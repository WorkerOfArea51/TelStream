import 'dart:async';
import 'package:video_player/video_player.dart';
import 'unified_player_controller.dart';

class ExoPlayerUnifiedController extends UnifiedPlayerController {
  final VideoPlayerController _controller;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();

  ExoPlayerUnifiedController(this._controller) {
    _controller.addListener(_onVideoPlayerUpdate);
  }

  void _onVideoPlayerUpdate() {
    final value = _controller.value;
    _positionController.add(value.position);
    _durationController.add(value.duration);
    _volumeController.add(value.volume * 100.0);
    _rateController.add(value.playbackSpeed);
    _playingController.add(value.isPlaying);
    _bufferingController.add(value.isBuffering);
  }

  @override
  dynamic get originalPlayer => _controller;

  @override
  UnifiedPlayerStateData get state {
    final value = _controller.value;
    return UnifiedPlayerStateData(
      position: value.position,
      duration: value.duration,
      volume: value.volume * 100.0,
      rate: value.playbackSpeed,
      playing: value.isPlaying,
      buffering: value.isBuffering,
    );
  }

  @override
  UnifiedPlayerStreamData get stream => UnifiedPlayerStreamData(
        position: _positionController.stream,
        duration: _durationController.stream,
        volume: _volumeController.stream,
        rate: _rateController.stream,
        playing: _playingController.stream,
        buffering: _bufferingController.stream,
      );

  @override
  bool get supportsEqualizer => false;
  @override
  bool get supportsPitch => false;
  @override
  bool get supportsAudioTrackSelection => false;
  @override
  bool get supportsSubtitleTrackSelection => false;

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume / 100.0);

  @override
  Future<void> setRate(double rate) => _controller.setPlaybackSpeed(rate);

  @override
  void dispose() {
    _controller.removeListener(_onVideoPlayerUpdate);
    _positionController.close();
    _durationController.close();
    _volumeController.close();
    _rateController.close();
    _playingController.close();
    _bufferingController.close();
  }
}
