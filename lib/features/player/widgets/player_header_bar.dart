import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/expressive_container.dart';

class PlayerHeaderBar extends StatelessWidget {
  final String videoTitle;
  final VoidCallback onBack;
  final int? sleepTimerSecondsRemaining;
  final String Function(int) formatSleepTimeRemaining;
  final String decoderModeLabel;
  final VoidCallback onToggleDecoderMode;
  final VoidCallback onShowSubtitles;
  final VoidCallback onShowAudioTracks;
  final VoidCallback onShowQueue;
  final VoidCallback onShowMoreOptions;
  final Widget quickActionRow;
  final Color settingsAccent;

  const PlayerHeaderBar({
    super.key,
    required this.videoTitle,
    required this.onBack,
    required this.sleepTimerSecondsRemaining,
    required this.formatSleepTimeRemaining,
    required this.decoderModeLabel,
    required this.onToggleDecoderMode,
    required this.onShowSubtitles,
    required this.onShowAudioTracks,
    required this.onShowQueue,
    required this.onShowMoreOptions,
    required this.quickActionRow,
    required this.settingsAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: MarqueeText(
                text: videoTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sleepTimerSecondsRemaining != null) ...[
                  Text(
                    formatSleepTimeRemaining(sleepTimerSecondsRemaining!),
                    style: TextStyle(
                      color: settingsAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                // HW+ Decoder Mode Button
                Material3ExpressiveContainer(
                  shape: ExpressiveShape.squircle,
                  size: 38,
                  onTap: onToggleDecoderMode,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  child: Center(
                    child: Text(
                      decoderModeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // CC Subtitles Button
                Material3ExpressiveContainer(
                  shape: ExpressiveShape.squircle,
                  size: 38,
                  onTap: onShowSubtitles,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.closed_caption_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),

                // Music Audio Tracks Button
                Material3ExpressiveContainer(
                  shape: ExpressiveShape.squircle,
                  size: 38,
                  onTap: onShowAudioTracks,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.music_note_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),

                // Playlist / Queue Button
                Material3ExpressiveContainer(
                  shape: ExpressiveShape.squircle,
                  size: 38,
                  onTap: onShowQueue,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.playlist_play_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),

                // More Options Button (Vertical 3 dots)
                Material3ExpressiveContainer(
                  shape: ExpressiveShape.squircle,
                  size: 38,
                  onTap: onShowMoreOptions,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
        quickActionRow,
      ],
    );
  }
}

/// Custom self-contained scrolling text widget for long file titles.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _scrollController.jumpTo(0.0);
      _startScrolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || !_scrollController.hasClients) return;
      if (_isScrolling) return;

      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      _isScrolling = true;
      
      // Wait a moment at the start
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) {
        _isScrolling = false;
        return;
      }

      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) {
        _isScrolling = false;
        return;
      }

      // Scroll to the end
      final duration = Duration(milliseconds: (currentMax * 35).clamp(1000, 20000).toInt());
      await _scrollController.animateTo(
        currentMax,
        duration: duration,
        curve: Curves.linear,
      );

      // Wait a moment at the end
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) {
        _isScrolling = false;
        return;
      }

      // Slide back to start
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
      );

      _isScrolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
