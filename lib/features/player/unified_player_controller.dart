import 'package:media_kit/media_kit.dart' as media_kit;
import 'dart:async';

/// Engine-agnostic snapshot of player state.
///
/// Designed to be value-equatable so consumers can use it in
/// `==` comparisons to skip redundant rebuilds. Do NOT add engine-specific
/// fields here — if you need engine-specific state, expose it via a typed
/// accessor on [UnifiedPlayerController] instead.
class UnifiedPlayerStateData {
  final Duration position;
  final Duration duration;
  final double volume; // 0.0 to 100.0
  final double rate; // playback speed
  final bool playing;
  final bool buffering;
  final bool completed;
  final String? errorMessage;

  const UnifiedPlayerStateData({
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.playing,
    required this.buffering,
    this.completed = false,
    this.errorMessage,
  });

  UnifiedPlayerStateData copyWith({
    Duration? position,
    Duration? duration,
    double? volume,
    double? rate,
    bool? playing,
    bool? buffering,
    bool? completed,
    String? errorMessage,
  }) =>
      UnifiedPlayerStateData(
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        rate: rate ?? this.rate,
        playing: playing ?? this.playing,
        buffering: buffering ?? this.buffering,
        completed: completed ?? this.completed,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// Engine-agnostic stream bundle. Each stream emits ONLY on actual value
/// change (engine implementations MUST apply distinct filtering before
/// emitting — see [BaseUnifiedPlayerController.emitDistinct]).
class UnifiedPlayerStreamData {
  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<double> volume;
  final Stream<double> rate;
  final Stream<bool> playing;
  final Stream<bool> buffering;
  final Stream<bool> completed;
  final Stream<String?> error;

  const UnifiedPlayerStreamData({
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.playing,
    required this.buffering,
    required this.completed,
    required this.error,
  });
}

/// A single audio track, normalized across engines.
class UnifiedAudioTrack {
  final String id;
  final String? language;
  final String? title;
  const UnifiedAudioTrack({required this.id, this.language, this.title});
}

/// A single subtitle track, normalized across engines.
class UnifiedSubtitleTrack {
  final String id;
  final String? language;
  final String? title;
  const UnifiedSubtitleTrack({required this.id, this.language, this.title});
}

/// The set of tracks currently available in the media.
class UnifiedTracks {
  final List<UnifiedAudioTrack> audio;
  final List<UnifiedSubtitleTrack> subtitle;
  final UnifiedAudioTrack? currentAudio;
  final UnifiedSubtitleTrack? currentSubtitle;
  const UnifiedTracks({
    this.audio = const [],
    this.subtitle = const [],
    this.currentAudio,
    this.currentSubtitle,
  });
}

/// Abstract video engine controller.
///
/// ── Architecture rules for implementers ──────────────────────────────────
/// 1. NEVER expose the underlying engine object via a `dynamic` getter.
///    Engine-specific features belong in typed methods on this interface
///    (with `UnsupportedError` defaults for engines that don't support them).
///    This is the ONLY way to keep `custom_video_controls.dart` free of
///    unsafe casts.
///
/// 2. Stream emissions MUST be distinct-filtered. Use
///    [BaseUnifiedPlayerController.emitDistinct] or implement equivalent
///    deduplication. Firing on every frame (as the original VLC/ExoPlayer
///    controllers did) causes 360+ setState/sec → severe jank.
///
/// 3. All async methods MUST be safe to call after dispose. Engine
///    implementations should silently no-op (with a debug log) rather than
///    throwing. This prevents post-dispose crashes from queued microtasks.
abstract class UnifiedPlayerController {
  UnifiedPlayerStateData get state;
  UnifiedPlayerStreamData get stream;

  // ── Capabilities (UI uses these to hide/show controls) ──────────────
  /// True if the engine supports a real-time audio equalizer.
  bool get supportsEqualizer => false;
  /// True if the engine supports pitch shifting (independent of speed).
  bool get supportsPitch => false;
  /// True if the engine exposes multi-track audio (e.g., JP/EN dub switch).
  bool get supportsAudioTrackSelection => false;
  /// True if the engine exposes multi-track subtitles (embedded SRT/ASS).
  bool get supportsSubtitleTrackSelection => false;
  /// True if the engine can capture the current frame to an image.
  bool get supportsScreenshot => false;
  /// True if the engine supports subtitle delay adjustment (ms precision).
  bool get supportsSubtitleDelay => false;
  /// True if the engine supports audio delay adjustment (ms precision).
  bool get supportsAudioDelay => false;
  /// True if the engine supports setting an arbitrary aspect ratio override.
  bool get supportsAspectRatioOverride => false;
  /// Human-readable engine name for diagnostics UI (e.g., "MediaKit", "ExoPlayer").
  String get engineName;

  // ─── Engine-specific accessors ──────────────────────────────────
  media_kit.Player? get mediaKitPlayer => null;
  dynamic get vlcPlayer => null;
  dynamic get exoPlayerController => null;

  // ── Transport ───────────────────────────────────────────────────────
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> open(String url, {bool play = true, Map<String, String>? httpHeaders});
  Future<void> playOrPause() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume); // 0.0 .. 100.0
  Future<void> setRate(double rate);

  // ── Track selection (default: UnsupportedError) ─────────────────────
  Future<UnifiedTracks> getTracks() async => const UnifiedTracks();
  Future<void> setAudioTrack(UnifiedAudioTrack track) async {
    throw UnsupportedError('$engineName does not support audio track selection');
  }
  Future<void> setSubtitleTrack(UnifiedSubtitleTrack track) async {
    throw UnsupportedError('$engineName does not support subtitle track selection');
  }
  Future<void> setSubtitleDelay(Duration delay) async {
    throw UnsupportedError('$engineName does not support subtitle delay');
  }
  Future<void> setAudioDelay(Duration delay) async {
    throw UnsupportedError('$engineName does not support audio delay');
  }

  // ── Advanced features (default: UnsupportedError) ───────────────────
  Future<void> setPitch(double pitch) async {
    throw UnsupportedError('$engineName does not support pitch shifting');
  }
  Future<List<int>> screenshot({String format = 'png'}) async {
    throw UnsupportedError('$engineName does not support screenshots');
  }

  // ── Lifecycle ───────────────────────────────────────────────────────
  void dispose();
}

/// Base class providing dedup-emit plumbing for engine adapters that wrap
/// a `Listenable` (ExoPlayer, VLC) — both of which fire `notifyListeners`
/// on every frame. Subclasses call [emitDistinct] instead of pushing
/// raw values to the stream controllers.
///
/// This is the fix for the "60fps → 360 setState/sec" jank bug in the
/// original VlcUnifiedController and ExoPlayerUnifiedController.
abstract class BaseUnifiedPlayerController extends UnifiedPlayerController {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  // Last-emitted values for distinct comparison.
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  double _lastVolume = -1;
  double _lastRate = -1;
  bool? _lastPlaying;
  bool? _lastBuffering;
  bool? _lastCompleted;
  String? _lastError;
  bool isClosed = false;

