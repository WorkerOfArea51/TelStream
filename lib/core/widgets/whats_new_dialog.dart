import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/update_service.dart';
import 'changelog_parser.dart';

class WhatsNewDialog extends StatelessWidget {
  final String content;

  const WhatsNewDialog({Key? key, required this.content}) : super(key: key);

  static void show(BuildContext context, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WhatsNewDialog(content: content),
    );
  }

  static void showDynamic(BuildContext context) async {
    // Show a loading indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );

    // Fetch the latest release info from GitHub
    final updateInfo = await UpdateService.checkForUpdate();
    
    if (context.mounted) {
      Navigator.pop(context); // Dismiss loading indicator
    }

    if (updateInfo != null && context.mounted) {
      show(context, updateInfo.releaseNotes);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load changelog from GitHub.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            const Text(
              "What's New in TelStream",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              "v${Constants.currentVersion}",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: ChangelogParser(content: content),
              ),
            ),
            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Let's Go!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
