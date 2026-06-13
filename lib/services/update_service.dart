import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/secrets.dart';
import '../core/widgets/wavy_progress_indicators.dart';
import '../core/widgets/changelog_parser.dart';

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
  }  static void showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UpdateDialogContent(updateInfo: updateInfo);
      },
    );
  }
}

class UpdateDialogContent extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialogContent({Key? key, required this.updateInfo}) : super(key: key);

  @override
  State<UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<UpdateDialogContent> {
  double? _progress;
  String _statusText = "";
  bool _isDownloading = false;
  bool _hasError = false;
  String? _errorMessage;
  HttpClientRequest? _activeRequest;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  @override
  void dispose() {
    _activeRequest?.abort();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _hasError = false;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _statusText = "Downloading...";
    });

    final client = HttpClient();
    File? apkFile;
    try {
      final url = widget.updateInfo.releaseUrl;
      final request = await client.getUrl(Uri.parse(url));
      _activeRequest = request;
      
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception("Server returned HTTP code ${response.statusCode}");
      }

      final tempDir = await getTemporaryDirectory();
      apkFile = File('${tempDir.path}/telstream_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final fileSink = apkFile.openWrite();
      final totalBytes = response.contentLength;
      int downloadedBytes = 0;

      await for (final chunk in response) {
        fileSink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          setState(() {
            _progress = progress;
            _downloadedBytes = downloadedBytes;
            _totalBytes = totalBytes;
            _statusText = "Downloading: ${(progress * 100).toInt()}%";
          });
        } else {
          setState(() {
            _progress = null; // Indeterminate
            _downloadedBytes = downloadedBytes;
            _totalBytes = 0;
            _statusText = "Downloading... (${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB)";
          });
        }
      }

      await fileSink.flush();
      await fileSink.close();

      setState(() {
        _statusText = "Preparing installation...";
        _progress = 1.0;
      });

      // Invoke Method Channel
      const channel = MethodChannel('com.darkmatter.telstream/updater');
      await channel.invokeMethod('installApk', {'filePath': apkFile.path});
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isDownloading = false;
          _errorMessage = e.toString();
          _statusText = "Failed to download update.";
        });
      }
      if (apkFile != null && await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }
    } finally {
      client.close();
      _activeRequest = null;
    }
  }

  void _cancelDownload() {
    _activeRequest?.abort();
    Navigator.pop(context);
  }

  Future<void> _fallbackBrowserDownload() async {
    final uri = Uri.parse(widget.updateInfo.releaseUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching browser update URL: $e");
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return PopScope(
      canPop: !_isDownloading,
      child: Dialog(
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDownloading ? Icons.downloading_rounded : Icons.system_update_alt_rounded,
                      color: primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDownloading ? 'Updating TelStream' : 'New Version Ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isDownloading ? 'Please wait while update downloads' : 'Update recommended',
                          style: const TextStyle(
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

              // Content depending on state
              if (_isDownloading) ...[
                const SizedBox(height: 10),
                WavyLinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progress != null ? "${(_progress! * 100).toInt()}%" : _statusText,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        "${(_downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB of ${(_totalBytes / 1024 / 1024).toStringAsFixed(2)} MB",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      )
                    else if (_downloadedBytes > 0)
                      Text(
                        "${(_downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelDownload,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ] else if (_hasError) ...[
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (_errorMessage != null)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 80),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _fallbackBrowserDownload,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
                      child: const Text('Open in Browser'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  widget.updateInfo.latestVersion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: ChangelogParser(content: widget.updateInfo.releaseNotes),
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
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
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
            ],
          ),
        ),
      ),
    );
  }
}
