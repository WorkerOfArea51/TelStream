import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import 'player_playback_bar.dart';

class ChaptersPanel extends StatefulWidget {
  final Player player;
  final List<VideoChapter> chapters;
  final VoidCallback onVisibilityChanged;
  final void Function(Duration position, String chapterTitle) onChapterSelected;

  const ChaptersPanel({
    super.key,
    required this.player,
    required this.chapters,
    required this.onVisibilityChanged,
    required this.onChapterSelected,
  });

  @override
  ChaptersPanelState createState() => ChaptersPanelState();
}

class ChaptersPanelState extends State<ChaptersPanel> {
  bool isVisible = false;

  void show() {
    if (!isVisible) {
      setState(() => isVisible = true);
      widget.onVisibilityChanged();
    }
  }

  void hide() {
    if (isVisible) {
      setState(() => isVisible = false);
      widget.onVisibilityChanged();
    }
  }

  bool _isChapterIntro(VideoChapter ch, double start, double end) {
    final titleLower = ch.title.toLowerCase().trim();
    return titleLower.contains('intro') ||
        titleLower.contains('opening') ||
        titleLower.contains('theme') ||
        titleLower.contains('title sequence') ||
        titleLower.contains('main title') ||
        titleLower.contains('title screen') ||
        titleLower.contains('opening credits') ||
        titleLower == 'op' ||
        titleLower.startsWith('op ') ||
        titleLower.endsWith(' op') ||
        titleLower.contains('op 1') ||
        titleLower.contains('op 2') ||
        titleLower.contains('op1') ||
        titleLower.contains('op2');
  }

  bool _isChapterOutro(
    VideoChapter ch,
    double start,
    double end,
    double totalDuration,
  ) {
    final titleLower = ch.title.toLowerCase().trim();
    return titleLower.contains('outro') ||
        titleLower.contains('ending') ||
        titleLower.contains('credits') ||
        titleLower.contains('credit') ||
        titleLower.contains('closing') ||
        titleLower.contains('post-credits') ||
        titleLower.contains('preview') ||
        titleLower.contains('teaser') ||
        titleLower.contains('epilogue') ||
        titleLower == 'ed' ||
        titleLower.startsWith('ed ') ||
        titleLower.endsWith(' ed') ||
        titleLower.contains('ed 1') ||
        titleLower.contains('ed 2') ||
        titleLower.contains('ed1') ||
        titleLower.contains('ed2');
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    final currentPos = widget.player.state.position;
    int activeIndex = -1;
    for (int i = 0; i < widget.chapters.length; i++) {
      final start = widget.chapters[i].position;
      final end = (i + 1 < widget.chapters.length)
          ? widget.chapters[i + 1].position
          : widget.player.state.duration;
      if (currentPos >= start && currentPos < end) {
        activeIndex = i;
        break;
      }
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final panelContent = ClipRRect(
      borderRadius: isPortrait
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : const BorderRadius.horizontal(left: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          height: isPortrait ? 340 : double.infinity,
          decoration: BoxDecoration(
            color: const Color(0x990A0F1D), // Slate 950 with 60% opacity for premium glassmorphism
            borderRadius: isPortrait
                ? const BorderRadius.vertical(top: Radius.circular(24))
                : const BorderRadius.horizontal(left: Radius.circular(30)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.list, color: settingsAccent, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Chapters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: hide,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: widget.chapters.isEmpty
                      ? const Center(
                          child: Text(
                            'No chapters available',
                            style: TextStyle(color: Colors.white38, fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: widget.chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = widget.chapters[index];
                            final isSelected = index == activeIndex;

                            final start = chapter.position.inSeconds.toDouble();
                            final totalDuration = widget.player.state.duration.inSeconds.toDouble();
                            final end = (index + 1 < widget.chapters.length)
                                ? widget.chapters[index + 1].position.inSeconds.toDouble()
                                : (totalDuration > 0 ? totalDuration : start + 90.0);

                            String displayTitle = chapter.title;
                            if (_isChapterIntro(chapter, start, end)) {
                              displayTitle = 'Intro';
                            } else if (_isChapterOutro(chapter, start, end, totalDuration)) {
                              displayTitle = 'Credits';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  widget.onChapterSelected(chapter.position, displayTitle);
                                  hide();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? settingsAccent.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? settingsAccent.withValues(alpha: 0.4)
                                          : Colors.white.withValues(alpha: 0.05),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? settingsAccent.withValues(alpha: 0.2)
                                              : Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _formatDuration(chapter.position),
                                          style: TextStyle(
                                            color: isSelected ? settingsAccent : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          displayTitle,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.play_arrow_rounded, color: settingsAccent, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        if (isVisible)
          GestureDetector(
            onTap: hide,
            child: Container(color: Colors.black26),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: isPortrait ? 0 : null,
          right: isPortrait ? 0 : (isVisible ? 0 : -380),
          top: isPortrait ? null : 0,
          bottom: isPortrait ? (isVisible ? 0 : -800) : 0,
          width: isPortrait ? null : 380,
          child: StreamBuilder<Duration>(
            stream: widget.player.stream.position,
            builder: (context, snapshot) => panelContent,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }
}
