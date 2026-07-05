import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/subtitle_color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class SubtitleDelayDialog extends StatefulWidget {
  final double current;
  final Color accentColor;

  const SubtitleDelayDialog({required this.current, required this.accentColor});

  @override
  State<SubtitleDelayDialog> createState() => SubtitleDelayDialogState();
}

class SubtitleDelayDialogState extends State<SubtitleDelayDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text('Subtitle Delay Offset', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _value == 0.0
                ? 'No Delay'
                : _value > 0.0
                    ? '+${_value.toStringAsFixed(1)} seconds'
                    : '${_value.toStringAsFixed(1)} seconds',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18),
          ),
          Slider(
            value: _value,
            min: -10.0,
            max: 10.0,
            divisions: 200,
            activeColor: widget.accentColor,
            onChanged: (val) {
              setState(() {
                _value = double.parse(val.toStringAsFixed(1));
              });
            },
          ),
          Text(
            'Positive: Subtitles appear later\nNegative: Subtitles appear earlier',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: Text('Save', style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}

