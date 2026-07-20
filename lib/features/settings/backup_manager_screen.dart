import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import '../../services/storage_service.dart';
import '../settings/settings_provider.dart';
import '../../services/sync_service.dart';
import '../../core/utils/path_helper.dart';

import '../../l10n/app_localizations.dart';

class BackupManagerScreen extends ConsumerStatefulWidget {
  const BackupManagerScreen({super.key});

  @override
  ConsumerState<BackupManagerScreen> createState() => _BackupManagerScreenState();
}

class _BackupManagerScreenState extends ConsumerState<BackupManagerScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isSyncing = false;
  String? _statusMessage;
  Color _statusColor = Colors.green;

  Future<String?> _promptPassword(String title) async {
    String? password;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0F11),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: TextField(
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter password',
              hintStyle: TextStyle(color: Colors.white54),
            ),
            onChanged: (val) => password = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, password),
              child: const Text('OK', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }
    );
  }

  Future<void> _triggerManualSync() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      await ref.read(progressSyncServiceProvider.notifier).manualSync();
      setState(() {
        _statusMessage = 'Cloud progress sync completed successfully!';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Cloud progress sync failed: $e';
        _statusColor = Colors.redAccent;
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final password = await _promptPassword('Set Backup Password');
      if (password == null || password.isEmpty) {
        setState(() => _isExporting = false);
        return;
      }

      final storage = ref.read(storageServiceProvider);
      storage.getVideoSettings(); 
      
      final backupJson = storage.exportBackupData();
      
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        final appDir = await getAppDirectory();
        selectedDirectory = appDir.path;
      }

      final timestamp = DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').split('.').first;
      final fileName = 'telstream_backup_$timestamp.enc';
      final file = File('$selectedDirectory/$fileName');
      
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(backupJson, iv: iv);
      final backupData = '${iv.base64}:${encrypted.base64}';

      await file.writeAsString(backupData);
      
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
        allowedExtensions: ['enc', 'json'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final contents = await file.readAsString();
      
      String decryptedJson;
      if (contents.contains(':')) {
        final password = await _promptPassword('Enter Backup Password');
        if (password == null || password.isEmpty) {
          setState(() => _isImporting = false);
          return;
        }
        final keyBytes = sha256.convert(utf8.encode(password)).bytes;
        final key = enc.Key(Uint8List.fromList(keyBytes));
        final parts = contents.split(':');
        final iv = enc.IV.fromBase64(parts[0]);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        try {
          decryptedJson = encrypter.decrypt64(parts[1], iv: iv);
        } catch (e) {
          throw Exception('Incorrect password or corrupted backup.');
        }
      } else {
        decryptedJson = contents; // Fallback for old plaintext backups
      }

      final Map<String, dynamic> parsed = json.decode(decryptedJson);
      if (!parsed.containsKey('history') && !parsed.containsKey('video_settings')) {
        throw Exception('Invalid backup file structure.');
      }

      final storage = ref.read(storageServiceProvider);
      await storage.importBackupData(parsed);

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
    final settings = ref.watch(videoSettingsProvider);
    final notifier = ref.read(videoSettingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    String syncModeText = 'Disabled';
    if (settings.progressSyncMode == 'pinned') {
      syncModeText = 'Pinned Message (Clean)';
    } else if (settings.progressSyncMode == 'sequential') {
      syncModeText = 'Sequential Logs';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          l10n.backupManagerTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
                        title: Text(l10n.exportBackup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(l10n.exportBackupSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: _isExporting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                            : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                        onTap: _isExporting || _isImporting || _isSyncing ? null : _exportBackup,
                      ),
                      const Divider(color: Colors.white10),
                      ListTile(
                        leading: const Icon(Icons.upload_rounded, color: Colors.greenAccent, size: 30),
                        title: Text(l10n.restoreBackup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(l10n.restoreBackupSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: _isImporting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                            : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                        onTap: _isExporting || _isImporting || _isSyncing ? null : _importBackup,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cloud Synchronization',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
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
                        leading: const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 30),
                        title: Text(l10n.cloudProgressSync, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(syncModeText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: DropdownButton<String>(
                          value: settings.progressSyncMode,
                          dropdownColor: theme.cardColor,
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          items: [
                            DropdownMenuItem(value: 'disabled', child: Text(l10n.disabled)),
                            DropdownMenuItem(value: 'pinned', child: Text(l10n.pinnedMessage)),
                            DropdownMenuItem(value: 'sequential', child: Text(l10n.sequentialLogs)),
                          ],
                          onChanged: _isExporting || _isImporting || _isSyncing
                              ? null
                              : (String? val) {
                                  if (val != null) {
                                    notifier.updateSettings(settings.copyWith(progressSyncMode: val));
                                    if (val != 'disabled') {
                                      _triggerManualSync();
                                    }
                                  }
                                },
                        ),
                      ),
                      if (settings.progressSyncMode != 'disabled') ...[
                        const Divider(color: Colors.white10),
                        ListTile(
                          leading: const Icon(Icons.sync, color: Colors.orangeAccent, size: 30),
                          title: Text(l10n.syncProgressNow, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(l10n.syncProgressNowSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: _isSyncing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
                              : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                          onTap: _isExporting || _isImporting || _isSyncing ? null : _triggerManualSync,
                        ),
                      ],
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
      ),
    );
  }
}
