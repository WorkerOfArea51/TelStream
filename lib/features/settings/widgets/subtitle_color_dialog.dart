import 'package:flutter/material.dart';
class SubtitleColorDialog extends StatefulWidget {
  final String current;
  final double currentSize;
  final String currentFont;
  final Color accentColor;

  const SubtitleColorDialog({
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

  final List<Map<String, String>> _predefinedColors = [
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Yellow', 'hex': '#FFFF00'},
    {'name': 'Green', 'hex': '#00FF00'},
    {'name': 'Cyan', 'hex': '#00FFFF'},
    {'name': 'Red', 'hex': '#FF0000'},
    {'name': 'Light Blue', 'hex': '#33B5E5'},
    {'name': 'Amber', 'hex': '#FFBB33'},
  ];

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
      title: Text('Subtitle Color', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
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
              child: Text(
                'Hello World',
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
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _predefinedColors.map((colorMap) {
                final hex = colorMap['hex']!;
                final color = _parseHexColor(hex);
                final isSelected = _selectedHex == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedHex = hex;
                      _customController.text = hex;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? widget.accentColor : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Custom Hex Color',
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                hintText: '#FFFFFF',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                if (val.startsWith('#') && (val.length == 7 || val.length == 9)) {
                  setState(() {
                    _selectedHex = val.toUpperCase();
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
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedHex),
          child: Text('Save', style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}




