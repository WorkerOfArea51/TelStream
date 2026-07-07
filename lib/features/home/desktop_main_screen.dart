import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants.dart';
import '../../models/anime_models.dart';
import 'desktop_state.dart';

import 'downloads_screen.dart';
import 'history_screen.dart';
import 'global_search_screen.dart';

import 'desktop_library_view.dart';
import 'android_series_details_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_provider.dart';
import '../player/pip_manager.dart';
import '../player/video_player_screen.dart';
import '../player/widgets/track_selector_panel.dart';
import '../../services/storage_service.dart';
import 'package:media_kit/media_kit.dart';
import 'airing_calendar_screen.dart';
import '../../services/update_service.dart';
import 'widgets/custom_about_dialog.dart';
import 'network_stream_screen.dart';
import 'dart:io';

class DesktopMainScreen extends ConsumerStatefulWidget {
  const DesktopMainScreen({super.key});

  @override
  ConsumerState<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends ConsumerState<DesktopMainScreen> with TickerProviderStateMixin, WindowListener {
  bool _isFullScreen = false;
  bool _wasMaximized = false;
  bool _isTopHovered = false;
  bool _isBottomHovered = false;
  bool _isRightPanelOpen = true;
  bool _isRightEdgeHovered = false;
  
  String _currentRightPanelView = 'library'; // 'library', 'downloads', 'history'
  
  late TabController _tabController;

  void _showNotImplementedDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1c),
        title: const Text('Coming Soon', style: TextStyle(color: Colors.white)),
        content: Text('$featureName will be fully integrated once the native PC video player engine is connected.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showOpenStreamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1c),
        title: const Text('Open Stream', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter stream URL (e.g., https://...)',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.pop(context);
                ref.read(pipControllerProvider.notifier).playVideo(
                  context,
                  messageId: 0,
                  videoFileId: 0,
                  videoTitle: 'Network Stream',
                  networkUrl: value,
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context);
                ref.read(pipControllerProvider.notifier).playVideo(
                  context,
                  messageId: 0,
                  videoFileId: 0,
                  videoTitle: 'Network Stream',
                  networkUrl: value,
                );
              }
            },
            child: const Text('Play', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowState();
    _tabController = TabController(length: 3, vsync: this);
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && updateInfo.isUpdateAvailable && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    }
  }

