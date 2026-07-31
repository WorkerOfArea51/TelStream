import 'package:flutter_test/flutter_test.dart';
import 'package:telstream/models/video_source.dart';
import 'package:telstream/core/video_metadata/video_metadata.dart';

void main() {
  group('VideoSource.qualityLabel tests', () {
    test('Token extraction works from filename', () {
      final source = VideoSource(
        messageId: 1,
        chatId: 1,
        fileSizeBytes: 1000,
        fileName: 'Anime_Episode_1080p_WEB.mkv',
        mimeType: 'video/x-matroska',
        receivedAt: DateTime.now(),
      );
      expect(source.qualityLabel, '1080p');
    });

    test('Falls back to height buckets when filename has no tokens', () {
      final meta1080 = VideoMetadata(
        width: 1920,
        height: 1080,
        durationMillis: 1000,
        container: VideoContainer.mp4,
      );
      final source1080 = VideoSource(
        messageId: 1,
        chatId: 1,
        fileSizeBytes: 1000,
        fileName: 'Anime_Episode.mkv',
        mimeType: 'video/x-matroska',
        receivedAt: DateTime.now(),
        metadata: meta1080,
      );
      expect(source1080.qualityLabel, '1080p');

      final meta720 = VideoMetadata(
        width: 1280,
        height: 720,
        durationMillis: 1000,
        container: VideoContainer.mp4,
      );
      final source720 = VideoSource(
        messageId: 1,
        chatId: 1,
        fileSizeBytes: 1000,
        fileName: 'Anime_Episode.mkv',
        mimeType: 'video/x-matroska',
        receivedAt: DateTime.now(),
        metadata: meta720,
      );
      expect(source720.qualityLabel, '720p');
    });

    test('Defaults to 480p for SD resolution', () {
      final metaSD = VideoMetadata(
        width: 720,
        height: 480,
        durationMillis: 1000,
        container: VideoContainer.mp4,
      );
      final sourceSD = VideoSource(
        messageId: 1,
        chatId: 1,
        fileSizeBytes: 1000,
        fileName: 'Anime_Episode.mkv',
        mimeType: 'video/x-matroska',
        receivedAt: DateTime.now(),
        metadata: metaSD,
      );
      expect(sourceSD.qualityLabel, '480p');
    });

    test('Returns Unknown when metadata height is 0 and no tokens', () {
      final metaUnknown = VideoMetadata.unknown();
      final sourceUnknown = VideoSource(
        messageId: 1,
        chatId: 1,
        fileSizeBytes: 1000,
        fileName: 'Anime_Episode.mkv',
        mimeType: 'video/x-matroska',
        receivedAt: DateTime.now(),
        metadata: metaUnknown,
      );
      expect(sourceUnknown.qualityLabel, 'Unknown');
    });
  });
}
