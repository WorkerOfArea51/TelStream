import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _downloadsChannel = MethodChannel('com.darkmatter.telstream/downloads');

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _downloadsChannel.invokeMethod('minimizeApp');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.tv_outlined),
              selectedIcon: Icon(Icons.tv),
              label: 'Anime',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie),
              label: 'Movies',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_collection_outlined),
              selectedIcon: Icon(Icons.video_collection),
              label: 'Web Series',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
