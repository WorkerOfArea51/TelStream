import 'package:flutter/material.dart';

class ChangelogParser extends StatelessWidget {
  final String content;

  const ChangelogParser({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildLine(context, line)).toList(),
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    // Determine indentation before trimming
    int indentLevel = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        indentLevel++;
      } else if (line[i] == '\t') {
        indentLevel += 2; // Treat tab as 2 spaces
      } else {
        break;
      }
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox(height: 6);

    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final onSurface = theme.colorScheme.onSurface;

    // 1. Headers Check
    int hashCount = 0;
    while (hashCount < trimmed.length && trimmed[hashCount] == '#') {
      hashCount++;
    }

    if (hashCount > 0 && hashCount < trimmed.length && trimmed[hashCount] == ' ') {
      final headerText = trimmed.substring(hashCount + 1).trim();
      double fontSize = 13.5;
      FontWeight fontWeight = FontWeight.bold;
      Color color = onSurface;
      double topPadding = 12.0;
      double bottomPadding = 6.0;

      if (hashCount == 1) {
        fontSize = 19.0;
        fontWeight = FontWeight.bold;
        color = primaryColor;
        topPadding = 16.0;
        bottomPadding = 8.0;
      } else if (hashCount == 2) {
        fontSize = 16.5;
        fontWeight = FontWeight.bold;
        color = primaryColor;
        topPadding = 14.0;
        bottomPadding = 8.0;
      } else if (hashCount == 3) {
        fontSize = 14.5;
        fontWeight = FontWeight.w800;
        color = primaryColor.withValues(alpha: 0.95);
        topPadding = 12.0;
        bottomPadding = 6.0;
      } else if (hashCount == 4) {
        fontSize = 13.0;
        fontWeight = FontWeight.bold;
        color = onSurface;
        topPadding = 10.0;
        bottomPadding = 4.0;
      }

      return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Text(
          headerText,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // 2. Bullets Check
    final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('* ');
    
    // Strip bullet prefix if exists
    String displayLine = trimmed;
    if (isBullet) {
      if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        displayLine = trimmed.substring(1).trim();
      } else if (trimmed.startsWith('* ')) {
        displayLine = trimmed.substring(2).trim();
      }
    }

    final baseStyle = TextStyle(
      color: isBullet ? onSurface.withValues(alpha: 0.85) : onSurface.withValues(alpha: 0.65),
      fontSize: 12.5,
      height: 1.4,
    );

    // Padding based on indentation and bullet status
    double leftPadding = indentLevel * 4.0;
    if (isBullet) {
      leftPadding += 12.0;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: leftPadding,
        bottom: 5.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBullet)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(
                indentLevel > 0 ? Icons.radio_button_unchecked : Icons.fiber_manual_record,
                size: indentLevel > 0 ? 5.5 : 6,
                color: primaryColor,
              ),
            ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _parseFormattedText(context, displayLine, baseStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseFormattedText(BuildContext context, String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold, color: onSurface),
      ));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }
}
