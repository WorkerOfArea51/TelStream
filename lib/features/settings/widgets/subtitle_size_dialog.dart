import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class SubtitleSizeDialog extends StatefulWidget {
  final double current;
  final String currentColor;
  final String currentFont;
  final Color accentColor;

  const SubtitleSizeDialog({super.key, 
    required this.current,
    required this.currentColor,
    required this.currentFont,
    required this.accentColor,
  });

  @override
  State<SubtitleSizeDialog> createState() => SubtitleSizeDialogState();
}

class SubtitleSizeDialogState extends State<SubtitleSizeDialog> {
  late double _value;

  Color _parseHexColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _value = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    String resolvedFontFamily = 'Roboto';
    if (widget.currentFont.toLowerCase().contains('arial')) {
      resolvedFontFamily = 'Arial';
    } else if (widget.currentFont.toLowerCase().contains('dejavu')) {
      resolvedFontFamily = 'DejaVuSans';
    } else if (widget.currentFont.toLowerCase().contains('sans-serif')) {
      resolvedFontFamily = 'sans-serif';
    } else if (widget.currentFont.toLowerCase().contains('roboto')) {
      resolvedFontFamily = 'Roboto';
    }

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text(l10n.subtitleFontSizeDialogTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.helloWorld,
              style: TextStyle(
                fontSize: _value,
                color: _parseHexColor(widget.currentColor),
                fontFamily: resolvedFontFamily,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                  Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                  Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.nPixels(_value.toInt()), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
          Slider(
            value: _value,
            min: 15,
            max: 80,
            divisions: 65,
            activeColor: widget.accentColor,
            onChanged: (val) {
              setState(() {
                _value = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: Text(l10n.save, style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}
