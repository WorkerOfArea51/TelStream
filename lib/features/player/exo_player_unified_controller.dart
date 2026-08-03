import 'dart:async';
import 'package:video_player/video_player.dart';
import 'unified_player_controller.dart';

/// ExoPlayer-backed [UnifiedPlayerController] (Android only).
///
/// Uses the `video_player` Flutter plugin, which wraps ExoPlayer on Android.
/// ExoPlayer is Google's reference Android media player — it uses
/// MediaCodec directly (no mpv in the path) and handles the c2.mtk.hevc
/// decoder correctly because it implements Android's standard
/// MediaCodec renderer contract (SurfaceTexture drainage + presentation
/// timestamp matching), unlike mpv's copy-back VO.
///
/// ── Why ExoPlayer "just works" on MediaTek ──────────────────────────
/// ExoPlayer's `MediaCodecRenderer` uses Android's standard
/// `MediaCodec.configure(surface, ...)` + `dequeueOutputBuffer` +
/// `releaseOutputBuffer(render=true)` pattern. This is the SAME path
/// that Android's own MediaPlayer and VLC use — it's the canonical
/// SurfaceTexture drainage contract that MediaTek's c2.mtk.hevc.decoder
/// implements correctly. There is no copy-back VO, no GL framebuffer
/// interop, no Impeller/Skia texture conversion. Frames go directly
/// from MediaCodec → SurfaceTexture → Flutter texture.
///
/// ── The getter override (CRITICAL FIX 2025-08-04) ───────────────────
/// This class MUST override `exoPlayerController` (not just provide
/// `videoPlayerController`). The video surface builder in
/// `video_player_screen.dart` reads `activePlayer.exoPlayerController`.
/// Without this override, the base class returns `null` → the builder
/// falls through to media_kit's `CachedVideoWidget` → ExoPlayer's video
/// surface is never mounted → black screen with audio only.
///
/// ── Limitations of the video_player plugin ────────────────────────────
/// The official `video_player` plugin does NOT expose:
///   - Multi-track audio/subtitle selection
///   - Equalizer
///   - Pitch shifting
///   - Screenshots
///   - Subtitle/audio delay
/// To unlock these, switch to `better_player` — see the feature roadmap
/// in GEMINI_INSTRUCTIONS.md. For now, capability flags honestly report
/// `false`.
class ExoPlayerUnifiedController extends BaseUnifiedPlayerController {
  VideoPlayerController? _controller;

  /// CRITICAL: Override the base-class getter so the video surface builder
  /// in video_player_screen.dart can pick up the ExoPlayer controller.
  /// The old `videoPlayerController` getter was never read by anyone.
  @override
  dynamic get exoPlayerController => _controller;

  /// Kept for backwards compatibility — any code that still references
  /// `videoPlayerController` will work. Prefer `exoPlayerController`.
  VideoPlayerController? get videoPlayerController => _controller;

  bool _isLooping = false;

  final Map<String, String> _httpHeaders;

  ExoPlayerUnifiedController({Map<String, String>? httpHeaders})
      : _httpHeaders = httpHeaders ?? const {};

  // ── Capabilities ─────────────────────────────────────────────────────
  @override
  String get engineName => 'ExoPlayer';
  // NOTE: All advanced capabilities are `false` because the `video_player`
  // plugin doesn't expose them — NOT because ExoPlayer itself lacks them.
  // Upgrade to `better_player` to flip these to `true`.
  @override
  bool get supportsAudioTrackSelection => false;
  @override
  bool get supportsSubtitleTrackSelection => false;
  @override
  bool get supportsEqualizer => false;
  @override
  bool get supportsPitch => false;
  @override
  bool get supportsScreenshot => false;
  @override
  bool get supportsSubtitleDelay => false;
  @override
  bool get supportsAudioDelay => false;
  @override
  bool get supportsAspectRatioOverride => false;

  // ── Transport ─────────────────────────────────────────────────────────
  @override
  UnifiedPlayerStateData get state {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const UnifiedPlayerStateData(
        position: Duration.zero,
        duration: Duration.zero,
        volume: 100.0,
        rate: 1.0,
        playing: false,
        buffering: true,
      );
    }
    final v = c.value;
    return UnifiedPlayerStateData(
      position: v.position,
      duration: v.duration,
      volume: v.volume * 100.0,
      rate: v.playbackSpeed,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      isLooping: _isLooping,
      errorMessage: v.errorDescription,
    );
  }

  @override
  Future<void> open(String url,
      {bool play = true, Map<String, String>? httpHeaders}) async {
    final headers = httpHeaders ?? _httpHeaders;
    // Dispose any previous controller — ExoPlayer doesn't support
    // re-pointing to a new URL on the same instance.
    final old = _controller;
    _controller = null; // Clear BEFORE dispose so the getter returns null
    // during the transition (prevents the widget from grabbing a
    // disposed controller).
    if (old != null) {
      old.removeListener(_onVideoPlayerUpdate);
      try {
        await old.dispose();
      } catch (_) {}
    }

    // ExoPlayer-specific: video_player's VideoPlayerController.networkUrl
    // wraps ExoPlayer's ProgressiveMediaSource / HlsMediaSource /
    // DashMediaSource. ExoPlayer auto-selects the right MediaCodec renderer
    // (c2.mtk.hevc.decoder for HEVC, c2.android.avc.decoder for H264, etc.)
    // and uses the standard SurfaceTexture drainage pattern that
    // MediaTek's decoder implements correctly.
    final newController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      // video_player 2.x: formatHint lets us tell ExoPlayer what container
      // to expect. Leaving it null (auto-detect) is the safest default —
      // ExoPlayer's extractor sniffing is reliable for MP4/MKV/WebM.
      formatHint: null,
      // 'application/octet-stream' is the most permissive MIME type —
      // ExoPlayer will fall back to its content-type sniffer.
      videoPlayerOptions: null,
    );

    _controller = newController;
    _controller!.addListener(_onVideoPlayerUpdate);

    try {
      await _controller!.initialize();
    } catch (e) {
      // If initialization fails, emit an error so the UI shows it
      // instead of an infinite loading spinner.
      if (!isClosed) {
        emitDistinct(
          position: Duration.zero,
          duration: Duration.zero,
          volume: 100.0,
          rate: 1.0,
          playing: false,
          buffering: false,
          error: 'ExoPlayer init failed: $e',
        );
      }
      rethrow;
    }

    if (play && !isClosed) {
      try {
        await _controller!.play();
      } catch (_) {}
    }
  }

  @override
  Future<void> play() async {
    try {
      await _controller?.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _controller?.pause();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _controller?.pause();
      await _controller?.seekTo(Duration.zero);
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _controller?.seekTo(position);
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _controller?.setVolume((volume / 100.0).clamp(0.0, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> setRate(double rate) async {
    try {
      await _controller?.setPlaybackSpeed(rate);
    } catch (_) {}
  }

  @override
  Future<void> setLooping(bool enabled) async {
    _isLooping = enabled;
    try {
      await _controller?.setLooping(enabled);
    } catch (_) {}
  }

  void _onVideoPlayerUpdate() {
    final c = _controller;
    if (c == null || isClosed || !c.value.isInitialized) return;
    final v = c.value;
    emitDistinct(
      position: v.position,
      duration: v.duration,
      volume: v.volume * 100.0,
      rate: v.playbackSpeed,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      error: v.errorDescription,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPlayerUpdate);
    super.dispose();
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}
