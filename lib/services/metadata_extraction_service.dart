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
import '../features/home/home_controller.dart';

final metadataExtractionServiceProvider = NotifierProvider<MetadataExtractionNotifier, Map<int, Episode>>(
  MetadataExtractionNotifier.new,
);

class MetadataExtractionNotifier extends Notifier<Map<int, Episode>> {
  final _pool = Pool(3);

  @override
  Map<int, Episode> build() {
    return {};
  }

  /// Stable key for an episode = messageId of its FIRST source (creation order,
  /// not quality order). This key does NOT shift as metadata arrives.
  int _episodeKey(Episode episode) {
    if (episode.sources.isEmpty) return -1;
    return episode.sources.first.messageId;
  }

  /// Fire-and-forget prefetch for an episode that's about to be shown.
  /// Useful when navigating into a series detail screen — start extraction
  /// for the first N episodes immediately.
  Future<void> prefetchEpisode(Episode episode) async {
    // Same as extractMetadataForEpisode but never throws and is silently
    // swallowed if the pool is saturated.
    try {
      await extractMetadataForEpisode(episode);
    } catch (e, st) {
      Log.e('prefetchEpisode failed silently', e, st);
    }
  }

  /// Invalidate the cached metadata for a single messageId. The next time
  /// the corresponding episode is rendered, extraction will run fresh.
  Future<void> invalidate(int messageId) async {
    await VideoMetadataCache.clearForMessage(messageId);
    // Also clear the in-memory marker so extractMetadataForEpisode re-runs.
    final keysToRemove = <int>[];
    state.forEach((key, ep) {
      if (ep.sources.any((s) => s.messageId == messageId)) {
        keysToRemove.add(key);
      }
    });
    if (keysToRemove.isNotEmpty) {
      final newState = Map<int, Episode>.from(state);
      for (final k in keysToRemove) {
        final ep = newState[k]!;
        newState[k] = ep.copyWith(
          sources: ep.sources.map((s) {
            if (s.messageId == messageId) return s.copyWith(metadata: null);
            return s;
          }).toList(),
          isMetadataExtracted: false,
        );
      }
      state = newState;
    }
  }

  /// Invalidate every episode in the given list. Used by "Clear all metadata"
  /// in Settings.
  Future<void> invalidateAll(List<Episode> episodes) async {
    await VideoMetadataCache.clearAll();
    state = {};
  }

  Future<void> extractMetadataForEpisode(Episode episode) async {
    if (episode.sources.isEmpty) return;

    final episodeKey = _episodeKey(episode);
    if (episodeKey < 0) return;
    if (state[episodeKey]?.isMetadataExtracted == true) return;

    final proxy = await ref.read(streamingProxyServiceProvider.future);
    final tdlib = ref.read(tdlibServiceProvider);

    final updatedSources = <VideoSource>[];
    bool anyChanged = false;

    for (final source in episode.sources) {
      // Skip if we already have FULL metadata (container known + height > 0).
      // For MessageVideo, TDLib gives us height/width/duration but container
      // is unknown — we still want to parse the container to get the codec.
      if (source.hasMetadata && source.metadata!.container != VideoContainer.unknown) {
        updatedSources.add(source);
        continue;
      }

      final cached = await VideoMetadataCache.get(source.messageId);
      switch (cached) {
        case CachedMetadata(:final metadata):
          updatedSources.add(source.copyWith(metadata: metadata));
          anyChanged = true;
          continue;
        case CachedFailure():
          updatedSources.add(source);
          continue;
        case CacheMiss():
          break; // fall through to extraction below
      }

      // Need to extract
      final meta = await _pool.withResource(() async {
        return await _extractWithRetry(source, proxy, tdlib);
      });

      if (meta != null) {
        await VideoMetadataCache.save(source.messageId, meta);
        updatedSources.add(source.copyWith(metadata: meta));
        anyChanged = true;
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
      episodeKey: updatedEpisode,
    };

    // Propagate only to controllers that actually contain this episode.
    // (Calling updateEpisode on a controller whose category doesn't contain
    // the episode is a no-op but wasteful — it walks the entire catalog.)
    if (anyChanged) {
      final controllers = [
        ref.read(animeControllerProvider.notifier),
        ref.read(moviesControllerProvider.notifier),
        ref.read(webSeriesControllerProvider.notifier),
      ];
      for (final controller in controllers) {
        await controller.updateEpisode(
          episodeKey,
          (existing) => existing.copyWith(
            sources: _mergeSources(existing.sources, updatedSources),
            isMetadataExtracted: true,
          ),
        );
      }
    }
  }

  /// Merge freshly-extracted sources into the existing list without losing
  /// any sources the grouper may have added between extraction start and end.
  List<VideoSource> _mergeSources(
    List<VideoSource> existing,
    List<VideoSource> updated,
  ) {
    final byId = {for (final s in existing) s.messageId: s};
    for (final u in updated) {
      final prev = byId[u.messageId];
      if (prev == null) {
        byId[u.messageId] = u;
      } else if (u.hasMetadata) {
        // Container-parsed metadata is more detailed than TDLib's initial
        // metadata (it includes container type + codec). But preserve the
        // TDLib-provided duration and minithumbnail if the parsed metadata
        // doesn't have them.
        final mergedMetadata = u.metadata!;
        final finalMetadata = (mergedMetadata.durationMillis > 0 || prev.tdlibDurationSeconds == null)
            ? mergedMetadata
            : mergedMetadata.copyWith(
                durationMillis: prev.tdlibDurationSeconds! * 1000,
              );
        byId[u.messageId] = u.copyWith(metadata: finalMetadata);
      } else {
        // Extraction failed — keep the existing source (which may have
        // TDLib-provided initial metadata).
        byId[u.messageId] = prev;
      }
    }
    // Preserve original insertion order.
    return existing.map((e) => byId[e.messageId]!).toList()
      ..addAll(updated.where((u) => !existing.any((e) => e.messageId == u.messageId)));
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
    // 1. Try prefix (first 2 MB).
    try {
      final prefixBytes = await TdlibRangeFetch.fetchPrefix(msg, proxy);
      if (prefixBytes != null && prefixBytes.isNotEmpty) {
        final meta = await VideoMetadataExtractor.extractFromPrefix(
          prefix: prefixBytes,
          mimeType: source.mimeType,
          fileName: source.fileName,
        );
        if (meta != null) return meta;
      }
    } catch (e) {
      // Fall through to suffix attempt below.
      if (!e.toString().contains('moov_not_found')) {
        Log.w('Prefix extraction error for ${source.messageId}: $e');
      }
    }

    // 2. For MP4/MOV/M4V only, retry with the suffix (last 2 MB) — moov is at end.
    final lowerName = source.fileName.toLowerCase();
    final lowerMime = source.mimeType.toLowerCase();
    final isMp4Family = lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.m4v') ||
        lowerMime == 'video/mp4';
    if (!isMp4Family) return null;

    Log.i('moov not found in prefix for ${source.messageId}, fetching suffix...');
    try {
      final suffixBytes = await TdlibRangeFetch.fetchSuffix(msg, proxy);
      if (suffixBytes != null && suffixBytes.isNotEmpty) {
        return await VideoMetadataExtractor.extractFromSuffix(
          suffix: suffixBytes,
          mimeType: source.mimeType,
          fileName: source.fileName,
        );
      }
    } catch (e, st) {
      Log.e('Suffix extraction failed for ${source.messageId}', e, st);
    }
    return null;
  }
}
