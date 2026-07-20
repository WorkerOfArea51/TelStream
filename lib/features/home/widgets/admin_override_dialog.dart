import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

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
      title: Text(AppLocalizations.of(context)!.adminOverrideTitle, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.adminOverrideLinking(widget.title),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SelectableText(
            AppLocalizations.of(context)!.firebaseFolder(base64Url.encode(utf8.encode(widget.title)).replaceAll("=", "")),
            style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.pasteUrlsHint,
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
          child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(AppLocalizations.of(context)!.saveLink, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
