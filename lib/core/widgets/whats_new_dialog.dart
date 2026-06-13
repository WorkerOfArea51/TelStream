import 'package:flutter/material.dart';
import '../../core/constants.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WhatsNewDialog(),
    );
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
                color: theme.primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                color: theme.primaryColor,
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
            Text(
              "v${Constants.currentVersion}",
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      theme,
                      icon: Icons.download_rounded,
                      title: "Native Background Downloads",
                      bullets: [
                        "Active Background Services: Downloads now run in background when the app is minimized.",
                        "Notification Center: Real-time progress bar and state indicators in the Android status bar.",
                        "Recents Dismiss: Swiping away the app stops downloads and wipes temp files to save cache storage.",
                        "Player Exit Fix: Playing a video while downloading no longer cancels background progress on exit.",
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      theme,
                      icon: Icons.palette_rounded,
                      title: "Custom Gradient Themes",
                      bullets: [
                        "Vibrant Gradients: 4 premium themes (Sunset Cyberpunk, Aurora Abyss, Solaris Flare, Classic Navy) selectable from settings.",
                        "Solid Surfaces: Clean, premium solid card textures replacing previous transparent backgrounds.",
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      theme,
                      icon: Icons.settings_suggest_rounded,
                      title: "Other Optimizations",
                      bullets: [
                        "Disk storage cleanup and automatic background database checkups on startup.",
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
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

  Widget _buildSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...bullets.map((bullet) {
          final parts = bullet.split(': ');
          if (parts.length > 1) {
            return Padding(
              padding: const EdgeInsets.only(left: 28.0, bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(color: Colors.white38)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                        children: [
                          TextSpan(
                            text: "${parts[0]}: ",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          TextSpan(text: parts[1]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(left: 28.0, bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(color: Colors.white38)),
                Expanded(
                  child: Text(
                    bullet,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
