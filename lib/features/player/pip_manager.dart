import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'video_player_screen.dart';
import '../../models/episode.dart';
import '../../models/video_source.dart';
import '../../services/storage_service.dart';
import '../../services/streaming_proxy_service.dart';
import '../../services/tdlib_service.dart';
import 'package:tdlib/td_api.dart' as td;

class PlayQueueItem {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final String seriesName;
  final String? networkUrl;
  final td.Message? message;
  final Episode? episode;
  final int selectedSourceIndex;

  PlayQueueItem({
    required this.messageId,
    required this.videoFileId,
    required this.videoTitle,
    required this.seriesName,
    this.networkUrl,
    this.message,
    this.episode,
    this.selectedSourceIndex = 0,
  });

  PlayQueueItem copyWith({
    int? messageId,
    int? videoFileId,
    String? videoTitle,
    String? seriesName,
    String? networkUrl,
    td.Message? message,
    Episode? episode,
    int? selectedSourceIndex,
  }) {
    return PlayQueueItem(
      messageId: messageId ?? this.messageId,
      videoFileId: videoFileId ?? this.videoFileId,
      videoTitle: videoTitle ?? this.videoTitle,
      seriesName: seriesName ?? this.seriesName,
      networkUrl: networkUrl ?? this.networkUrl,
      message: message ?? this.message,
      episode: episode ?? this.episode,
      selectedSourceIndex: selectedSourceIndex ?? this.selectedSourceIndex,
    );
  }
}

class PipVideoState {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<Episode>? episodeList;
  final int? currentEpisodeIndex;
  final String seriesName;
  final bool isPip;
  final String? networkUrl;
  final List<PlayQueueItem> queue;
  final int currentIndex;

  PipVideoState({
    required this.messageId,
    required this.videoFileId,
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
    this.networkUrl,
    required this.queue,
    required this.currentIndex,
  });

