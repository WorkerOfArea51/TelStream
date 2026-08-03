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
  VideoPlayerController? get videoPlayerController => _controller;

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
      errorMessage: v.errorDescription,
    );
  }

  @override
  Future<void> open(String url,
      {bool play = true, Map<String, String>? httpHeaders}) async {
    final headers = httpHeaders ?? _httpHeaders;
    // Dispose any previous controller — ExoPlayer doesn't support
    // re-pointing to a new URL on the same instance.
    await _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
    );
    _controller!.addListener(_onVideoPlayerUpdate);
    await _controller!.initialize();
    if (play && !isClosed) {
      await _controller!.play();
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
