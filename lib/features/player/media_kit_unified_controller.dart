import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'unified_player_controller.dart';

class MediaKitUnifiedController extends UnifiedPlayerController {
  final Player _player;
  
  MediaKitUnifiedController(this._player);

  Player get originalPlayer => _player;

  @override
  UnifiedPlayerStateData get state => UnifiedPlayerStateData(
        position: _player.state.position,
        duration: _player.state.duration,
        volume: _player.state.volume,
        rate: _player.state.rate,
        playing: _player.state.playing,
        buffering: _player.state.buffering,
      );

  @override
  UnifiedPlayerStreamData get stream => UnifiedPlayerStreamData(
        position: _player.stream.position,
        duration: _player.stream.duration,
        volume: _player.stream.volume,
        rate: _player.stream.rate,
        playing: _player.stream.playing,
        buffering: _player.stream.buffering,
      );

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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);
  
  @override
  Future<dynamic> screenshot({String? format}) => _player.screenshot(format: format);

  @override
  void dispose() {
    // We typically don't dispose the Player here because it's managed by video_player_screen.
  }
}
