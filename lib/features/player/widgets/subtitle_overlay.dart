import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:telstream/providers/video_settings_provider.dart';

class SubtitleOverlay extends ConsumerStatefulWidget {
  final Player player;

  const SubtitleOverlay({
    super.key,
    required this.player,
  });

  @override
  ConsumerState<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends ConsumerState<SubtitleOverlay> {
  double? _dragBottomMargin;
  double? _dragHorizontalOffset;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(videoSettingsProvider);
    final subSize = settings.subtitleFontSize;
    final subFont = settings.subtitleFont;
    final subColorStr = settings.subtitleColor;
    Color subColor = Colors.white;
    try {
      final cleanHex = subColorStr.replaceAll('#', '');
      subColor = Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {}

    return StreamBuilder<List<String>>(
      stream: widget.player.stream.subtitle,
      builder: (context, snapshot) {
        final subtitleLines = snapshot.data;
        if (subtitleLines == null || subtitleLines.isEmpty) {
          return const Positioned(child: SizedBox.shrink());
        }

        final subtitleText = subtitleLines.join('\n');
        // Strip any raw ASS/SSA tags (like {\an8}, {\pos(x,y)}, etc.) to keep plain text clean in overlay mode
        final cleanText = subtitleText
            .replaceAll(RegExp(r'\{[^}]*\}'), '')
            .trim();
        if (cleanText.isEmpty) {
          return const Positioned(child: SizedBox.shrink());
        }

        final activeBottomMargin =
            _dragBottomMargin ?? settings.subtitleBottomMargin;
        final activeHorizontalOffset =
            _dragHorizontalOffset ?? settings.subtitleHorizontalOffset;
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return Positioned(
          bottom: activeBottomMargin,
          left: 24.0 + activeHorizontalOffset,
          right: 24.0 - activeHorizontalOffset,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _dragBottomMargin = settings.subtitleBottomMargin;
                _dragHorizontalOffset = settings.subtitleHorizontalOffset;
              },
              onPanUpdate: (details) {
                setState(() {
                  _dragBottomMargin = (_dragBottomMargin! - details.delta.dy).clamp(
                    10.0,
                    screenHeight - 120.0,
                  );
                  _dragHorizontalOffset = (_dragHorizontalOffset! + details.delta.dx).clamp(
                    -screenWidth / 2 + 50.0,
                    screenWidth / 2 - 50.0,
                  );
                });
              },
              onPanEnd: (_) {
                if (_dragBottomMargin != null && _dragHorizontalOffset != null) {
                  ref.read(videoSettingsProvider.notifier).updateSettings(
                        settings.copyWith(
                          subtitleBottomMargin: _dragBottomMargin,
                          subtitleHorizontalOffset: _dragHorizontalOffset,
                        ),
                      );
                }
                setState(() {
                  _dragBottomMargin = null;
                  _dragHorizontalOffset = null;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: settings.subtitleBackgroundOpacity),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cleanText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subColor,
                      fontSize: subSize,
                      fontWeight: FontWeight.w600,
                      fontFamily: subFont,
                      height: 1.3,
                      shadows: [
                        if (settings.subtitleBackgroundOpacity < 0.5) ...[
                          const Shadow(
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                            color: Colors.black,
                          ),
                          const Shadow(
                            offset: Offset(-1.0, -1.0),
                            blurRadius: 3.0,
                            color: Colors.black,
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
