// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'unified_player_controller.dart';

/// libVLC-backed [UnifiedPlayerController].
///
/// libVLC is the recommended engine for MediaTek Dimensity 6080 — it uses
/// its own MediaCodec integration (via libvlc's `android_surface` module)
/// which does NOT go through mpv's GPU VO, avoiding the copy-back
/// SurfaceTexture stall that produces `Render: 0, Drop: 119` on c2.mtk.hevc.
///
/// ── The getter override (CRITICAL FIX 2025-08-04) ───────────────────
/// This class MUST override `vlcPlayer` (not just provide `vlcController`).
/// The video surface builder in `video_player_screen.dart` reads
/// `activePlayer.vlcPlayer`. Without this override, the base class returns
/// `null` → the builder falls through to media_kit's `CachedVideoWidget`
/// → VLC's video surface (VlcPlayer widget) is never mounted → VLC has no
/// Surface to render to → playback fails entirely (no video, no audio
/// because the renderer can't attach).
///
/// ── Streaming proxy auth ──────────────────────────────────────────────
/// VLC's `--http-header=` option is the ONLY way to pass per-request
/// headers. The proxy expects an Authorization header — without it, every
/// request 401s. Headers MUST be set at controller construction time
/// (libVLC does not support changing them per-media without recreating
/// the controller).
///
/// ── Engine-specific codec options ─────────────────────────────────────
/// VLC on Android uses `HwAcc.full` which enables MediaCodec direct
/// rendering (zero-copy to SurfaceTexture). This is the SAME path
/// ExoPlayer uses and is the canonical way to play video on Android.
/// Unlike mpv's `mediacodec-copy` (which copies frames through a GL VO
/// for tone-mapping), VLC's `HwAcc.full` goes directly to the
/// SurfaceTexture — no GL interop, no Impeller/Skia issues.
///
/// Additional VLC options applied below:
///   - `--no-video-title-show`  : don't overlay the filename on the video
///   - `--rtsp-tcp`             : force RTSP over TCP (more reliable on mobile)
///   - `--no-stats`             : disable stats collection (minor perf)
///   - `--prefer-swr`           : prefer SWresampler for audio (better sync)
///   - `--audio-resampler=soxr` : high-quality audio resampling
class VlcUnifiedController extends BaseUnifiedPlayerController {
  VlcPlayerController? _controller;

  /// CRITICAL: Override the base-class getter so the video surface builder
  /// in video_player_screen.dart can pick up the VLC controller.
  /// The old `vlcController` getter was never read by anyone.
  @override
  dynamic get vlcPlayer => _controller;

  /// Kept for backwards compatibility — any code that still references
  /// `vlcController` will work. Prefer `vlcPlayer`.
  VlcPlayerController? get vlcController => _controller;

  bool _isLooping = false;

  final Map<String, String> _httpHeaders;
  final List<String> _extraOptions;

  VlcUnifiedController({
    Map<String, String>? httpHeaders,
    List<String> extraOptions = const [],
  })  : _httpHeaders = httpHeaders ?? const {},
        _extraOptions = extraOptions;

