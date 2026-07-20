import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class SubtitleDelayDialog extends StatefulWidget {
  final double current;
  final Color accentColor;

  const SubtitleDelayDialog({super.key, required this.current, required this.accentColor});

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
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      title: Text(l10n.subtitleDelayOffsetDialogTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _value == 0.0
                ? l10n.noDelay
                : _value > 0.0
                    ? l10n.delayPositive(_value.toStringAsFixed(1))
                    : l10n.delayNegative(_value.toStringAsFixed(1)),
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
            l10n.subtitleDelayDescription,
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
            textAlign: TextAlign.center,
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
