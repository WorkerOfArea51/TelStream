import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/permission_service.dart';
import '../../core/constants.dart';
import '../../services/update_service.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/whats_new_dialog.dart';
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
      ref.read(permissionServiceProvider).requestAllImportantPermissions();
      _showWhatsNewIfNeeded();
    });
  }

  void _showWhatsNewIfNeeded() async {
    final storage = ref.read(storageServiceProvider);
    final lastSeen = storage.getLastSeenVersion();
    if (lastSeen != Constants.currentVersion) {
      if (mounted) {
        WhatsNewDialog.show(context);
        await storage.setLastSeenVersion(Constants.currentVersion);
      }
    }
  }

  void _checkUpdatesSilently() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && updateInfo.isUpdateAvailable && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true, // Allows translucent navigation bar to blend in
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: BottomNavigationBar(
            backgroundColor: theme.cardColor.withOpacity(0.92),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.4),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.tv),
                activeIcon: Icon(Icons.tv, color: theme.primaryColor),
                label: 'Anime',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.movie_outlined),
                activeIcon: Icon(Icons.movie, color: theme.primaryColor),
                label: 'Movies',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.video_collection_outlined),
                activeIcon: Icon(Icons.video_collection, color: theme.primaryColor),
                label: 'Web Series',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz, color: theme.primaryColor),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