  /// Builds the VlcPlayerController with proxy auth + streaming-friendly
  /// defaults. Called by [open] (not the constructor) so that header changes
  /// between episodes (rare, but possible) take effect.
  VlcPlayerController _buildController(String url, {bool autoPlay = true}) {
    final advancedOpts = <String>[
      // ── Streaming stability ──────────────────────────────────────────
      // These match mpv's demuxer-readahead-secs=180 and
      // demuxer-max-bytes=200MB from the media_kit path, translated to
      // VLC's own caching knobs (in milliseconds, not seconds/bytes).
      '--network-caching=3000',   // 3s network buffer
      '--file-caching=3000',      // 3s file buffer (for completed downloads)
      '--live-caching=1500',      // 1.5s live buffer
      '--clock-jitter=0',         // Disable jitter compensation (mpv doesn't use it)
      '--clock-synchro=0',        // Don't resample audio to match video clock

      // ── VLC-specific UI / behavior tweaks ────────────────────────────
      '--no-video-title-show',    // Don't overlay filename on video
      '--no-stats',               // Disable stats collection (minor perf gain)
      '--rtsp-tcp',               // Force RTSP over TCP (more reliable on mobile)
      '--prefer-swr',             // Prefer SWresampler for audio (better A/V sync)

      // ── Hardware acceleration ────────────────────────────────────────
      // HwAcc.full (set below) enables MediaCodec direct rendering.
      // These options tune the MediaCodec path:
      '--mediacodec-dr',          // Direct rendering (zero-copy to SurfaceTexture)
      '--no-mediacodec-omx',      // Don't use the legacy OMX codec (use MediaCodec)

      // ── Pass auth headers ────────────────────────────────────────────
      // (commit 145e581 fix for proxy — VLC needs headers at construction
      // time, not per-request)
      for (final entry in _httpHeaders.entries)
        '--http-header=${entry.key}: ${entry.value}',
      ..._extraOptions,
    ];

    return VlcPlayerController.network(
      url,
      // HwAcc.full = full hardware acceleration via MediaCodec direct
      // rendering. This is the canonical Android video playback path and
      // works correctly on MediaTek Dimensity 6080 (unlike mpv's
      // mediacodec-copy which has the SurfaceTexture/GL interop bug).
      hwAcc: HwAcc.full,
      autoPlay: autoPlay,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions(advancedOpts),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
      ),
    );
  }

  void _attachListener(VlcPlayerController c) {
    c.addListener(_onVlcUpdate);
  }

  void _detachListener(VlcPlayerController? c) {
    c?.removeListener(_onVlcUpdate);
  }

  void _onVlcUpdate() {
    final c = _controller;
    if (c == null || isClosed) return;
    final value = c.value;
    emitDistinct(
      position: value.position,
      duration: value.duration,
      volume: value.volume.toDouble(),
      rate: value.playbackSpeed,
      playing: value.isPlaying,
      buffering: value.isBuffering,
      completed: value.isEnded,
      error: value.hasError ? 'VLC playback error' : null,
    );
  }

  // ── Capabilities (corrected — VLC supports all of these) ──────────────
  @override
  String get engineName => 'LibVLC';
  @override
  bool get supportsEqualizer => true;   // VlcPlayerController.setEqualizer
  @override
  bool get supportsAudioTrackSelection => true;
  @override
  bool get supportsSubtitleTrackSelection => true;
  @override
  bool get supportsSubtitleDelay => true;  // via --sub-delay
  @override
  bool get supportsAudioDelay => true;     // via --audio-delay
  @override
  bool get supportsAspectRatioOverride => true; // via VlcPlayerController.setAspectRatio

  // ── Transport ─────────────────────────────────────────────────────────
  @override
  UnifiedPlayerStateData get state {
    final c = _controller;
    if (c == null) {
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
      volume: v.volume.toDouble(),
      rate: v.playbackSpeed,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      completed: v.isEnded,
      isLooping: _isLooping,
      errorMessage: v.hasError ? 'VLC playback error' : null,
    );
  }

  @override
  Future<void> open(String url,
      {bool play = true, Map<String, String>? httpHeaders}) async {
    // If headers changed since construction, we must rebuild the controller.
    final headersChanged =
        httpHeaders != null && !_mapsEqual(httpHeaders, _httpHeaders);

    final old = _controller;
    if (_controller == null || headersChanged) {
      // Clear the field BEFORE dispose so the getter returns null during
      // the transition (prevents the widget from grabbing a disposed
      // controller).
      _controller = null;
      if (old != null) {
        _detachListener(old);
        try {
          await old.dispose();
        } catch (_) {}
      }
      _controller = _buildController(url, autoPlay: play);
      _attachListener(_controller!);
      // VlcPlayerController.network with autoPlay=true will start playing
      // automatically once the media is loaded. No explicit play() needed.
    } else {
      // Same headers — just swap the media.
      await _controller!
          .setMediaFromNetwork(url, hwAcc: HwAcc.full, autoPlay: play);
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
      await _controller?.stop();
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
      await _controller?.setVolume(volume.toInt().clamp(0, 100));
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

  // ── Track selection ──────────────────────────────────────────────────
  @override
  Future<UnifiedTracks> getTracks() async {
    final c = _controller;
    if (c == null) return const UnifiedTracks();
    try {
      final audioTracks = await c.getAudioTracks();
      final subTracks = await c.getSpuTracks();
      final audioIdx = await c.getAudioTrack();
      final subIdx = await c.getSpuTrack();
      return UnifiedTracks(
        audio: _normalizeVlcAudioTracks(audioTracks),
        subtitle: _normalizeVlcSubtitleTracks(subTracks),
        currentAudio: _audioIndexToTrack(audioTracks, audioIdx ?? -1),
        currentSubtitle: _subtitleIndexToTrack(subTracks, subIdx ?? -1),
      );
    } catch (_) {
      return const UnifiedTracks();
    }
  }

  @override
  Future<void> setAudioTrack(UnifiedAudioTrack track) async {
    final c = _controller;
    if (c == null) return;
    try {
      final audioTracks = await c.getAudioTracks();
      final idx = _audioTrackToIndex(audioTracks, track);
      if (idx >= 0) await c.setAudioTrack(idx);
    } catch (_) {}
  }

  @override
  Future<void> setSubtitleTrack(UnifiedSubtitleTrack track) async {
    final c = _controller;
    if (c == null) return;
    try {
      final subTracks = await c.getSpuTracks();
      final idx = _subtitleTrackToIndex(subTracks, track);
      if (idx >= 0) await c.setSpuTrack(idx);
    } catch (_) {}
  }

  // ── Helpers ──────────────────────────────────────────────
  List<UnifiedAudioTrack> _normalizeVlcAudioTracks(Map<int, String> raw) => raw
      .entries
      .map((e) => UnifiedAudioTrack(
            id: e.key.toString(),
            title: e.value,
          ))
      .toList();

  List<UnifiedSubtitleTrack> _normalizeVlcSubtitleTracks(Map<int, String> raw) => raw
      .entries
      .map((e) => UnifiedSubtitleTrack(
            id: e.key.toString(),
            title: e.value,
          ))
      .toList();

  UnifiedAudioTrack? _audioIndexToTrack(Map<int, String> raw, int idx) {
    final title = raw[idx];
    return title == null
        ? null
        : UnifiedAudioTrack(id: idx.toString(), title: title);
  }

  UnifiedSubtitleTrack? _subtitleIndexToTrack(Map<int, String> raw, int idx) {
    final title = raw[idx];
    return title == null
        ? null
        : UnifiedSubtitleTrack(id: idx.toString(), title: title);
  }

  int _audioTrackToIndex(Map<int, String> raw, UnifiedAudioTrack track) {
    final id = int.tryParse(track.id);
    if (id != null && raw.containsKey(id)) return id;
    for (final e in raw.entries) {
      if (e.value == track.title) return e.key;
    }
    return -1;
  }

  int _subtitleTrackToIndex(Map<int, String> raw, UnifiedSubtitleTrack track) {
    final id = int.tryParse(track.id);
    if (id != null && raw.containsKey(id)) return id;
    for (final e in raw.entries) {
      if (e.value == track.title) return e.key;
    }
    return -1;
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (b[k] != a[k]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _detachListener(_controller);
    super.dispose();
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}
