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
  final String? networkUrl;

  PipVideoState({
    required this.messageId,
    required this.videoFileId,
    this.videoTitle = '',
    this.episodeList,
    this.currentEpisodeIndex,
    this.seriesName = '',
    this.isPip = false,
    this.networkUrl,
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
    );
  }
}

class PipController extends Notifier<PipVideoState?> {
  Player? _activePlayer;
  bool isTransitioning = false;

  Player? get activePlayer => _activePlayer;

  void setActivePlayer(Player player) {
    if (_activePlayer != null && _activePlayer != player) {
      try {
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
    String? networkUrl,
  }) {
    isTransitioning = true;
    final oldActivePlayer = _activePlayer;
    if (oldActivePlayer != null) {
      try {
        oldActivePlayer.dispose();
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
      networkUrl: networkUrl,
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

    if (oldActivePlayer != null) {
      Navigator.of(context, rootNavigator: true).pushReplacement(route);
    } else {
      Navigator.of(context, rootNavigator: true).push(route);
    }
  }

  void minimize() {
    close();
  }

  void maximize() {}

  void close() {
    state = null;
    if (_activePlayer != null) {
      try {
        _activePlayer!.dispose();
      } catch (_) {}
      _activePlayer = null;
    }
  }
}

final pipControllerProvider = NotifierProvider<PipController, PipVideoState?>(PipController.new);
