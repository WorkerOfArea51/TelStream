import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants.dart';
import '../../services/update_service.dart';
import 'library_view.dart';
import 'more_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    LibraryView(category: Constants.categories[0]), // Anime
    LibraryView(category: Constants.categories[1]), // Movies
    LibraryView(category: Constants.categories[2]), // Web Series
    const MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesSilently();
      _requestStoragePermissionSilently();
    });
  }

  Future<void> _requestStoragePermissionSilently() async {
    if (Platform.isAndroid) {
      final sdkVersion = _getAndroidSdkVersion();
      if (sdkVersion > 0 && sdkVersion < 33) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }
    }
  }

  int _getAndroidSdkVersion() {
    if (!Platform.isAndroid) return 0;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final sdkIndex = versionStr.indexOf('SDK ');
      if (sdkIndex != -1) {
        final sdkStr = versionStr.substring(sdkIndex + 4);
        final closingParen = sdkStr.indexOf(')');
        final numStr = closingParen != -1 ? sdkStr.substring(0, closingParen) : sdkStr;
        return int.tryParse(numStr.trim()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  void _checkUpdatesSilently() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && updateInfo.isUpdateAvailable && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true, // Allows translucent navigation bar to blend in
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: BottomNavigationBar(
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.white38,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.tv),
                activeIcon: Icon(Icons.tv, color: Colors.orange),
                label: 'Anime',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.movie_outlined),
                activeIcon: Icon(Icons.movie, color: Colors.orange),
                label: 'Movies',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.video_collection_outlined),
                activeIcon: Icon(Icons.video_collection, color: Colors.orange),
                label: 'Web Series',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz, color: Colors.orange),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
