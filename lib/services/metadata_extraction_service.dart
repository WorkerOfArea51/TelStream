import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../models/episode.dart';
import '../models/video_source.dart';
import 'network/tdlib_range_fetch.dart';

import 'streaming_proxy_service.dart';
import '../core/video_metadata/video_metadata_extractor.dart';
import '../core/logger.dart';

final metadataExtractionServiceProvider = NotifierProvider<MetadataExtractionNotifier, Map<int, Episode>>(
  MetadataExtractionNotifier.new,
);

class MetadataExtractionNotifier extends Notifier<Map<int, Episode>> {
  @override
  Map<int, Episode> build() {
    return {};
  }

  Future<void> extractMetadataForEpisode(
    Episode episode,
  ) async {
    // We use the bestSource message id as the map key
    final bestSource = episode.bestSource;
    if (bestSource == null) return;
    
    final episodeId = bestSource.message.id;
    
    // Skip if already extracting or extracted
    if (state[episodeId]?.isMetadataExtracted == true) return;
    
    final proxy = await ref.read(streamingProxyServiceProvider.future);

    final updatedSources = <VideoSource>[];

    for (final source in episode.sources) {
      if (source.width == 0 || source.height == 0) {
        try {
          final msgContent = source.message.content;
          String mimeType = '';
          String fileName = '';
          if (msgContent is td.MessageVideo) {
            mimeType = msgContent.video.mimeType;
            fileName = msgContent.video.fileName;
          } else if (msgContent is td.MessageDocument) {
            mimeType = msgContent.document.mimeType;
            fileName = msgContent.document.fileName;
          }
          final bytes = await TdlibRangeFetch.fetchPrefix(source.message, proxy);
          if (bytes != null && bytes.isNotEmpty) {
            final meta = await VideoMetadataExtractor.extractFromPrefix(prefix: bytes, mimeType: mimeType, fileName: fileName);
            if (meta != null) {
              updatedSources.add(source.copyWith(
                width: meta.width,
                height: meta.height,
              ));
              continue;
            }
          }
        } catch (e, st) {
          Log.e('Failed to extract metadata for message ${source.message.id}', e, st);
        }
      }
      // If we failed or it already had dimensions, keep original
      updatedSources.add(source);
    }

    final updatedEpisode = episode.copyWith(
      sources: updatedSources,
      isMetadataExtracted: true,
    );

    // Update state to trigger UI rebuilds
    state = {
      ...state,
      episodeId: updatedEpisode,
    };
  }
}
