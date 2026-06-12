import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:media_kit/media_kit.dart';
import 'video_player_screen.dart';

class PipVideoState {
  final int messageId;
  final int videoFileId;
  final String videoTitle;
  final List<td.Message>? episodeList;
  final int? currentEpisodeIndex;
  final String seriesName;
  final bool isPip;

  PipVideoState({
    required this.messageId,
    required this.videoFileId,
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
  });

  PipVideoState copyWith({
    int? messageId,
    int? videoFileId,
    String? videoTitle,
    List<td.Message>? episodeList,
    int? currentEpisodeIndex,
    String? seriesName,
    bool? isPip,
  }) {
    return PipVideoState(
      messageId: messageId ?? this.messageId,
      videoFileId: videoFileId ?? this.videoFileId,
      videoTitle: videoTitle ?? this.videoTitle,
      episodeList: episodeList ?? this.episodeList,
      currentEpisodeIndex: currentEpisodeIndex ?? this.currentEpisodeIndex,
      seriesName: seriesName ?? this.seriesName,
      isPip: isPip ?? this.isPip,
    );
  }
}

class PipController extends Notifier<PipVideoState?> {
  OverlayEntry? _overlayEntry;
  Player? _activePlayer;

  Player? get activePlayer => _activePlayer;

  void setActivePlayer(Player player) {
    if (_activePlayer != null && _activePlayer != player) {
      try {
        _activePlayer!.pause();
        _activePlayer!.stop();
        _activePlayer!.dispose();
      } catch (_) {}
    }
    _activePlayer = player;
  }

  void clearActivePlayer(Player player) {
    if (_activePlayer == player) {
      _activePlayer = null;
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
  }) {
    if (_activePlayer != null) {
      try {
        _activePlayer!.pause();
        _activePlayer!.stop();
        _activePlayer!.dispose();
      } catch (_) {}
      _activePlayer = null;
    }

    state = PipVideoState(
      messageId: messageId,
      videoFileId: videoFileId,
      videoTitle: videoTitle,
      episodeList: episodeList,
      currentEpisodeIndex: currentEpisodeIndex,
      seriesName: seriesName,
      isPip: false,
    );

    _showOverlay(context);
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Consumer(
          builder: (context, widgetRef, child) {
            final currentState = widgetRef.watch(pipControllerProvider);
            if (currentState == null) return const SizedBox.shrink();

            return VideoPlayerScreen(
              key: ValueKey(currentState.messageId),
              messageId: currentState.messageId,
              videoFileId: currentState.videoFileId,
              videoTitle: currentState.videoTitle,
              episodeList: currentState.episodeList,
              currentEpisodeIndex: currentState.currentEpisodeIndex,
              seriesName: currentState.seriesName,
              isPip: currentState.isPip,
            );
          },
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void minimize() {
    if (state != null) {
      state = state!.copyWith(isPip: true);
    }
  }

  void maximize() {
    if (state != null) {
      state = state!.copyWith(isPip: false);
    }
  }

  void close() {
    state = null;
    if (_activePlayer != null) {
      try {
        _activePlayer!.pause();
        _activePlayer!.stop();
        _activePlayer!.dispose();
      } catch (_) {}
      _activePlayer = null;
    }
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }
}

final pipControllerProvider = NotifierProvider<PipController, PipVideoState?>(PipController.new);
