import 'package:flutter/material.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Double tap seek duration', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_value seconds', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18)),
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




