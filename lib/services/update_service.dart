import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/secrets.dart';

class AppUpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String releaseNotes;
  final String releaseUrl;

  AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
  });
}

class UpdateService {
  static const String _githubRepo = 'WorkerOfArea51/TelStream';
  static const String _apiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';

  static int getCurrentBuildNumber() {
    final tag = Secrets.buildTag;
    if (tag == 'Local Dev') return 0; // Default to 0 for local development testing
    final match = RegExp(r'#(\d+)').firstMatch(tag);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  static int? parseBuildNumber(String tag) {
    // Matches build.5, #5, or +5
    final match = RegExp(r'(?:build\.|#|\+)(\d+)').firstMatch(tag);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('User-Agent', 'TelStream-App');
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        
        final latestTagName = json['tag_name'] as String? ?? '';
        final htmlUrl = json['html_url'] as String? ?? 'https://github.com/$_githubRepo/releases';
        final releaseNotes = json['body'] as String? ?? '';
        final latestName = json['name'] as String? ?? latestTagName;

        final assets = json['assets'] as List<dynamic>? ?? [];
        String apkDownloadUrl = htmlUrl;

        // Auto-select the correct APK based on device architecture
        final isArm64 = Platform.version.toLowerCase().contains('arm64') ||
            Platform.version.toLowerCase().contains('aarch64');
        final targetAssetName = isArm64 ? 'telstream-arm64.apk' : 'telstream-arm32.apk';

        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final assetName = asset['name'] as String? ?? '';
            if (assetName == targetAssetName) {
              apkDownloadUrl = asset['browser_download_url'] as String? ?? apkDownloadUrl;
              break;
            }
          }
        }

        // Fallback to any APK if architecture specific asset wasn't found
        if (apkDownloadUrl == htmlUrl) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final assetName = asset['name'] as String? ?? '';
              if (assetName.endsWith('.apk')) {
                apkDownloadUrl = asset['browser_download_url'] as String? ?? apkDownloadUrl;
                break;
              }
            }
          }
        }

        final currentBuild = getCurrentBuildNumber();
        final latestBuild = parseBuildNumber(latestTagName);

        if (latestBuild != null && latestBuild > currentBuild) {
          return AppUpdateInfo(
            isUpdateAvailable: true,
            latestVersion: latestName,
            releaseNotes: releaseNotes,
            releaseUrl: apkDownloadUrl,
          );
        }
        
        return AppUpdateInfo(
          isUpdateAvailable: false,
          latestVersion: latestName,
          releaseNotes: releaseNotes,
          releaseUrl: apkDownloadUrl,
        );
      }
    } catch (e) {
      // Fail silently
    } finally {
      client.close();
    }
    return null;
  }

  static void showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F0F11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Version Ready',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Update recommended',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  updateInfo.latestVersion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (updateInfo.releaseNotes.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: Text(
                        updateInfo.releaseNotes,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: const Text('Later'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse(updateInfo.releaseUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Update Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
