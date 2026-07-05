import 'package:flutter/material.dart';

class SnackbarService {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.grey[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
