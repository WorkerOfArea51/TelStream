import 'dart:typed_data';
import 'video_metadata.dart';
import 'parsers/mp4_parser.dart';
import 'parsers/mkv_parser.dart';
import 'parsers/fallback_parser.dart';

abstract class VideoMetadataExtractor {
  /// [prefix] is the first N bytes of the file (N typically 2 MB).
  /// Returns null if extraction fails — caller treats as Unknown.
  static Future<VideoMetadata?> extractFromPrefix({
    required Uint8List prefix,
    required String mimeType,
    required String fileName,
  }) async {
    final lowerName = fileName.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    if (lowerName.endsWith('.mp4') || lowerMime == 'video/mp4' || lowerName.endsWith('.mov') || lowerName.endsWith('.m4v')) {
      final res = await Mp4Parser.parse(prefix);
      if (res != null) return res;
    }

    if (lowerName.endsWith('.mkv') || lowerName.endsWith('.webm') || lowerMime == 'video/x-matroska' || lowerMime == 'video/webm') {
      final res = await MkvParser.parse(prefix);
      if (res != null) return res;
    }

    // Attempt fallback parser if primary parser failed or unknown type
    return FallbackParser.parse(prefix);
  }
}