  void _initWindowState() async {
    _isFullScreen = await windowManager.isFullScreen();
    if (mounted) setState(() {});
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTopBar(bool showTop) {
    final theme = Theme.of(context);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: showTop ? 0 : -40,
      left: 0,
      right: 0,
      height: 40,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isTopHovered = true),
        onExit: (_) => setState(() => _isTopHovered = false),
        child: Container(
          color: const Color(0xFF141414), // Lighter than pure black for contrast
          child: Row(
            children: [
              // TelStream Logo Dropdown (The "More" menu)
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  color: const Color(0xFF141414), // Match top bar
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  tooltip: 'Menu',
                  onSelected: (value) async {
                    if (value == 'downloads' || value == 'history' || value == 'preferences') {
                      setState(() {
                        _currentRightPanelView = value;
                        _isRightPanelOpen = true; // Ensure it's open
                      });
                    } else if (value == 'video' || value == 'audio' || value == 'subtitles') {
                      int index = 0;
                      if (value == 'video') index = 1;
                      if (value == 'subtitles') index = 2;
                      _showControlPanelDialog(context, initialIndex: index);
                    } else if (value == 'update') {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: Colors.orange),
                        ),
                      );
                      final updateInfo = await UpdateService.checkForUpdate();
                      if (context.mounted) Navigator.pop(context); // Close loading
                      
                      if (updateInfo != null && updateInfo.isUpdateAvailable && context.mounted) {
                        UpdateService.showUpdateDialog(context, updateInfo);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You are on the latest version!')),
                        );
                      }
                    } else if (value == 'about') {
                      CustomAboutDialog.show(context);
                    } else if (value == 'open') {
                      _showOpenStreamDialog(context);
                    } else if (value == 'calendar') {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: const SizedBox(
                              width: 800,
                              height: 600,
                              child: AiringCalendarScreen(),
                            ),
                          ),
                        ),
                      );
                    } else if (value == 'exit') {
                      windowManager.close();
                    }
                  },
                  itemBuilder: (context) => [
                    _buildMenuItem('open', 'Open Stream...', shortcut: 'Ctrl+O'),
                    _buildMenuItem('downloads', 'Downloads', shortcut: 'Ctrl+D'),
                    _buildMenuItem('history', 'History / Playback', shortcut: 'Ctrl+H'),
                    _buildMenuItem('calendar', 'Airing Calendar', shortcut: 'Ctrl+Cal'),
                    _buildMenuItem('div1', '', isDivider: true),
                    _buildMenuItem('video', 'Video', hasSubmenu: true),
                    _buildMenuItem('audio', 'Audio', hasSubmenu: true),
                    _buildMenuItem('subtitles', 'Subtitles', hasSubmenu: true),
                    _buildMenuItem('div2', '', isDivider: true),
                    _buildMenuItem('preferences', 'Preferences...', shortcut: 'F5'),
                    _buildMenuItem('update', 'Check for Update'),
                    _buildMenuItem('about', 'About'),
                    _buildMenuItem('div3', '', isDivider: true),
                    _buildMenuItem('exit', 'Exit', shortcut: 'Alt+F4'),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_filled, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'TelStream',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Draggable area
              const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
              

              
              // Window Controls
              WindowCaptionButton.minimize(
                brightness: Brightness.dark,
                onPressed: () async => await windowManager.minimize(),
              ),
              WindowCaptionButton.maximize(
                brightness: Brightness.dark,
                onPressed: () async {
                  if (_isFullScreen) {
                    setState(() => _isFullScreen = false);
                    await windowManager.setFullScreen(false);
                    await windowManager.maximize();
                  } else {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                      await windowManager.setSize(const Size(1000, 700));
                      await windowManager.center();
                    } else {
                      await windowManager.maximize();
                    }
                  }
                },
              ),
              IconButton(
                icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () async {
                  if (_isFullScreen) {
                    setState(() => _isFullScreen = false);
                    await windowManager.setFullScreen(false);
                    if (_wasMaximized) {
                      await windowManager.maximize();
                    } else {
                      await windowManager.unmaximize();
                    }
                  } else {
                    _wasMaximized = await windowManager.isMaximized();
                    setState(() => _isFullScreen = true);
                    await windowManager.setFullScreen(true);
                  }
                },
              ),
              WindowCaptionButton.close(
                brightness: Brightness.dark,
                onPressed: () async => await windowManager.close(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool showBottom, bool showRight) {
    final theme = Theme.of(context);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      bottom: showBottom ? 0 : -68,
      left: 0,
      right: showRight ? 350 : 0, // Adjust width based on panel state
      height: 68,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isBottomHovered = true),
        onExit: (_) => setState(() => _isBottomHovered = false),
        child: Container(
          color: const Color(0xFF141414), // Lighter than pure black for contrast
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Desktop Playback Controls
              DesktopPlaybackControls(
                player: ref.watch(activePlayerProvider),
                pipState: ref.watch(pipControllerProvider),
                pipNotifier: ref.read(pipControllerProvider.notifier),
                rightSideTools: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: () {
                      setState(() {
                        _currentRightPanelView = 'search';
                        _isRightPanelOpen = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    onPressed: () => _showControlPanelDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    onPressed: () {
                      setState(() {
                        _isRightPanelOpen = !_isRightPanelOpen;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(bool showTop, bool showRight, AnimeSeries? selectedSeries) {
    final theme = Theme.of(context);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      top: showTop ? 40 : 0,
      bottom: 0,
      right: showRight ? 0 : -350,
      width: 350,
      child: MouseRegion(
        onEnter: (_) {
          if (_isFullScreen) setState(() => _isRightEdgeHovered = true);
        },
        onExit: (_) {
          if (_isFullScreen) setState(() => _isRightEdgeHovered = false);
        },
        child: Container(
          color: theme.cardColor,
          child: Column(
            children: [
              if (selectedSeries != null) ...[

                Expanded(
                  child: AndroidSeriesDetailsScreen(
                    series: selectedSeries,
                    categoryTitle: 'Anime',
                    onBack: () {
                      ref.read(desktopSelectedSeriesProvider.notifier).state = null;
                      ref.read(desktopSelectedEpisodeProvider.notifier).state = null;
                    },
                  ),
                ),
              ] else if (_currentRightPanelView == 'library') ...[
                // Custom TabBar
                Container(
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: theme.primaryColor,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Anime'),
                            Tab(text: 'Movies'),
                            Tab(text: 'Web Series'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DesktopLibraryView(category: Constants.categories[0]),
                      DesktopLibraryView(category: Constants.categories[1]),
                      DesktopLibraryView(category: Constants.categories[2]),
                    ],
                  ),
                ),
              ] else if (_currentRightPanelView == 'search') ...[
                Expanded(
                  child: GlobalSearchScreen(
                    onBack: () => setState(() => _currentRightPanelView = 'library'),
                  ),
                ),
              ] else ...[
                // Back Button Header for Downloads/History
                Container(
                  color: theme.scaffoldBackgroundColor,
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => setState(() => _currentRightPanelView = 'library'),
                      ),
                      Expanded(
                        child: Text(
                          _currentRightPanelView == 'downloads' ? 'Downloads' : 'History',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _currentRightPanelView == 'downloads'
                      ? const DownloadsScreen()
                      : const HistoryScreen(),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoverDetectors() {
    return Stack(
      children: [
        // Top Hover Detector
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 10,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isTopHovered = true),
            child: const SizedBox.expand(),
          ),
        ),
        // Bottom Hover Detector
        Positioned(
          bottom: 0,
          left: 0,
          right: _isRightPanelOpen ? 350 : 0,
          height: 10,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isBottomHovered = true),
            child: const SizedBox.expand(),
          ),
        ),
        // Right Edge Hover Detector (only active in fullscreen)
        if (_isFullScreen && !_isRightEdgeHovered)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 10,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isRightEdgeHovered = true),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String title, {String? shortcut, bool hasSubmenu = false, bool isDivider = false}) {
    if (isDivider) {
      return const PopupMenuItem<String>(
        value: '',
        enabled: false,
        height: 1,
        padding: EdgeInsets.zero,
        child: Divider(color: Colors.white24, height: 1),
      );
    }
    return PopupMenuItem<String>(
      value: value,
      height: 32, // Dense height like PotPlayer
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13))),
          if (shortcut != null)
            Text(shortcut, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (hasSubmenu)
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.arrow_right, color: Colors.white54, size: 16),
            )
          else if (shortcut == null)
            const SizedBox(width: 32), // Spacer for items without shortcuts/submenus to align nicely
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTop = !_isFullScreen || _isTopHovered;
    final showBottom = !_isFullScreen || _isBottomHovered;
    final showRight = !_isFullScreen ? _isRightPanelOpen : _isRightEdgeHovered;
    final selectedSeries = ref.watch(desktopSelectedSeriesProvider);
    final pipState = ref.watch(pipControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Base color is black like player background
      body: Stack(
        children: [
          // Main Background Area (where video plays)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: showRight ? 350 : 0,
            child: pipState != null
                ? VideoPlayerScreen(
                    messageId: pipState.messageId,
                    videoFileId: pipState.videoFileId,
                    videoTitle: pipState.videoTitle,
                    episodeList: pipState.episodeList,
                    currentEpisodeIndex: pipState.currentEpisodeIndex,
                    seriesName: pipState.seriesName,
                    networkUrl: pipState.networkUrl,
                    isPip: false,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_outline, size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'TelStream',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white.withOpacity(0.2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Detectors
          _buildHoverDetectors(),

          // Overlays
          _buildRightPanel(showTop, showRight, selectedSeries),
          _buildBottomBar(showBottom, showRight),
          _buildTopBar(showTop),
        ],
      ),
    );
  }

  void _showControlPanelDialog(BuildContext context, {int initialIndex = 0}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Like a native floating window
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              right: 16,
              bottom: 80, // Above the bottom control bar
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 360,
                  height: 320,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.95), // Slight glassmorphism
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: DefaultTabController(
                    length: 4,
                    initialIndex: initialIndex,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.settings, color: Colors.white70, size: 14),
                              const SizedBox(width: 8),
                              const Text('Control Panel', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                                onPressed: () => Navigator.pop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                hoverColor: Colors.red.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ),
                        // Tabs
                        const TabBar(
                          indicatorColor: Colors.orange,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white54,
                          labelStyle: TextStyle(fontSize: 12),
                          tabs: [
                            Tab(text: 'Audio'),
                            Tab(text: 'Video'),
                            Tab(text: 'Subtitle'),
                            Tab(text: 'Playback'),
                          ],
                        ),
                        // Tab content
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildTrackPanel(isSubtitle: false),
                              const Center(child: Text('Video Controls', style: TextStyle(color: Colors.white54))),
                              _buildTrackPanel(isSubtitle: true),
                              const Center(child: Text('Playback Controls', style: TextStyle(color: Colors.white54))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackPanel({required bool isSubtitle}) {
    final player = ref.watch(activePlayerProvider);
    if (player == null) {
      return Center(
        child: Text(
          'No video currently playing',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final settings = ref.watch(videoSettingsProvider);
    final storage = ref.read(storageServiceProvider);

    return TrackSelectorPanel(
      player: player,
      isSubtitle: isSubtitle,
      trackCodecs: const {},
      currentRendererMode: settings.subtitleRendererMode,
      onRendererModeChanged: (newMode) {
        ref.read(videoSettingsProvider.notifier).updateSettings(
          settings.copyWith(subtitleRendererMode: newMode),
        );
      },
      currentDecoderMode: storage.getHardwareDecoderMode(),
      onDecoderModeChanged: (newDecoderMode) async {
        await storage.setHardwareDecoderMode(newDecoderMode);
        try {
          if (player.platform is NativePlayer) {
            final nativePlayer = player.platform as NativePlayer;
            if (newDecoderMode != 'no') {
              nativePlayer.setProperty('hwdec', Platform.isAndroid ? newDecoderMode : 'auto');
            } else {
              nativePlayer.setProperty('hwdec', 'no');
            }
          }
        } catch (_) {}
        setState(() {});
      },
      currentSubtitleDelay: settings.subtitleDelay,
      onSubtitleDelayChanged: (val) {
        final roundedVal = double.parse(val.toStringAsFixed(1));
        if (player.platform is NativePlayer) {
          try {
            (player.platform as NativePlayer).setProperty('sub-delay', roundedVal.toString());
          } catch (_) {}
        }
        storage.setSubtitleDelay(roundedVal);
        ref.read(videoSettingsProvider.notifier).updateSettings(settings.copyWith(subtitleDelay: roundedVal));
      },
      currentAudioDelay: 0.0, // Used inside AudioSyncDialog normally
      onAudioDelayChanged: (val) {},
      onTrackSelected: (track) {
        if (isSubtitle) {
          player.setSubtitleTrack(track as SubtitleTrack);
          if (track.id != 'no' && track.id != 'auto') {
            storage.setPreferredSubtitleTrackForAudioLanguage(
              player.state.track.audio.language ?? 'und', 
              track.language ?? 'und',
            );
          }
        } else {
          player.setAudioTrack(track as AudioTrack);
          if (track.id != 'no' && track.id != 'auto') {
            storage.setPreferredAudioTrack(track.language ?? 'und');
          }
        }
      },
      onPickLocalSubtitle: () {},
      onOpenSubtitleDownloader: () {},
      onClose: () {},
      currentFontSize: settings.subtitleFontSize,
      hideHeader: true,
      onFontSizeChanged: (val) {
        storage.setSubtitleFontSize(val);
        ref.read(videoSettingsProvider.notifier).updateSettings(settings.copyWith(subtitleFontSize: val));
      },
      currentFontColor: settings.subtitleColor,
      onFontColorChanged: (val) {
        storage.setSubtitleColor(val);
        ref.read(videoSettingsProvider.notifier).updateSettings(settings.copyWith(subtitleColor: val));
      },
      currentFontFamily: settings.subtitleFont,
      onFontFamilyChanged: (val) {
        storage.setSubtitleFont(val);
        ref.read(videoSettingsProvider.notifier).updateSettings(settings.copyWith(subtitleFont: val));
      },
    );
  }
}

class DesktopPlaybackControls extends StatefulWidget {
  final dynamic player;
  final PipVideoState? pipState;
  final PipController pipNotifier;
  final List<Widget> rightSideTools;

  const DesktopPlaybackControls({
    super.key,
    required this.player,
    required this.pipState,
    required this.pipNotifier,
    required this.rightSideTools,
  });

  @override
  State<DesktopPlaybackControls> createState() => _DesktopPlaybackControlsState();
}

class _DesktopPlaybackControlsState extends State<DesktopPlaybackControls> {
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
    }
    return '${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = widget.player;
    
    if (player == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 12, child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 2.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0)),
            child: Slider(value: 0, onChanged: (v) {}),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.play_arrow, size: 20), onPressed: null),
                IconButton(icon: const Icon(Icons.stop, size: 20), onPressed: null),
                IconButton(icon: const Icon(Icons.skip_previous, size: 20), onPressed: null),
                IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: null),
                const SizedBox(width: 16),
                const Text('00:00 / 00:00', style: TextStyle(fontSize: 12)),
                const Spacer(),
                const Icon(Icons.volume_up, size: 18, color: Colors.white70),
                SizedBox(width: 80, height: 24, child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 2.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0)),
                  child: Slider(value: 1, onChanged: (v) {}),
                )),
                const SizedBox(width: 8),
                ...widget.rightSideTools,
              ],
            ),
          ),
        ],
      );
    }

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, posSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durSnapshot) {
            return StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, playingSnapshot) {
                return StreamBuilder<double>(
                  stream: player.stream.volume,
                  builder: (context, volSnapshot) {
                    final position = posSnapshot.data ?? player.state.position;
                    final duration = durSnapshot.data ?? player.state.duration;
                    final isPlaying = playingSnapshot.data ?? player.state.playing;
                    final volume = volSnapshot.data ?? player.state.volume;

                    double progress = 0.0;
                    if (duration.inMilliseconds > 0) {
                      progress = position.inMilliseconds / duration.inMilliseconds;
                      progress = progress.clamp(0.0, 1.0);
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 12,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                              activeTrackColor: theme.primaryColor,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: theme.primaryColor,
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: (v) {
                                final targetMs = (v * duration.inMilliseconds).toInt();
                                player.seek(Duration(milliseconds: targetMs));
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                                onPressed: () {
                                  if (isPlaying) {
                                    player.pause();
                                  } else {
                                    player.play();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop, size: 20),
                                onPressed: () {
                                  player.pause();
                                  player.seek(Duration.zero);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous, size: 20),
                                onPressed: () {
                                  if (widget.pipState != null && widget.pipState!.currentIndex > 0) {
                                    widget.pipNotifier.playQueueIndex(context, widget.pipState!.currentIndex - 1);
                                  } else {
                                    player.seek(Duration.zero);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, size: 20),
                                onPressed: () {
                                  if (widget.pipState != null && widget.pipState!.currentIndex + 1 < widget.pipState!.queue.length) {
                                    widget.pipNotifier.playQueueIndex(context, widget.pipState!.currentIndex + 1);
                                  }
                                },
                              ),
                              
                              const SizedBox(width: 16),
                              Text('${_formatDuration(position)} / ${_formatDuration(duration)}', style: const TextStyle(fontSize: 12)),
                              
                              const Spacer(),
                              
                              Icon(volume > 0 ? Icons.volume_up : Icons.volume_off, size: 18, color: Colors.white70),
                              SizedBox(
                                width: 80,
                                height: 24,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                                    activeTrackColor: theme.primaryColor,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: (volume / 100).clamp(0.0, 1.0),
                                    onChanged: (v) {
                                      player.setVolume(v * 100);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ...widget.rightSideTools,
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                );
              }
            );
          }
        );
      }
    );
  }
}
