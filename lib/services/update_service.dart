import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import '../core/logger.dart';
import '../core/secrets.dart';
import '../core/widgets/wavy_progress_indicators.dart';
import '../core/widgets/changelog_parser.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

class AppUpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String releaseNotes;
  final String releaseUrl;
  final String expectedSha256;
  final String signatureUrl;

  AppUpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
    this.expectedSha256 = '',
    this.signatureUrl = '',
  });
}

class UpdateCheckResult {
  final AppUpdateInfo? info;
  final String? errorMessage;
  final String? sourceMirror;
  bool get isSuccess => info != null && errorMessage == null;

  UpdateCheckResult({this.info, this.errorMessage, this.sourceMirror});
}

class _HttpFetchResult {
  final int statusCode;
  final String? body;
  final dynamic json;
  final String? error;
  _HttpFetchResult({required this.statusCode, this.body, this.json, this.error});
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

  static Future<_HttpFetchResult> _httpGetJsonWithTimeout(
    String url, {
    Duration timeout = const Duration(seconds: 10),
    int retries = 2,
  }) async {
    Object? lastError;
    for (int attempt = 0; attempt <= retries; attempt++) {
      final client = HttpClient();
      try {
        client.connectionTimeout = timeout;
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set('User-Agent', 'TelStream-App');
        req.headers.set('Accept', 'application/vnd.github+json');
        final resp = await req.close().timeout(timeout + const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join().timeout(timeout);
          return _HttpFetchResult(statusCode: 200, body: body, json: jsonDecode(body));
        } else if (resp.statusCode == 403 || resp.statusCode == 429) {
          return _HttpFetchResult(statusCode: resp.statusCode, error: 'Rate-limited');
        }
        lastError = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastError = e.toString();
      } finally {
        client.close(force: true);
      }
    }
    return _HttpFetchResult(statusCode: -1, error: lastError?.toString() ?? 'unknown');
  }

  static Future<UpdateCheckResult> checkForUpdateDetailed({bool manual = false}) async {
    final mirrors = [
      _apiUrl,
      'https://cdn.jsdelivr.net/gh/$_githubRepo@main/latest_release.json',
      'https://ghproxy.com/$_apiUrl',
      'https://gh.api.99988866.xyz/$_apiUrl',
      'https://github.moeyy.xyz/$_apiUrl',
      'https://gh-proxy.com/$_apiUrl',
    ];

    String? lastErrorMsg;

    for (final mirrorUrl in mirrors) {
      try {
        final fetchResult = await _httpGetJsonWithTimeout(mirrorUrl, timeout: const Duration(seconds: 10));
        if (fetchResult.statusCode == 200 && fetchResult.json != null) {
          final json = fetchResult.json as Map<String, dynamic>;
          final currentBuild = getCurrentBuildNumber();
          
          if (mirrorUrl.contains('latest_release.json')) {
            final latestTagName = json['tag_name'] as String? ?? '';
            final latestBuild = parseBuildNumber(latestTagName);
            final latestVersion = json['name'] as String? ?? 'Update';
            if (latestBuild != null && latestBuild > currentBuild) {
              return UpdateCheckResult(
                sourceMirror: mirrorUrl,
                info: AppUpdateInfo(
                  isUpdateAvailable: true,
                  latestVersion: latestVersion,
                  releaseNotes: json['body'] as String? ?? "A new update is available.",
                  releaseUrl: 'https://github.com/$_githubRepo/releases/latest',
                ),
              );
            }
            return UpdateCheckResult(
              sourceMirror: mirrorUrl,
              info: AppUpdateInfo(isUpdateAvailable: false, latestVersion: latestVersion, releaseNotes: '', releaseUrl: ''),
            );
          }

          final latestTagName = json['tag_name'] as String? ?? '';
          final htmlUrl = json['html_url'] as String? ?? 'https://github.com/$_githubRepo/releases';
          final releaseNotes = json['body'] as String? ?? '';
          final latestName = json['name'] as String? ?? latestTagName;
          final assets = json['assets'] as List<dynamic>? ?? [];
          String downloadUrl = htmlUrl;
          String signatureUrl = '';

          if (Platform.isWindows) {
            for (final asset in assets) {
              if (asset is Map<String, dynamic>) {
                final assetName = asset['name'] as String? ?? '';
                if (assetName == 'telstream-setup.exe') {
                  downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
                } else if (assetName == 'telstream-setup.exe.sig') {
                  signatureUrl = asset['browser_download_url'] as String? ?? signatureUrl;
                }
              }
            }
          } else {
            // Android: detect ARM architecture
            bool isArm64;
            try {
              final deviceInfo = DeviceInfoPlugin();
              final androidInfo = await deviceInfo.androidInfo;
              isArm64 = androidInfo.supportedAbis.any((abi) => abi.toLowerCase().contains('arm64'));
            } catch (e) {
              Log.w('Could not detect ARM architecture, defaulting to arm64: $e');
              isArm64 = true;
            }
            final targetAssetName = isArm64 ? 'telstream-arm64.apk' : 'telstream-arm32.apk';
            for (final asset in assets) {
              if (asset is Map<String, dynamic>) {
                final assetName = asset['name'] as String? ?? '';
                if (assetName == targetAssetName) {
                  downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
                  break;
                }
              }
            }
            if (downloadUrl == htmlUrl) {
              for (final asset in assets) {
                if (asset is Map<String, dynamic>) {
                  if ((asset['name'] as String? ?? '').endsWith('.apk')) {
                    downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
                    break;
                  }
                }
              }
            }
          }

          final latestBuild = parseBuildNumber(latestTagName);
          String parsedSha256 = _extractSha256FromReleaseNotes(releaseNotes, downloadUrl.split('/').last);
          
          if (latestBuild != null && latestBuild > currentBuild) {
            return UpdateCheckResult(
              sourceMirror: mirrorUrl,
              info: AppUpdateInfo(
                isUpdateAvailable: true,
                latestVersion: latestName,
                releaseNotes: releaseNotes,
                releaseUrl: downloadUrl,
                expectedSha256: parsedSha256,
                signatureUrl: signatureUrl,
              ),
            );
          }
          return UpdateCheckResult(
            sourceMirror: mirrorUrl,
            info: AppUpdateInfo(
              isUpdateAvailable: false,
              latestVersion: latestName,
              releaseNotes: releaseNotes,
              releaseUrl: downloadUrl,
              expectedSha256: parsedSha256,
              signatureUrl: signatureUrl,
            ),
          );
        } else if (fetchResult.error != null) {
          lastErrorMsg = fetchResult.error;
        }
      } catch (e, stack) {
        Log.e("Update check failed for mirror: $mirrorUrl", e, stack);
        lastErrorMsg = e.toString();
      }
    }
    return UpdateCheckResult(errorMessage: lastErrorMsg ?? "Unknown error");
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    final res = await checkForUpdateDetailed();
    return res.info;
  }

