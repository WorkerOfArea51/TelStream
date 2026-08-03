import 'dart:async';


class UnifiedPlayerStateData {
  final Duration position;
  final Duration duration;
  final double volume; // 0.0 to 100.0
  final double rate; // playback speed
  final bool playing;
  final bool buffering;

  UnifiedPlayerStateData({
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.playing,
    required this.buffering,
  });
}

class UnifiedPlayerStreamData {
  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<double> volume;
  final Stream<double> rate;
  final Stream<bool> playing;
  final Stream<bool> buffering;

  UnifiedPlayerStreamData({
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.playing,
    required this.buffering,
  });
}

abstract class UnifiedPlayerController {
  UnifiedPlayerStateData get state;
  UnifiedPlayerStreamData get stream;

  // Capabilities (UI can use these to hide/show buttons)
  bool get supportsEqualizer => false;
  bool get supportsPitch => false;
  bool get supportsAudioTrackSelection => false;
  bool get supportsSubtitleTrackSelection => false;
  bool get supportsScreenshot => false;

  // Basic Actions
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setRate(double rate);

  // Advanced Actions (override if supported)
  Future<void> setPitch(double pitch) async {
    throw UnsupportedError('Pitch shifting is not supported by this engine.');
  }
  
  Future<dynamic> screenshot({String? format}) async {
    throw UnsupportedError('Screenshots are not supported by this engine.');
  }

  // Access to the underlying engine-specific player for advanced dialogs
  dynamic get originalPlayer => null;

  void dispose();
}
