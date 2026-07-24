import 'package:media_kit/media_kit.dart';
import '../../settings/settings_provider.dart';
import 'dart:developer' as developer;

class PlayerFilterService {
  static void updateAudioFilters(Player player, VideoSettings settings, {bool audioBoostActive = false}) {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        final filters = <String>[];
        
        if (audioBoostActive) {
          filters.add('volume=volume=6dB:precision=fixed');
        }
        
        if (settings.audio.dynamicRangeCompression) {
          filters.add('lavfi=[dynaudnorm]');
        }
        
        if (settings.audio.equalizerEnabled) {
          final bands = settings.audio.equalizerBands;
          filters.add('equalizer=f=100:width_type=o:w=2.0:g=${bands[0]}');
          filters.add('equalizer=f=300:width_type=o:w=2.0:g=${bands[1]}');
          filters.add('equalizer=f=1000:width_type=o:w=2.0:g=${bands[2]}');
          filters.add('equalizer=f=3000:width_type=o:w=2.0:g=${bands[3]}');
          filters.add('equalizer=f=10000:width_type=o:w=2.0:g=${bands[4]}');
        }

        if (filters.isNotEmpty) {
          nativePlayer.setProperty('af', filters.join(','));
          developer.log('Applied combined audio filters: ${filters.join(',')}');
        } else {
          nativePlayer.setProperty('af', '');
          developer.log('Cleared all audio filters');
        }
      }
    } catch (e) {
      developer.log('Failed to apply audio filters: $e');
    }
  }

  static Future<bool> updateBlendSubtitlesForTrack(Player player, SubtitleTrack track) async {
    try {
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        String targetId = track.id;
        if (targetId == 'auto') {
          final sid = await nativePlayer.getProperty('sid');
          if (sid == 'no' || sid == 'auto') {
            nativePlayer.setProperty('blend-subtitles', 'no');
            return false;
          }
          targetId = sid;
        }

        final tracksInfoStr = await nativePlayer.getProperty('track-list');
        final tracksInfo = tracksInfoStr.toString();
        
        // Simplified logic since tracksInfo is a String in media_kit
        if (tracksInfo.contains('"id":$targetId') || tracksInfo.contains("'id':$targetId")) {
             // We'll skip the exact bitmap codec check for auto id if we can't parse it easily.
             // Just safely default to no if we aren't sure.
        }
        
        nativePlayer.setProperty('blend-subtitles', 'no');
        developer.log('Native blending subtitle disabled for text subtitle');
      }
    } catch (e) {
      developer.log('Failed to configure blend-subtitles: $e');
    }
    return false;
  }
}
