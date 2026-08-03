import 'dart:async';
import 'dart:typed_data';
import 'package:media_kit/media_kit.dart';
import 'unified_player_controller.dart';

/// media_kit (libmpv) backed [UnifiedPlayerController].
///
/// media_kit is the historical default engine. It wraps libmpv and provides
/// the richest feature set (equalizer, pitch, screenshot, subtitle delay,
/// native libass rendering). It is also the engine with the MediaTek
/// Dimensity 6080 black-screen bug — see `device_detector.dart` and the
/// v1–v7 audit history in `core/constants.dart`.
///
/// ── Why this is NOT a BaseUnifiedPlayerController subclass ─────────────
/// media_kit already provides its own deduplicated broadcast streams via
/// `Player.stream`. We delegate directly to those streams rather than
/// re-implementing deduplication. Only ExoPlayer and VLC (which wrap a
/// `Listenable` that fires per-frame) need [BaseUnifiedPlayerController].
class MediaKitUnifiedController extends UnifiedPlayerController {
  final Player _player;
  late final StreamController<UnifiedTracks> _tracksController =
      StreamController<UnifiedTracks>.broadcast();

  StreamSubscription? _tracksSub;

  MediaKitUnifiedController(this._player) {
    // Bridge media_kit's typed Tracks stream into the engine-agnostic
    // UnifiedTracks stream. This lets `video_player_screen.dart` subscribe
    // to `mk.tracksStream` instead of `_mediaKitPlayer.stream.tracks`,
    // which is the crash source for non-media_kit engines.
    _tracksSub = _player.stream.tracks.listen((tracks) {
      if (_tracksController.isClosed) return;
      _tracksController.add(UnifiedTracks(
        audio: tracks.audio
            .map((t) => UnifiedAudioTrack(
                  id: t.id,
                  language: t.language,
                  title: t.title,
                ))
            .toList(),
        subtitle: tracks.subtitle
            .map((t) => UnifiedSubtitleTrack(
                  id: t.id,
                  language: t.language,
                  title: t.title,
                ))
            .toList(),
        currentAudio: _toUnifiedAudio(_player.state.track.audio),
        currentSubtitle: _toUnifiedSubtitle(_player.state.track.subtitle),
      ));
    });
  }

  /// Exposes media_kit's tracks stream, bridged to [UnifiedTracks].
  /// Used by `video_player_screen.dart._setupPlayerListeners` for the
  /// media_kit engine path. ExoPlayer/VLC use a poll-based approach
  /// instead (see _setupPlayerListeners Block 4).
  Stream<UnifiedTracks> get tracksStream => _tracksController.stream;

  /// Direct access to the underlying media_kit Player.
  ///
  /// NOTE: This is intentionally typed (returns `Player`, not `dynamic`).
  /// Consumers MUST check `widget.player is MediaKitUnifiedController`
  /// before accessing this — the cast `as Player` on a non-media_kit
  /// controller is a compile error, not a runtime TypeError.
  @override
  Player? get mediaKitPlayer => _player;

  // ── Capabilities ─────────────────────────────────────────────────────
  @override
  String get engineName => 'MediaKit';
  @override
  bool get supportsEqualizer => true;
  @override
  bool get supportsPitch => true;
  @override
  bool get supportsAudioTrackSelection => true;
  @override
  bool get supportsSubtitleTrackSelection => true;
  @override
  bool get supportsScreenshot => true;
  @override
  bool get supportsSubtitleDelay => true;
  @override
  bool get supportsAudioDelay => true;
  @override
  bool get supportsAspectRatioOverride => true;

  // ── State ────────────────────────────────────────────────────────────
  @override
  UnifiedPlayerStateData get state => UnifiedPlayerStateData(
        position: _player.state.position,
        duration: _player.state.duration,
        volume: _player.state.volume,
        rate: _player.state.rate,
        playing: _player.state.playing,
        buffering: _player.state.buffering,
        completed: _player.state.completed,
        isLooping: _player.state.playlistMode == PlaylistMode.loop,  
      );

  @override
  UnifiedPlayerStreamData get stream => UnifiedPlayerStreamData(
        position: _player.stream.position,
        duration: _player.stream.duration,
        volume: _player.stream.volume,
        rate: _player.stream.rate,
        playing: _player.stream.playing,
        buffering: _player.stream.buffering,
        completed: _player.stream.completed,
        error: _player.stream.error.map((e) => e.toString()),
      );