  PipVideoState copyWith({
    int? messageId,
    int? videoFileId,
    String? videoTitle,
    List<Episode>? episodeList,
    int? currentEpisodeIndex,
    String? seriesName,
    bool? isPip,
    String? networkUrl,
    List<PlayQueueItem>? queue,
    int? currentIndex,
  }) {
    return PipVideoState(
      messageId: messageId ?? this.messageId,
      videoFileId: videoFileId ?? this.videoFileId,
      videoTitle: videoTitle ?? this.videoTitle,
      episodeList: episodeList ?? this.episodeList,
      currentEpisodeIndex: currentEpisodeIndex ?? this.currentEpisodeIndex,
      seriesName: seriesName ?? this.seriesName,
      isPip: isPip ?? this.isPip,
      networkUrl: networkUrl ?? this.networkUrl,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class ActivePlayerNotifier extends Notifier<Player?> {
  @override
  Player? build() => null;
  void setPlayer(Player? player) => state = player;
}

final activePlayerProvider = NotifierProvider<ActivePlayerNotifier, Player?>(ActivePlayerNotifier.new);

class PipController extends Notifier<PipVideoState?> {
  bool isTransitioning = false;
  
  Player? get activePlayer => ref.read(activePlayerProvider);

  void setActivePlayer(Player player) {
    final activePlayer = ref.read(activePlayerProvider);
    if (activePlayer != null && activePlayer != player) {
      final oldPlayer = activePlayer;
      ref.read(activePlayerProvider.notifier).setPlayer(null);
      Future.microtask(() async {
        try {
          oldPlayer.setVolume(0.0);
          oldPlayer.pause();
          await oldPlayer.stop();
          await oldPlayer.dispose();
        } catch (_) {}
      });
    }
    ref.read(activePlayerProvider.notifier).setPlayer(player);
  }

  void clearActivePlayer(Player player) {
    if (ref.read(activePlayerProvider) == player) {
      Future.microtask(() {
        ref.read(activePlayerProvider.notifier).setPlayer(null);
      });
    }
  }

  @override
  PipVideoState? build() => null;

  void playVideo(BuildContext context, {
    required int messageId,
    required int videoFileId,
    String videoTitle = '',
    List<Episode>? episodeList,
    int? currentEpisodeIndex,
    String seriesName = '',
    String? networkUrl,
  }) {
    isTransitioning = true;
    final oldActivePlayer = ref.read(activePlayerProvider);
    if (oldActivePlayer != null) {
      Future.microtask(() {
        ref.read(activePlayerProvider.notifier).setPlayer(null);
      });
      try { oldActivePlayer.pause(); } catch (_) {}
    }

    final List<PlayQueueItem> initialQueue = [];
    int initialIndex = 0;

    if (episodeList != null && episodeList.isNotEmpty && currentEpisodeIndex != null) {
      if (currentEpisodeIndex < 0 || currentEpisodeIndex >= episodeList.length) {
        currentEpisodeIndex = 0;
      }
      for (int i = 0; i < episodeList.length; i++) {
        final msg = episodeList[i];
        
        initialQueue.add(PlayQueueItem(
          messageId: msg.defaultSource?.messageId ?? 0,
          videoFileId: 0,
          videoTitle: '$seriesName - ${msg.title}',
          seriesName: seriesName,
          episode: msg,
          selectedSourceIndex: 0,
          
        ));
      }
      initialIndex = currentEpisodeIndex;
    } else {
      initialQueue.add(PlayQueueItem(
        messageId: messageId,
        videoFileId: videoFileId,
        videoTitle: videoTitle,
        seriesName: seriesName,
        networkUrl: networkUrl,
      ));
      initialIndex = 0;
    }

    state = PipVideoState(
      messageId: messageId,
      videoFileId: videoFileId,
      videoTitle: videoTitle,
      episodeList: episodeList,
      currentEpisodeIndex: currentEpisodeIndex,
      seriesName: seriesName,
      isPip: false,
      networkUrl: networkUrl,
      queue: initialQueue,
      currentIndex: initialIndex,
    );

    final route = MaterialPageRoute(
      builder: (context) => VideoPlayerScreen(
        key: ValueKey(networkUrl ?? messageId.toString()),
        messageId: messageId,
        videoFileId: videoFileId,
        videoTitle: videoTitle,
        episodeList: episodeList,
        currentEpisodeIndex: currentEpisodeIndex,
        seriesName: seriesName,
        isPip: false,
        networkUrl: networkUrl,
        isDesktopMode: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      ),
    );

    if (Platform.isWindows) {
      isTransitioning = false;
    } else {
      Navigator.of(context, rootNavigator: true).push(route).then((_) {
        isTransitioning = false;
      });
    }
  }

  void playQueueIndex(BuildContext context, int index) {
    final currentState = state;
    if (currentState == null || index < 0 || index >= currentState.queue.length) return;

    final item = currentState.queue[index];

    isTransitioning = true;
    final wasPip = currentState.isPip;
    final oldActivePlayer = ref.read(activePlayerProvider);
    if (oldActivePlayer != null && !Platform.isWindows) {
      try {
        oldActivePlayer.setVolume(0.0);
        oldActivePlayer.pause();
      } catch (_) {}
    }

    state = currentState.copyWith(
      messageId: item.messageId,
      videoFileId: item.videoFileId,
      videoTitle: item.videoTitle,
      seriesName: item.seriesName,
      isPip: false,
      networkUrl: item.networkUrl,
      currentIndex: index,
    );

    final reconstructedEpisodes = currentState.queue
        .map((e) => e.episode)
        .whereType<Episode>()
        .toList();

    final route = MaterialPageRoute(
      builder: (context) => VideoPlayerScreen(
        key: ValueKey(item.networkUrl ?? item.messageId.toString()),
        messageId: item.messageId,
        videoFileId: item.videoFileId,
        videoTitle: item.videoTitle,
        episodeList: reconstructedEpisodes.isNotEmpty ? reconstructedEpisodes : null,
        currentEpisodeIndex: index,
        seriesName: item.seriesName,
        isPip: false,
        networkUrl: item.networkUrl,
        isDesktopMode: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      ),
    );

    if (Platform.isWindows) {
      isTransitioning = false;
    } else if (oldActivePlayer != null && !wasPip) {
      Navigator.of(context, rootNavigator: true).pushReplacement(route).then((_) {
        isTransitioning = false;
      });
    } else {
      Navigator.of(context, rootNavigator: true).push(route).then((_) {
        isTransitioning = false;
      });
    }
  }

  /// Switches the current player's media to [newSource] in-place — no Navigator
  /// rebuild, no Player disposal. Preserves the current playback position by
  /// capturing it before the swap and seeking after the new media is loaded.
  /// 
  /// Returns the new playback position (in seconds) so the caller can show a
  /// brief overlay ("Switched to 1080p @ 12:34") if desired.
  Future<int> switchQualityInPlace(VideoSource newSource) async {
    final currentState = state;
    if (currentState == null) return 0;
    
    final player = ref.read(activePlayerProvider);
    if (player == null) return 0;
    
    final currentItem = currentState.queue[currentState.currentIndex];
    final episode = currentItem.episode;
    if (episode == null) return 0;
    
    // 1. Capture current position BEFORE any state change.
    final position = player.state.position.inSeconds;
    final duration = player.state.duration.inSeconds;
    
    // 2. Update the queue item to point at the new source.
    final selectedIndex = episode.sources.indexOf(newSource);
    final updatedItem = currentItem.copyWith(
      messageId: newSource.messageId,
      selectedSourceIndex: selectedIndex >= 0 ? selectedIndex : 0,
    );
    final newQueue = List<PlayQueueItem>.from(currentState.queue);
    newQueue[currentState.currentIndex] = updatedItem;
    state = currentState.copyWith(
      queue: newQueue,
      messageId: newSource.messageId,
    );
    
    // 3. Build the new proxy URL for the new source.
    final proxy = ref.read(streamingProxyServiceProvider).requireValue;
    final tdlib = ref.read(tdlibServiceProvider);
    final tdMsg = await tdlib.getMessage(newSource.chatId, newSource.messageId);
    if (tdMsg == null) return position;
    
    td.File? tdFile;
    if (tdMsg.content is td.MessageVideo) {
      tdFile = (tdMsg.content as td.MessageVideo).video.video;
    } else if (tdMsg.content is td.MessageDocument) {
      tdFile = (tdMsg.content as td.MessageDocument).document.document;
    }
    if (tdFile == null) return position;
    
    final newUrl = proxy.getProxyUrl(tdFile.id);
    
    // 4. Open the new media in the SAME player. Player.open with [play: false]
    //    loads the media without auto-playing, so we can seek first.
    await player.open(Media(newUrl, httpHeaders: proxy.getAuthHeaders()), play: false);
    
    // 5. Seek to the captured position.
    if (position > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      await player.seek(Duration(seconds: position));
    }
    
    // 6. Resume playback.
    await player.play();
    
    // 7. Persist the position to storage
    if (position > 0) {
      final storage = ref.read(storageServiceProvider);
      storage.saveWatchPosition(newSource.messageId, position);
      if (duration > 0) {
        storage.saveVideoDuration(newSource.messageId, duration);
      }
    }
    
    return position;
  }

  void addToQueue(PlayQueueItem item) {
    final currentState = state;
    if (currentState == null) return;
    final newQueue = List<PlayQueueItem>.from(currentState.queue)..add(item);
    state = currentState.copyWith(queue: newQueue);
  }

  void insertNext(PlayQueueItem item) {
    final currentState = state;
    if (currentState == null) return;
    final newQueue = List<PlayQueueItem>.from(currentState.queue);
    final insertIdx = currentState.currentIndex + 1;
    if (insertIdx >= newQueue.length) {
      newQueue.add(item);
    } else {
      newQueue.insert(insertIdx, item);
    }
    state = currentState.copyWith(queue: newQueue);
  }

  void removeFromQueue(int index) {
    final currentState = state;
    if (currentState == null) return;
    if (index < 0 || index >= currentState.queue.length) return;
    if (index == currentState.currentIndex) return;

    final newQueue = List<PlayQueueItem>.from(currentState.queue)..removeAt(index);
    final newIndex = index < currentState.currentIndex ? currentState.currentIndex - 1 : currentState.currentIndex;
    state = currentState.copyWith(queue: newQueue, currentIndex: newIndex);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final currentState = state;
    if (currentState == null) return;
    
    final newQueue = List<PlayQueueItem>.from(currentState.queue);
    int targetNewIndex = newIndex;
    if (oldIndex < newIndex) {
      targetNewIndex -= 1;
    }
    
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(targetNewIndex, item);
    
    int newCurrentIndex = currentState.currentIndex;
    if (currentState.currentIndex == oldIndex) {
      newCurrentIndex = targetNewIndex;
    } else if (oldIndex < currentState.currentIndex && targetNewIndex >= currentState.currentIndex) {
      newCurrentIndex -= 1;
    } else if (oldIndex > currentState.currentIndex && targetNewIndex <= currentState.currentIndex) {
      newCurrentIndex += 1;
    }
    
    state = currentState.copyWith(queue: newQueue, currentIndex: newCurrentIndex);
  }

  void minimize() {
    close();
  }

  void maximize() {}



  void close() {
    state = null;
    final activePlayer = ref.read(activePlayerProvider);
    if (activePlayer != null) {
      final playerToDispose = activePlayer;
      Future.microtask(() {
        ref.read(activePlayerProvider.notifier).setPlayer(null);
      });
      try {
        playerToDispose.setVolume(0.0);
      } catch (_) {}
      try {
        playerToDispose.pause();
      } catch (_) {}
      try {
        playerToDispose.stop();
      } catch (_) {}
      try {
        playerToDispose.dispose();
      } catch (_) {}
    }
  }
}

final pipControllerProvider = NotifierProvider<PipController, PipVideoState?>(PipController.new);
