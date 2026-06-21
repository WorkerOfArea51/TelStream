import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';

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
      final docDir = await getApplicationDocumentsDirectory();
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
    
    final isAndroid = Platform.isAndroid;
    final decoderMode = storage.getHardwareDecoderMode();
    final isNativeBlending = settings.subtitleRendererMode == 'native';
    
    // Check for the critical zero-copy subtitle rendering conflict
    final hasConflict = isAndroid && isNativeBlending && decoderMode == 'mediacodec';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Troubleshooting & Diagnostics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Subtitle Render Conflict Detected!',
                          style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your device is configured to use zero-copy hardware acceleration (mediacodec) with Native Blending subtitles. On many Android devices, zero-copy bypasses the subtitle filter rendering path entirely, causing subtitles inside MKV/MP4 files not to show up at all.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                            child: const Text('Switch to Copy-Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _updateDecoderMode('no'),
                            child: const Text('Use Software Decoding', style: TextStyle(fontSize: 12)),
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
                side: const BorderSide(color: Colors.green, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Configuration is compatible. Subtitles should render normally.',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                  title: const Text('Subtitle Renderer Mode', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    settings.subtitleRendererMode == 'flutter' 
                        ? 'Compatible Flutter Text Overlay' 
                        : 'Stylized Native Blending',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.subtitles, color: Colors.white30),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  title: const Text('Hardware Decoding Mode', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    decoderMode == 'mediacodec'
                        ? 'Zero-Copy Hardware (mediacodec)'
                        : decoderMode == 'mediacodec-copy'
                            ? 'Copy-Back Hardware (mediacodec-copy) [Recommended for Subs]'
                            : decoderMode == 'no'
                                ? 'Software Decoding (no)'
                                : 'Auto ($decoderMode)',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.settings_input_component, color: Colors.white30),
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
                    color: decoderMode == 'mediacodec' ? Colors.orange : Colors.white30,
                  ),
                  title: const Text('Zero-Copy (mediacodec)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Highest performance, but may hide subtitles on Android.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  onTap: () => _updateDecoderMode('mediacodec'),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: Icon(
                    decoderMode == 'mediacodec-copy' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: decoderMode == 'mediacodec-copy' ? Colors.orange : Colors.white30,
                  ),
                  title: const Text('Copy-Back (mediacodec-copy)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Hardware accelerated video with full native subtitle blending.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  onTap: () => _updateDecoderMode('mediacodec-copy'),
                ),
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: Icon(
                    decoderMode == 'no' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: decoderMode == 'no' ? Colors.orange : Colors.white30,
                  ),
                  title: const Text('Software Decoding (no)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Maximum subtitle compatibility. Decodes via CPU.', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                  const Divider(color: Colors.white10),
                  _buildStatRow('Database Directory', _appDocsDir),
                  const Divider(color: Colors.white10),
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
        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
