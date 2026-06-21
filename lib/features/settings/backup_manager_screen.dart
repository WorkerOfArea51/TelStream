import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';

class BackupManagerScreen extends ConsumerStatefulWidget {
  const BackupManagerScreen({super.key});

  @override
  ConsumerState<BackupManagerScreen> createState() => _BackupManagerScreenState();
}

class _BackupManagerScreenState extends ConsumerState<BackupManagerScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _statusMessage;
  Color _statusColor = Colors.green;

  Future<void> _exportBackup() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      // Retrieve the raw data Map
      storage.getVideoSettings(); // Just to trigger/check
      
      // Let's get the entire underlying data map from storage_service.dart
      // Wait, we need to expose a way to get or we can just access it.
      // Let's check how storage data is stored.
      // In StorageService, there is _data. Let's add a raw export method to StorageService.
      final backupJson = storage.exportBackupData();
      
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        // Fallback to Application Documents directory if canceled
        final appDir = await getApplicationDocumentsDirectory();
        selectedDirectory = appDir.path;
      }

      final timestamp = DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').split('.').first;
      final fileName = 'telstream_backup_$timestamp.json';
      final file = File('$selectedDirectory/$fileName');
      
      await file.writeAsString(backupJson);
      
      setState(() {
        _statusMessage = 'Backup saved to:\n${file.path}';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to export backup: $e';
        _statusColor = Colors.redAccent;
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _isImporting = true;
      _statusMessage = null;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();
      
      // Validate contents
      final Map<String, dynamic> parsed = json.decode(contents);
      if (!parsed.containsKey('history') && !parsed.containsKey('video_settings')) {
        throw Exception('Invalid backup file structure.');
      }

      final storage = ref.read(storageServiceProvider);
      await storage.importBackupData(parsed);

      // Invalidate providers to force UI updates
      ref.invalidate(videoSettingsProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(recentNetworkStreamsProvider);
      ref.invalidate(historyLogProvider);
      ref.invalidate(lastWatchedProvider);

      setState(() {
        _statusMessage = 'Backup restored successfully!\nSettings and history have been reloaded.';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to import backup: $e';
        _statusColor = Colors.redAccent;
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.settings_backup_restore,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage Database Backups',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Export your settings, watch progress history, favorite list, and streams log to a file, or restore them from a previous backup.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download_rounded, color: Colors.orange, size: 30),
                      title: const Text('Export Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Save configuration and history to a JSON file', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: _isExporting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                          : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                      onTap: _isExporting || _isImporting ? null : _exportBackup,
                    ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      leading: const Icon(Icons.upload_rounded, color: Colors.greenAccent, size: 30),
                      title: const Text('Restore Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Load settings and history from a JSON file', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: _isImporting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                          : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                      onTap: _isExporting || _isImporting ? null : _importBackup,
                    ),
                  ],
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(color: _statusColor, fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