  static Future<void> checkAndShowDialogIfAvailable(
    BuildContext context, {
    bool manual = false,
    bool showErrorSnack = false,
  }) async {
    final result = await checkForUpdateDetailed(manual: manual);
    if (!context.mounted) return;
    
    if (result.errorMessage != null) {
      Log.e('Update check failed: ${result.errorMessage}');
      if (showErrorSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not reach the update server. Error: ${result.errorMessage}. Try a VPN."),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => checkAndShowDialogIfAvailable(context, manual: manual, showErrorSnack: true),
            ),
          ),
        );
      }
      return;
    }
    final info = result.info;
    if (info != null && info.isUpdateAvailable) {
      showUpdateDialog(context, info);
    } else if (manual && info != null && !info.isUpdateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version.')),
      );
    }
  }

  static String _extractSha256FromReleaseNotes(String notes, String fileName) {
    if (notes.isEmpty || fileName.isEmpty) return '';
    final escaped = RegExp.escape(fileName);

    // 1. File-specific hash with arbitrary `-`, `*`, `**` bullet prefix.
    final specificRegex = RegExp(
      r'^[\s\-\*]*'              // optional whitespace, dashes, asterisks (any count)
      r'\**\s*'                  // optional bold markers
      r'(?:`?)' + escaped + r'(?:`?)'
      r'\s*[:：]\**\s*'
      r'`?([a-fA-F0-9]{64})`?'
      r'\s*$',
      multiLine: true,
      caseSensitive: false,
    );
    final m1 = specificRegex.firstMatch(notes);
    if (m1 != null) return m1.group(1)!.toLowerCase();

    // 2. GNU coreutils sha256sum format: "<hash>  <filename>"
    final coreutilsRegex = RegExp(
      r'^([a-fA-F0-9]{64})\s+\*?' + escaped + r'\s*$',
      multiLine: true,
      caseSensitive: false,
    );
    final m2 = coreutilsRegex.firstMatch(notes);
    if (m2 != null) return m2.group(1)!.toLowerCase();

    // 3. Generic SHA-256 prefix.
    final genericRegex = RegExp(
      r'(?:SHA-?256)[:\s]*`?([a-fA-F0-9]{64})`?',
      caseSensitive: false,
    );
    final m3 = genericRegex.firstMatch(notes);
    if (m3 != null) return m3.group(1)!.toLowerCase();

    return '';
  }

  static void showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return UpdateDialogContent(updateInfo: updateInfo);
      },
    );
  }
}

