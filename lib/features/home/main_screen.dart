import 'dart:io';
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
    final isDesktop = Platform.isWindows;

    Widget mainBody = IndexedStack(
      index: _currentIndex,
      children: [
        LibraryView(category: Constants.categories[0], isActive: _currentIndex == 0), // Anime
        LibraryView(category: Constants.categories[1], isActive: _currentIndex == 1), // Movies
        LibraryView(category: Constants.categories[2], isActive: _currentIndex == 2), // Web Series
        const MoreScreen(),
      ],
    );

    if (isDesktop) {
      mainBody = Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.cardColor,
            indicatorColor: theme.primaryColor,
            selectedIconTheme: IconThemeData(
              color: theme.primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.tv_outlined),
                selectedIcon: Icon(Icons.tv),
                label: Text('Anime'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.movie_outlined),
                selectedIcon: Icon(Icons.movie),
                label: Text('Movies'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.video_collection_outlined),
                selectedIcon: Icon(Icons.video_collection),
                label: Text('Web Series'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.more_horiz_outlined),
                selectedIcon: Icon(Icons.more_horiz),
                label: Text('More'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
          Expanded(child: mainBody),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _downloadsChannel.invokeMethod('minimizeApp');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: mainBody,
        bottomNavigationBar: isDesktop
            ? null
            : NavigationBar(
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
