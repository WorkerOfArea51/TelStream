import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/permission_service.dart';
import '../../core/constants.dart';
import '../../services/update_service.dart';
import '../../services/storage_service.dart';
import '../../core/widgets/whats_new_dialog.dart';
import 'android_library_view.dart';
import 'android_more_screen.dart';
import 'user_channels_provider.dart';
import 'user_channels_home_screen.dart';
import '../../l10n/app_localizations.dart';

class AndroidMainScreen extends ConsumerStatefulWidget {
  const AndroidMainScreen({super.key});

  @override
  ConsumerState<AndroidMainScreen> createState() => _AndroidMainScreenState();
}

class _AndroidMainScreenState extends ConsumerState<AndroidMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const _downloadsChannel = MethodChannel('com.darkmatter.telstream/downloads');
  DateTime? _lastUpdateCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesSilently();
      ref.read(permissionServiceProvider).requestAllImportantPermissions();
      _showWhatsNewIfNeeded();
    });

    // Default to "My Channels" tab if user has channels
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userChannels = ref.read(userChannelsProvider);
      if (userChannels.isNotEmpty && _currentIndex == 0) {
        // Already at index 0, which is now "My Channels" — that's correct
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastUpdateCheck == null || now.difference(_lastUpdateCheck!).inMinutes >= 5) {
        _checkUpdatesSilently();
      }
    }
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
    _lastUpdateCheck = DateTime.now();
    await UpdateService.checkAndShowDialogIfAvailable(context, manual: false, showErrorSnack: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userChannels = ref.watch(userChannelsProvider);
    final hasUserChannels = userChannels.isNotEmpty;

    // Build the list of screens and destinations dynamically
    final screens = <Widget>[];
    final destinations = <NavigationDestination>[];

    if (hasUserChannels) {
      screens.add(UserChannelsHomeScreen(isActive: _currentIndex == 0));
      destinations.add(NavigationDestination(
        icon: const Icon(Icons.playlist_play_outlined),
        selectedIcon: const Icon(Icons.playlist_play),
        label: l10n.myChannels,
      ));
    }

    final animeIndex = screens.length;
    screens.add(AndroidLibraryView(category: Constants.categories[0], isActive: _currentIndex == animeIndex));
    destinations.add(NavigationDestination(
      icon: const Icon(Icons.tv_outlined),
      selectedIcon: const Icon(Icons.tv),
      label: l10n.categoryAnime,
    ));

    final moviesIndex = screens.length;
    screens.add(AndroidLibraryView(category: Constants.categories[1], isActive: _currentIndex == moviesIndex));
    destinations.add(NavigationDestination(
      icon: const Icon(Icons.movie_outlined),
      selectedIcon: const Icon(Icons.movie),
      label: l10n.categoryMovies,
    ));

    final webSeriesIndex = screens.length;
    screens.add(AndroidLibraryView(category: Constants.categories[2], isActive: _currentIndex == webSeriesIndex));
    destinations.add(NavigationDestination(
      icon: const Icon(Icons.video_collection_outlined),
      selectedIcon: const Icon(Icons.video_collection),
      label: l10n.categoryWebSeries,
    ));

    screens.add(const AndroidMoreScreen());
    destinations.add(NavigationDestination(
      icon: const Icon(Icons.more_horiz_outlined),
      selectedIcon: const Icon(Icons.more_horiz),
      label: l10n.more,
    ));

    // Clamp _currentIndex to valid range
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    Widget mainBody = IndexedStack(
      index: _currentIndex,
      children: screens,
    );

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: destinations,
        ),
      ),
    );
  }
}
