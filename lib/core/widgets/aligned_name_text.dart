import 'package:flutter/material.dart';

class AlignedNameText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const AlignedNameText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final emojiRegex = RegExp(
      r'^([🎬📽🎥📺🎞🎭🏁🔥⭐✨🍿]+)\s*(.*)$',
    );
    final match = emojiRegex.firstMatch(text);

    if (match != null && match.group(1) != null) {
      final emoji = match.group(1)!;
      final remainingText = match.group(2) ?? '';
      
      if (remainingText.trim().isNotEmpty) {
        return RichText(
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          text: TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: (style.fontSize ?? 14) * 1.1,
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: remainingText,
                style: style,
              ),
            ],
          ),
        );
      }
    }

    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
