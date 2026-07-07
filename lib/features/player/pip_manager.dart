import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:media_kit/media_kit.dart';
import 'video_player_screen.dart';

class PlayQueueItem {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final String seriesName;
  final String? networkUrl;
  final td.Message? message;

  PlayQueueItem({
    required this.messageId,
    required this.videoFileId,
    required this.videoTitle,
    required this.seriesName,
    this.networkUrl,
    this.message,
  });

  PlayQueueItem copyWith({
    int? messageId,
    int? videoFileId,
    String? videoTitle,
    String? seriesName,
    String? networkUrl,
    td.Message? message,
  }) {
    return PlayQueueItem(
      messageId: messageId ?? this.messageId,
      videoFileId: videoFileId ?? this.videoFileId,
      videoTitle: videoTitle ?? this.videoTitle,
      seriesName: seriesName ?? this.seriesName,
      networkUrl: networkUrl ?? this.networkUrl,
      message: message ?? this.message,
    );
  }
}

class PipVideoState {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<td.Message>? episodeList;
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
    List<td.Message>? episodeList,
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
    final _activePlayer = ref.read(activePlayerProvider);
    if (_activePlayer != null && _activePlayer != player) {
      final oldPlayer = _activePlayer;
      try {
        oldPlayer.setVolume(0.0);
      } catch (_) {}
      try {
        oldPlayer.pause();
      } catch (_) {}
      try {
        oldPlayer.stop();
      } catch (_) {}
    }
    Future.microtask(() {
      ref.read(activePlayerProvider.notifier).setPlayer(player);
    });
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
    List<td.Message>? episodeList,
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
        int? fileId;
        String title = 'Episode ${i + 1}';
        
        if (msg.content is td.MessageVideo) {
          final v = msg.content as td.MessageVideo;
          fileId = v.video.video.id;
          title = v.video.fileName;
        } else if (msg.content is td.MessageDocument) {
          final d = msg.content as td.MessageDocument;
          fileId = d.document.document.id;
          title = d.document.fileName;
        }

        initialQueue.add(PlayQueueItem(
          messageId: msg.id,
          videoFileId: fileId ?? 0,
          videoTitle: '$seriesName - $title',
          seriesName: seriesName,
          message: msg,
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
      ),
    );

    // Always push the player screen when launching from lists/detail screens to preserve back navigation history
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
    if (oldActivePlayer != null) {
      Future.microtask(() {
        ref.read(activePlayerProvider.notifier).setPlayer(null);
      });
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

    // Reconstruct episodeList parameter for compatibility
    final reconstructedEpisodes = currentState.queue
        .map((e) => e.message)
        .whereType<td.Message>()
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
    final _activePlayer = ref.read(activePlayerProvider);
    if (_activePlayer != null) {
      final playerToDispose = _activePlayer;
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
    }
  }
}

final pipControllerProvider = NotifierProvider<PipController, PipVideoState?>(PipController.new);
