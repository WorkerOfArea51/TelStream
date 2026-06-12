import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/tdlib_service.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../player/pip_manager.dart';
import 'video_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSize = "Calculating...";

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
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
      const SnackBar(content: Text('Clearing video cache...'), duration: Duration(milliseconds: 800)),
    );
    
    await ref.read(tdlibServiceProvider).clearVideoCache();
    await _calculateCacheSize();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video cache cleared successfully!'), backgroundColor: Colors.green),
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
            title: const Text('Clear Video Cache', style: TextStyle(color: Colors.white)),
            subtitle: const Text('TelStream automatically caches downloaded videos for instant playback. Clear this if you are low on storage.', style: TextStyle(color: Colors.white54)),
            onTap: _clearCache,
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
        ],
      ),
    );
  }
}
