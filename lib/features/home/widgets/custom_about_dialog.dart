import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../core/secrets.dart';
import '../../../core/widgets/whats_new_dialog.dart';

class CustomAboutDialog {
  static void show(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600), // Ensures it looks good on wide desktop screens
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _AboutContent(scrollController: scrollController),
            );
          },
        );
      },
    );
  }
}

class _AboutContent extends StatelessWidget {
  final ScrollController? scrollController;
  final bool isDesktop;

  const _AboutContent({this.scrollController}) : isDesktop = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (!isDesktop)
          // Grab Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        if (isDesktop)
          // Desktop Close Button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),

        // Glowing Logo Center
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.play_circle_fill, size: 55, color: theme.primaryColor);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TelStream',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v${Constants.currentVersion} • Fairy Tail (${Secrets.buildTag})',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Description
        Text(
          'TelStream is a premium, open-source streaming client designed for watching Anime, Movies, and Web Series. Built on modern tech stacks, it features seamless media cache control and high-performance video streaming capabilities.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.75),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
            foregroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3), width: 1),
            ),
          ),
          onPressed: () {
            Navigator.pop(context); // Close about dialog
            WhatsNewDialog.show(context);
          },
          icon: const Icon(Icons.history_edu_rounded, size: 18),
          label: const Text('View Changelog'),
        ),
        const SizedBox(height: 28),

        // Section: Developer & Project
        Text(
          'PROJECT INFO & DEVELOPER',
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: Column(
            children: [
              _buildLinkTile(
                context,
                icon: Icons.code_rounded,
                title: 'GitHub Repository',
                subtitle: 'github.com/WorkerOfArea51/TelStream',
                url: 'https://github.com/WorkerOfArea51/TelStream',
              ),
              Divider(color: theme.dividerColor, height: 1, indent: 56),
              _buildLinkTile(
                context,
                icon: Icons.bug_report_rounded,
                title: 'Report Bug / Request Feature',
                subtitle: 'Submit issues or suggest enhancements',
                onTap: () {
                  _showReportBugOptions(context);
                },
              ),
              Divider(color: theme.dividerColor, height: 1, indent: 56),
              _buildLinkTile(
                context,
                icon: Icons.person_rounded,
                title: 'Developer Profile',
                subtitle: 'GitHub @WorkerOfArea51',
                url: 'https://github.com/WorkerOfArea51',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Tech Stack
        Text(
          'CORE TECHNOLOGIES',
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const _TechRow(
                name: 'Flutter & Dart',
                desc: 'Cross-platform UI engine & programming language.',
              ),
              Divider(color: theme.dividerColor, height: 20),
              const _TechRow(
                name: 'TDLib (Telegram Database)',
                desc: 'High-speed native client for MTProto API integration.',
              ),
              Divider(color: theme.dividerColor, height: 20),
              const _TechRow(
                name: 'MediaKit & libmpv',
                desc: 'Hardware-accelerated video decoding & audio controller.',
              ),
              Divider(color: theme.dividerColor, height: 20),
              const _TechRow(
                name: 'Riverpod',
                desc: 'Reactive state caching & dependency injection framework.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Legal / License
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Open Source License',
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () => _launchURL('https://github.com/WorkerOfArea51/TelStream/blob/main/LICENSE'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('MIT License', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? url,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.primaryColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.dividerColor),
      onTap: onTap ?? () {
        if (url != null) {
          _launchURL(url);
        }
      },
    );
  }

  void _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch URL: $e");
    }
  }

  void _showReportBugOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Report Bug / Request Feature',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.code_rounded, color: Colors.white, size: 20),
                ),
                title: Text('GitHub Issues', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text('Tracked publicly on repository', style: TextStyle(color: subTextColor, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _launchURL('https://github.com/WorkerOfArea51/TelStream/issues');
                },
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
                title: Text('Telegram Support Bot', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text('Directly report to @Fil3Stor3_bot', style: TextStyle(color: subTextColor, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _launchURL('https://t.me/Fil3Stor3_bot');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _TechRow extends StatelessWidget {
  final String name;
  final String desc;

  const _TechRow({required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            name,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            desc,
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
