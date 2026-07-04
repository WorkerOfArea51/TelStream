import 'package:flutter/material.dart';

class AdminOverrideDialog extends StatefulWidget {
  final String title;
  final String? initialText;
  const AdminOverrideDialog({super.key, required this.title, this.initialText});

  @override
  State<AdminOverrideDialog> createState() => _AdminOverrideDialogState();
}

class _AdminOverrideDialogState extends State<AdminOverrideDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text('Admin Override', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linking: ${widget.title}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Paste IMDB/MAL URLs (comma separated or multiple lines)',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save Link', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
