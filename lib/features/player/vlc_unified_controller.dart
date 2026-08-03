import 'dart:async';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'unified_player_controller.dart';

class VlcUnifiedController extends UnifiedPlayerController {
  final VlcPlayerController _controller;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();

  VlcUnifiedController(this._controller) {
    _controller.addListener(_onVlcUpdate);
  }

  void _onVlcUpdate() {
    final value = _controller.value;
    _positionController.add(value.position);
    _durationController.add(value.duration);
    _volumeController.add(value.volume.toDouble());
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
      volume: value.volume.toDouble(),
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
  bool get supportsEqualizer => false; // VLC on Android doesn't expose it easily in this plugin
  @override
  bool get supportsPitch => false;
  @override
  bool get supportsAudioTrackSelection => true; // VLC does support this via _controller.getAudioTracks()
  @override
  bool get supportsSubtitleTrackSelection => true;

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();
  @override
  Future<void> stop() => _controller.stop();
  @override
  Future<void> open(String url, {bool play = true, Map<String, String>? httpHeaders}) async {
    await _controller.setMediaFromNetwork(url, hwAcc: HwAcc.full, autoPlay: play);
  }

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume.toInt());

  @override
  Future<void> setRate(double rate) => _controller.setPlaybackSpeed(rate);

  @override
  void dispose() {
    _controller.removeListener(_onVlcUpdate);
    _positionController.close();
    _durationController.close();
    _volumeController.close();
    _rateController.close();
    _playingController.close();
    _bufferingController.close();
  }
}