  void emitDistinct({
    required Duration position,
    required Duration duration,
    required double volume,
    required double rate,
    required bool playing,
    required bool buffering,
    bool completed = false,
    String? error,
  }) {
    if (isClosed) return;
    // Position changes almost every frame (that's expected — it's the
    // playback cursor). DO NOT dedup position. The UI bar NEEDS every
    // update to animate smoothly. The jank bug was NOT from position
    // emissions; it was from volume/rate/playing/buffering re-emitting
    // the SAME value 60 times/sec, each triggering a setState in controls.
    if (position != _lastPosition) {
      _lastPosition = position;
      _positionController.add(position);
    }
    if (duration != _lastDuration) {
      _lastDuration = duration;
      _durationController.add(duration);
    }
    if (volume != _lastVolume) {
      _lastVolume = volume;
      _volumeController.add(volume);
    }
    if (rate != _lastRate) {
      _lastRate = rate;
      _rateController.add(rate);
    }
    if (_lastPlaying != playing) {
      _lastPlaying = playing;
      _playingController.add(playing);
    }
    if (_lastBuffering != buffering) {
      _lastBuffering = buffering;
      _bufferingController.add(buffering);
    }
    if (_lastCompleted != completed) {
      _lastCompleted = completed;
      _completedController.add(completed);
    }
    if (_lastError != error) {
      _lastError = error;
      _errorController.add(error);
    }
  }

  @override
  UnifiedPlayerStreamData get stream => UnifiedPlayerStreamData(
        position: _positionController.stream,
        duration: _durationController.stream,
        volume: _volumeController.stream,
        rate: _rateController.stream,
        playing: _playingController.stream,
        buffering: _bufferingController.stream,
        completed: _completedController.stream,
        error: _errorController.stream,
      );

  @override
  void dispose() {
    isClosed = true;
    _positionController.close();
    _durationController.close();
    _volumeController.close();
    _rateController.close();
    _playingController.close();
    _bufferingController.close();
    _completedController.close();
    _errorController.close();
  }
}