class UpdateDialogContent extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialogContent({super.key, required this.updateInfo});

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

  HttpClient? _client;

  @override
  void dispose() {
    _activeRequest?.abort();
    _client?.close(force: true);
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

    _client = HttpClient();
    File? tempFile;
    try {
      final urls = <String>[widget.updateInfo.releaseUrl];
      for (final p in const [
        'https://ghproxy.com/',
        'https://github.moeyy.xyz/',
        'https://gh-proxy.com/',
      ]) {
        if (!widget.updateInfo.releaseUrl.startsWith(p)) {
          urls.add(p + widget.updateInfo.releaseUrl);
        }
      }

      HttpClientResponse? response;
      for (final url in urls) {
        try {
          final request = await _client!.getUrl(Uri.parse(url));
          _activeRequest = request;
          final r = await request.close();
          if (r.statusCode == 200) {
            response = r;
            break;
          }
        } catch (_) {}
      }

      if (response == null) {
        throw Exception("Server returned HTTP error or all mirrors failed");
      }

      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}/updates');
      if (!await updatesDir.exists()) await updatesDir.create(recursive: true);

      if (Platform.isWindows) {
        tempFile = File('${updatesDir.path}/telstream-setup.exe');
      } else {
        tempFile = File('${updatesDir.path}/telstream_update.apk');
      }
      
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final fileSink = tempFile.openWrite();
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
        _statusText = "Verifying update integrity...";
        _progress = null;
      });

      if (widget.updateInfo.expectedSha256.isNotEmpty) {
        final digest = await sha256.bind(tempFile.openRead()).first;
        if (digest.toString() != widget.updateInfo.expectedSha256) {
          await tempFile.delete();
          throw Exception("Security Exception: Installer integrity check failed. SHA-256 hash mismatch.");
        }
      } else {
        // Recoverable prompt for missing hash instead of failing
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Verify Installation"),
            content: const Text("Could not verify the installer's SHA-256 hash automatically. Do you want to proceed with the installation?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Proceed")),
            ],
          ),
        );
        if (shouldProceed != true) {
          await tempFile.delete();
          throw Exception("Installation cancelled by user due to missing SHA-256 hash.");
        }
      }

      // Add Ed25519 signature verification for Windows
      if (Platform.isWindows) {
        if (widget.updateInfo.signatureUrl.isEmpty) {
          await tempFile.delete();
          throw Exception("Security Exception: Missing signature file (.sig) in release. Cannot verify authenticity.");
        }
        
        setState(() {
          _statusText = "Verifying cryptographic signature...";
        });

        final sigRequest = await _client!.getUrl(Uri.parse(widget.updateInfo.signatureUrl));
        final sigResponse = await sigRequest.close();
        if (sigResponse.statusCode != 200) {
          await tempFile.delete();
          throw Exception("Security Exception: Failed to download signature file.");
        }
        
        final signatureBytes = await sigResponse.expand((b) => b).toList();
        final fileBytes = await tempFile.readAsBytes();
        
        // Parse hex public key
        final pubKeyHex = Secrets.updatePublicKey;
        if (pubKeyHex.length != 64) {
          await tempFile.delete();
          throw Exception("Security Exception: Invalid hardcoded public key length.");
        }
        
        final pubKeyBytes = List<int>.generate(
          pubKeyHex.length ~/ 2,
          (i) => int.parse(pubKeyHex.substring(i * 2, i * 2 + 2), radix: 16),
        );
        
        final publicKey = ed.PublicKey(pubKeyBytes);
        final isValid = ed.verify(publicKey, fileBytes, Uint8List.fromList(signatureBytes));
        
        if (!isValid) {
          await tempFile.delete();
          throw Exception("Security Exception: The installer's cryptographic signature is INVALID or corrupted.");
        }
      }

      setState(() {
        _statusText = "Preparing installation...";
        _progress = 1.0;
      });

      if (Platform.isWindows) {
        // Run the downloaded installer executable in detached mode and terminate the current app
        await Process.start(tempFile.path, [], mode: ProcessStartMode.detached);
        exit(0);
      } else {
        // Invoke Method Channel for Android APK installation
        const channel = MethodChannel('com.darkmatter.telstream/updater');
        await channel.invokeMethod('installApk', {'filePath': tempFile.path});
        if (mounted) {
          Navigator.pop(context);
        }
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
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    } finally {
      _client?.close(force: true);
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
    const primaryColor = Colors.orange;

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
                      color: primaryColor.withValues(alpha: 0.15),
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
                      color: Colors.redAccent.withValues(alpha: 0.05),
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
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
