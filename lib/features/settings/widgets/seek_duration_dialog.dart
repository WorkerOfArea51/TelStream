import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
class SeekDurationDialog extends StatefulWidget {
  final int current;
  final Color accentColor;

  const SeekDurationDialog({super.key, required this.current, required this.accentColor});

  @override
  State<SeekDurationDialog> createState() => SeekDurationDialogState();
}

class SeekDurationDialogState extends State<SeekDurationDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(AppLocalizations.of(context)!.doubleTapSeekDurationDialogTitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.nSeconds(_value), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
          Slider(
            value: _value.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            activeColor: widget.accentColor,
            onChanged: (val) {
              setState(() {
                _value = val.toInt();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _value),
          child: Text(AppLocalizations.of(context)!.save, style: TextStyle(color: widget.accentColor)),
        ),
      ],
    );
  }
}





