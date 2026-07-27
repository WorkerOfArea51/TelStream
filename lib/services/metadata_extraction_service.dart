import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';
import 'package:tdlib/td_api.dart' as td;
import '../models/episode.dart';
import '../models/video_source.dart';
import 'network/tdlib_range_fetch.dart';
import 'streaming_proxy_service.dart';
import '../core/video_metadata/video_metadata_extractor.dart';
import '../core/logger.dart';
import 'video_metadata_cache.dart';
import 'tdlib_service.dart';
import '../core/video_metadata/video_metadata.dart';

final metadataExtractionServiceProvider = NotifierProvider<MetadataExtractionNotifier, Map<int, Episode>>(
  MetadataExtractionNotifier.new,
);

class MetadataExtractionNotifier extends Notifier<Map<int, Episode>> {
  final _pool = Pool(3);

  @override
  Map<int, Episode> build() {
    return {};
  }

  Future<void> extractMetadataForEpisode(
    Episode episode,
  ) async {
    final defaultSource = episode.defaultSource;
    if (defaultSource == null || defaultSource.messageId == null) return;
    
    final episodeId = defaultSource.messageId!;
    if (state[episodeId]?.isMetadataExtracted == true) return;
    
    final proxy = await ref.read(streamingProxyServiceProvider.future);
    final tdlib = ref.read(tdlibServiceProvider);

    final updatedSources = <VideoSource>[];

    for (final source in episode.sources) {
      if (source.hasMetadata) {
        updatedSources.add(source);
        continue;
      }

      final cached = await VideoMetadataCache.get(source.messageId);
      if (cached != null) {
        if (cached.container != VideoContainer.unknown) {
           updatedSources.add(source.copyWith(metadata: cached));
        } else {
           // It's a cached failure (unknown), keep original to not spam requests
           updatedSources.add(source);
        }
        continue;
      }

      // Need to extract
      final meta = await _pool.withResource(() async {
        return await _extractWithRetry(source, proxy, tdlib);
      });

      if (meta != null) {
        await VideoMetadataCache.save(source.messageId, meta);
        updatedSources.add(source.copyWith(metadata: meta));
      } else {
        await VideoMetadataCache.saveFailure(source.messageId);
        updatedSources.add(source);
      }
    }

    final updatedEpisode = episode.copyWith(
      sources: updatedSources,
      isMetadataExtracted: true,
    );

    state = {
      ...state,
      episodeId: updatedEpisode,
    };
  }

  Future<VideoMetadata?> _extractWithRetry(VideoSource source, StreamingProxyService proxy, TdlibService tdlib) async {
    int maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final msg = await tdlib.getMessage(source.chatId, source.messageId);
        if (msg == null) return null;

        return await _extract(source, msg, proxy);
      } catch (e, st) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('429') || errStr.contains('flood_wait') || errStr.contains('timeout')) {
          if (attempt < maxRetries) {
            Log.w('Flood wait on metadata extraction for ${source.messageId}, retrying...');
            await Future.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
        }
        Log.e('Failed to extract metadata for message ${source.messageId}', e, st);
        return null;
      }
    }
    return null;
  }

  Future<VideoMetadata?> _extract(VideoSource source, td.Message msg, StreamingProxyService proxy) async {
    try {
      final bytes = await TdlibRangeFetch.fetchPrefix(msg, proxy);
      if (bytes != null && bytes.isNotEmpty) {
        final meta = await VideoMetadataExtractor.extractFromPrefix(
          prefix: bytes, 
          mimeType: source.mimeType, 
          fileName: source.fileName,
        );
        return meta;
      }
    } catch (e) {
      if (e.toString().contains('moov_not_found')) {
        Log.i('moov not found in prefix for ${source.messageId}, fetching suffix...');
        final suffixBytes = await TdlibRangeFetch.fetchSuffix(msg, proxy);
        if (suffixBytes != null && suffixBytes.isNotEmpty) {
          return await VideoMetadataExtractor.extractFromPrefix(
            prefix: suffixBytes, 
            mimeType: source.mimeType, 
            fileName: source.fileName,
          );
        }
      } else {
        rethrow;
      }
    }
    return null;
  }
}
