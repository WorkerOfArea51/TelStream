import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';
import '../../core/utils/path_helper.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _appDocsDir = 'Retrieving...';
  String _cachedSizeStr = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadDiagnosticsInfo();
  }

  Future<void> _loadDiagnosticsInfo() async {
    try {
      final docDir = await getAppDirectory();
      int cacheBytes = 0;
      if (await docDir.exists()) {
        await for (final entity in docDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            cacheBytes += await entity.length();
          }
        }
      }
      if (mounted) {
        setState(() {
          _appDocsDir = docDir.path;
          _cachedSizeStr = '${(cacheBytes / 1024 / 1024).toStringAsFixed(2)} MB';
        });
      }
    } catch (_) {
      // Ignored
    }
  }

  Future<void> _updateDecoderMode(String mode) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setHardwareDecoderMode(mode);
    // Invalidate providers to apply changes
    ref.invalidate(videoSettingsProvider);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hardware decoder updated to: $mode'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);
    final settings = ref.watch(videoSettingsProvider);
    
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
      final subTextColor = theme.textTheme.bodySmall?.color ?? Colors.black54;
      final divColor = theme.dividerColor;
      final isAndroid = Platform.isAndroid;
    final decoderMode = storage.getHardwareDecoderMode();
    final isNativeBlending = settings.subtitleRendererMode == 'native';
    
    // Check for the critical zero-copy subtitle rendering conflict
    final hasConflict = isAndroid && isNativeBlending && decoderMode == 'mediacodec';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Troubleshooting & Diagnostics',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Conflict / Warning Card
          if (hasConflict)
            Card(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Subtitle Render Conflict Detected!',
                          style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your device is configured to use zero-copy hardware acceleration (mediacodec) with Native Blending subtitles. On many Android devices, zero-copy bypasses the subtitle filter rendering path entirely, causing subtitles inside MKV/MP4 files not to show up at all.',
                      style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _updateDecoderMode('mediacodec-copy'),
                            child: Text('Switch to Copy-Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: divColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _updateDecoderMode('no'),
                            child: Text('Use Software Decoding', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              color: Colors.green.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Configuration is compatible. Subtitles should render normally.',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          const SizedBox(height: 20),
          _buildSectionHeader(theme, 'Active Settings'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  title: Text('Subtitle Renderer Mode', style: TextStyle(color: textColor)),
                  subtitle: Text(
                    settings.subtitleRendererMode == 'flutter' 
                        ? 'Compatible Flutter Text Overlay' 
                        : 'Stylized Native Blending',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  trailing: Icon(Icons.subtitles, color: subTextColor.withOpacity(0.5)),
                ),
                Divider(color: divColor, height: 1),
                ListTile(
                  title: Text('Hardware Decoding Mode', style: TextStyle(color: textColor)),
                  subtitle: Text(
                    decoderMode == 'mediacodec'
                        ? 'Zero-Copy Hardware (mediacodec)'
                        : decoderMode == 'mediacodec-copy'
                            ? 'Copy-Back Hardware (mediacodec-copy) [Recommended for Subs]'
                            : decoderMode == 'no'
                                ? 'Software Decoding (no)'
                                : 'Auto ($decoderMode)',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  trailing: Icon(Icons.settings_input_component, color: subTextColor.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          _buildSectionHeader(theme, 'Troubleshooting Settings'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    decoderMode == 'mediacodec' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: decoderMode == 'mediacodec' ? Colors.orange : subTextColor.withOpacity(0.5),
                  ),
                  title: Text('Zero-Copy (mediacodec)', style: TextStyle(color: textColor)),
                  subtitle: Text('Highest performance, but may hide subtitles on Android.', style: TextStyle(color: subTextColor, fontSize: 11)),
                  onTap: () => _updateDecoderMode('mediacodec'),
                ),
                Divider(color: divColor, height: 1),
                ListTile(
                  leading: Icon(
                    decoderMode == 'mediacodec-copy' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: decoderMode == 'mediacodec-copy' ? Colors.orange : subTextColor.withOpacity(0.5),
                  ),
                  title: Text('Copy-Back (mediacodec-copy)', style: TextStyle(color: textColor)),
                  subtitle: Text('Hardware accelerated video with full native subtitle blending.', style: TextStyle(color: subTextColor, fontSize: 11)),
                  onTap: () => _updateDecoderMode('mediacodec-copy'),
                ),
                Divider(color: divColor, height: 1),
                ListTile(
                  leading: Icon(
                    decoderMode == 'no' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: decoderMode == 'no' ? Colors.orange : subTextColor.withOpacity(0.5),
                  ),
                  title: Text('Software Decoding (no)', style: TextStyle(color: textColor)),
                  subtitle: Text('Maximum subtitle compatibility. Decodes via CPU.', style: TextStyle(color: subTextColor, fontSize: 11)),
                  onTap: () => _updateDecoderMode('no'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          _buildSectionHeader(theme, 'Device Info & Database Stats'),
          Card(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildStatRow('Operating System', Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.operatingSystem),
                  Divider(color: divColor),
                  _buildStatRow('Database Directory', _appDocsDir),
                  Divider(color: divColor),
                  _buildStatRow('Total Local Storage Size', _cachedSizeStr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.black54;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: TextStyle(color: subTextColor, fontSize: 13), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

