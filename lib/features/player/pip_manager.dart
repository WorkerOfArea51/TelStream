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
    String? networkUrl,
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
      networkUrl: networkUrl,
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

            final playerWidget = VideoPlayerScreen(
              key: ValueKey(currentState.networkUrl ?? currentState.messageId.toString()),
              messageId: currentState.messageId,
              videoFileId: currentState.videoFileId,
              videoTitle: currentState.videoTitle,
              episodeList: currentState.episodeList,
              currentEpisodeIndex: currentState.currentEpisodeIndex,
              seriesName: currentState.seriesName,
              isPip: currentState.isPip,
              networkUrl: currentState.networkUrl,
            );

            if (currentState.isPip) {
              return PositionedPipWrapper(
                onClose: () {
                  widgetRef.read(pipControllerProvider.notifier).close();
                },
                child: playerWidget,
              );
            } else {
              return playerWidget;
            }
          },
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void minimize() {
    close();
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

class PositionedPipWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onClose;

  const PositionedPipWrapper({
    Key? key,
    required this.child,
    required this.onClose,
  }) : super(key: key);

  @override
  State<PositionedPipWrapper> createState() => _PositionedPipWrapperState();
}

class _PositionedPipWrapperState extends State<PositionedPipWrapper> {
  double? _x;
  double? _y;
  Size? _lastScreenSize;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    const double pipWidth = 240.0;
    const double pipHeight = 135.0;

    final double minX = 8.0;
    final double maxX = screenSize.width - pipWidth - 8.0;
    final double minY = mediaQuery.padding.top + 8.0;
    final double maxY = screenSize.height - pipHeight - 16.0;

    // Adapt coordinates proportionally on screen rotation
    if (_lastScreenSize != null && _lastScreenSize != screenSize) {
      if (_x != null && _y != null) {
        final double rx = _x! / _lastScreenSize!.width;
        final double ry = _y! / _lastScreenSize!.height;
        _x = (rx * screenSize.width).clamp(minX, maxX);
        _y = (ry * screenSize.height).clamp(minY, maxY);
      }
    }
    _lastScreenSize = screenSize;

    // Default position: bottom-right (bottom: 90, right: 16)
    if (_x == null || _y == null) {
      _x = screenSize.width - pipWidth - 16.0;
      _y = screenSize.height - pipHeight - 90.0;
    }

    return Positioned(
      left: _x,
      top: _y,
      width: pipWidth,
      height: pipHeight,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x = (_x! + details.delta.dx).clamp(minX, maxX);
            _y = _y! + details.delta.dy;
            if (_y! < minY) _y = minY;
          });
        },
        onPanEnd: (details) {
          // If the center of the PIP is dragged past 82% of screen height, dismiss
          final dismissThreshold = screenSize.height * 0.82;
          if (_y! + (pipHeight / 2) > dismissThreshold) {
            widget.onClose();
          } else {
            // Animate/snap back inside screen bounds
            setState(() {
              if (_y! > maxY) {
                _y = maxY;
              }
            });
          }
        },
        child: widget.child,
      ),
    );
  }
}