  // ── Transport ────────────────────────────────────────────────────────
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> open(String url,
      {bool play = true, Map<String, String>? httpHeaders}) {
    return _player.open(Media(url, httpHeaders: httpHeaders), play: play);
  }
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setRate(double rate) => _player.setRate(rate);
  @override
  Future<void> setLooping(bool enabled) => _player.setPlaylistMode(
        enabled ? PlaylistMode.loop : PlaylistMode.none,
      );

  // ── Track selection ──────────────────────────────────────────────────
  @override
  Future<UnifiedTracks> getTracks() async {
    final tracks = _player.state.tracks;
    return UnifiedTracks(
      audio: tracks.audio
          .map((t) => UnifiedAudioTrack(
                id: t.id,
                language: t.language,
                title: t.title,
              ))
          .toList(),
      subtitle: tracks.subtitle
          .map((t) => UnifiedSubtitleTrack(
                id: t.id,
                language: t.language,
                title: t.title,
              ))
          .toList(),
      currentAudio: _toUnifiedAudio(_player.state.track.audio),
      currentSubtitle: _toUnifiedSubtitle(_player.state.track.subtitle),
    );
  }

  @override
  Future<void> setAudioTrack(UnifiedAudioTrack track) async {
    final mkTrack = _findAudioTrack(track);
    if (mkTrack != null) {
      await _player.setAudioTrack(mkTrack);
    }
  }

  @override
  Future<void> setSubtitleTrack(UnifiedSubtitleTrack track) async {
    // External subtitle (file path) — title field holds the path.
    // This mirrors the old `SubtitleTrack.uri(path)` usage in
    // custom_video_controls.dart.
    if (track.id == 'external' && track.title != null) {
      await _player.setSubtitleTrack(SubtitleTrack.uri(track.title!));
      return;
    }
    final mkTrack = _findSubtitleTrack(track);
    if (mkTrack != null) {
      await _player.setSubtitleTrack(mkTrack);
    }
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    if (_player.platform is NativePlayer) {
      await (_player.platform as NativePlayer)
          .setProperty('sub-delay', '${delay.inMilliseconds}ms');
    }
  }

  @override
  Future<void> setAudioDelay(Duration delay) async {
    if (_player.platform is NativePlayer) {
      await (_player.platform as NativePlayer)
          .setProperty('audio-delay', '${delay.inMilliseconds}ms');
    }
  }

  // ── Advanced ─────────────────────────────────────────────────────────
  @override
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);

  @override
  Future<List<int>> screenshot({String format = 'png'}) async {
    final Uint8List? bytes = await _player.screenshot(format: format);
    if (bytes == null) return [];
    return bytes;
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  AudioTrack? _findAudioTrack(UnifiedAudioTrack track) {
    final tracks = _player.state.tracks.audio;
    // Match by ID first, then by title, then by language.
    for (final t in tracks) {
      if (t.id == track.id) return t;
    }
    for (final t in tracks) {
      if (t.title != null && t.title == track.title) return t;
    }
    for (final t in tracks) {
      if (t.language != null && t.language == track.language) return t;
    }
    return null;
  }

  SubtitleTrack? _findSubtitleTrack(UnifiedSubtitleTrack track) {
    final tracks = _player.state.tracks.subtitle;
    for (final t in tracks) {
      if (t.id == track.id) return t;
    }
    for (final t in tracks) {
      if (t.title != null && t.title == track.title) return t;
    }
    for (final t in tracks) {
      if (t.language != null && t.language == track.language) return t;
    }
    return null;
  }

  UnifiedAudioTrack? _toUnifiedAudio(AudioTrack? t) {
    if (t == null) return null;
    return UnifiedAudioTrack(id: t.id, language: t.language, title: t.title);
  }

  UnifiedSubtitleTrack? _toUnifiedSubtitle(SubtitleTrack? t) {
    if (t == null) return null;
    return UnifiedSubtitleTrack(
        id: t.id, language: t.language, title: t.title);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────
  @override
  void dispose() {
    _tracksSub?.cancel();
    _tracksController.close();
    // We do NOT dispose _player here — it is owned by video_player_screen.
    // Disposing it would break the recreate-player flow.
  }
}
