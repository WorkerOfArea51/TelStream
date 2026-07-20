import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class SubtitleColorDialog extends StatefulWidget {
  final String current;
  final double currentSize;
  final String currentFont;
  final Color accentColor;

  const SubtitleColorDialog({super.key, 
    required this.current,
    required this.currentSize,
    required this.currentFont,
    required this.accentColor,
  });

  @override
  State<SubtitleColorDialog> createState() => SubtitleColorDialogState();
}

class SubtitleColorDialogState extends State<SubtitleColorDialog> {
  late String _selectedHex;
  final _customController = TextEditingController();

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
    _selectedHex = widget.current.toUpperCase();
    if (!_selectedHex.startsWith('#')) {
      _selectedHex = '#$_selectedHex';
    }
    _customController.text = _selectedHex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    final List<Map<String, String>> predefinedColors = [
      {'name': l10n.colorWhite, 'hex': '#FFFFFF'},
      {'name': l10n.colorYellow, 'hex': '#FFFF00'},
      {'name': l10n.colorGreen, 'hex': '#00FF00'},
      {'name': l10n.colorCyan, 'hex': '#00FFFF'},
      {'name': l10n.colorRed, 'hex': '#FF0000'},
      {'name': l10n.colorLightBlue, 'hex': '#33B5E5'},
      {'name': l10n.colorAmber, 'hex': '#FFBB33'},
    ];
    
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
      title: Text(l10n.subtitleColorDialogTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              height: 100,
              width: double.maxFinite,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 4, left: 4,
                    child: Text(l10n.preview, style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ),
                  Center(
                    child: Text(
                      l10n.sampleSubtitleText,
                      style: TextStyle(
                        fontSize: widget.currentSize,
                        color: _parseHexColor(_selectedHex),
                        fontFamily: resolvedFontFamily,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                          Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                          Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                          Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.colorPresets, style: TextStyle(color: widget.accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: predefinedColors.map((colorMap) {
                final color = _parseHexColor(colorMap['hex']!);
                final isSelected = _selectedHex == colorMap['hex'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedHex = colorMap['hex']!;
                      _customController.text = _selectedHex;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? widget.accentColor.withValues(alpha: 0.2) : Colors.transparent,
                      border: Border.all(color: isSelected ? widget.accentColor : theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(colorMap['name']!, style: TextStyle(color: isSelected ? widget.accentColor : (isDark ? Colors.white70 : Colors.black87), fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _customController,
              decoration: InputDecoration(
                labelText: l10n.customColorHex,
                labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.accentColor),
                ),
                prefixIcon: Icon(Icons.color_lens, color: widget.accentColor),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: (val) {
                if (val.length >= 7) {
                  setState(() {
                    _selectedHex = val.toUpperCase();
                    if (!_selectedHex.startsWith('#')) {
                      _selectedHex = '#$_selectedHex';
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedHex),
          child: Text(l10n.save, style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}
