import 'package:flutter/material.dart';

class SnackbarService {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    
    messenger.clearSnackBars();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: isError ? colorScheme.onError : colorScheme.onSurface)),
        backgroundColor: isError ? colorScheme.error : colorScheme.surfaceVariant,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
