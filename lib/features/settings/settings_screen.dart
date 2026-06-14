import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/permission_service.dart';
import '../../services/tdlib_service.dart';
import '../../services/storage_service.dart';
import '../../services/download_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../player/pip_manager.dart';
import 'video_settings_screen.dart';
import '../../core/widgets/whats_new_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSize = "Calculating...";
  String _downloadPath = "Default (App Private)";

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
    _loadDownloadPath();
  }

  Future<void> _loadDownloadPath() async {
    final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();
    setState(() {
      _downloadPath = customPath ?? "Default (App Private)";
    });
  }

  Future<void> _selectDownloadDirectory() async {
    final permissionGranted = await ref.read(permissionServiceProvider).requestStoragePermission();

    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to choose a custom downloads folder on this version of Android.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        await ref.read(storageServiceProvider).setCustomDownloadDirectory(selectedDirectory);
        setState(() {
          _downloadPath = selectedDirectory;
        });
        await ref.read(downloadControllerProvider.notifier).reloadDownloads();
        await _calculateCacheSize();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download folder updated to: $selectedDirectory'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select directory: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      int totalSize = 0;
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      // Also calculate custom download directory size if set
      final customPath = ref.read(storageServiceProvider).getCustomDownloadDirectory();
      if (customPath != null && customPath.isNotEmpty) {
        final customDir = Directory(customPath);
        if (await customDir.exists()) {
          await for (var entity in customDir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }
      
      if (!mounted) return;
      setState(() {
        if (totalSize < 1024 * 1024) {
          _cacheSize = "${(totalSize / 1024).toStringAsFixed(1)} KB";
        } else if (totalSize < 1024 * 1024 * 1024) {
          _cacheSize = "${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB";
        } else {
          _cacheSize = "${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
        }
      });
    } catch (e) {
      if (mounted) setState(() => _cacheSize = "Unknown");
    }
  }

  void _clearCache() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clearing cache (including images)...'), duration: Duration(milliseconds: 800)),
    );
    
    await ref.read(tdlibServiceProvider).clearVideoCache(includePhotos: true);
    await _calculateCacheSize();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully!'), backgroundColor: Colors.green),
    );
  }

  void _logout() async {
    ref.read(pipControllerProvider.notifier).close();
    ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Storage Management', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.storage, color: Colors.white70),
            title: const Text('App Cache Size', style: TextStyle(color: Colors.white)),
            trailing: Text(_cacheSize, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.cleaning_services, color: Colors.redAccent),
            title: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
            subtitle: const Text('TelStream caches videos and poster images. Clearing this deletes them and frees up storage.', style: TextStyle(color: Colors.white54)),
            onTap: _clearCache,
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.folder, color: Colors.orangeAccent),
            title: const Text('Download Folder', style: TextStyle(color: Colors.white)),
            subtitle: Text(_downloadPath, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: const Icon(Icons.folder_open, color: Colors.white70, size: 20),
            onTap: _selectDownloadDirectory,
          ),

          const SizedBox(height: 32),
          const Text('Playback', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.video_settings, color: Colors.white70),
            title: const Text('Video Player Preferences', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Gestures, audio, subtitles, and player UI', style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoSettingsScreen()));
            },
          ),
          
          const SizedBox(height: 32),
          const Text('Account', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout from TelStream', style: TextStyle(color: Colors.white)),
            onTap: _logout,
          ),

          const SizedBox(height: 32),
          const Text('Info', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.history_edu_rounded, color: Colors.white70),
            title: const Text("What's New / Changelog", style: TextStyle(color: Colors.white)),
            subtitle: const Text("View release notes for this version", style: TextStyle(color: Colors.white54)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => WhatsNewDialog.showDynamic(context),
          ),
        ],
      ),
    );
  }
}
