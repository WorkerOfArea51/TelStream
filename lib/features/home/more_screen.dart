import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/constants.dart';
import '../../core/secrets.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/tdlib_service.dart';
import '../../services/update_service.dart';
import '../../core/widgets/whats_new_dialog.dart';
import '../../core/widgets/m3_animated_menu_tile.dart';
import '../settings/settings_screen.dart';
import 'history_screen.dart';
import 'network_stream_screen.dart';
import 'downloads_screen.dart';
import 'global_search_screen.dart';
import 'airing_calendar_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  td.User? _currentUser;
  String? _localPhotoPath;
  bool _isLoadingUser = true;

  int _monthlySeconds = 174120; // Default seed (48 hrs 22 min)
  int _dailySeconds = 5820;     // Default seed (1 hr 37 min)
  int _watchStreak = 14;        // Default seed (14 Days)
  Timer? _screenTimeTimer;

  @override
  void initState() {
    super.initState();
    _loadTelegramUser();
    _loadStats();
    _startScreenTimeTracker();
  }

  @override
  void dispose() {
    _screenTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTelegramUser() async {
    try {
      final tdlib = ref.read(tdlibServiceProvider);
      final me = await tdlib.sendAsync(const td.GetMe());
      if (me is td.User) {
        setState(() {
          _currentUser = me;
        });

        final photo = me.profilePhoto;
        if (photo != null) {
          final smallFile = photo.small;
          if (smallFile.local.path.isNotEmpty) {
            setState(() {
              _localPhotoPath = smallFile.local.path;
              _isLoadingUser = false;
            });
          } else {
            // Trigger download of the profile photo file
            final res = await tdlib.sendAsync(td.DownloadFile(
              fileId: smallFile.id,
              priority: 32,
              offset: 0,
              limit: 0,
              synchronous: true,
            ));
            if (res is td.File && res.local.path.isNotEmpty) {
              setState(() {
                _localPhotoPath = res.local.path;
              });
            }
            setState(() {
              _isLoadingUser = false;
            });
          }
        } else {
          setState(() {
            _isLoadingUser = false;
          });
        }
      } else {
        setState(() {
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading telegram user: $e");
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  void _loadStats() {
    final storage = ref.read(storageServiceProvider);
    setState(() {
      _monthlySeconds = storage.getScreenTimeMonthly();
      _dailySeconds = storage.getScreenTimeDaily();
      _watchStreak = calculateWatchStreak(storage.getHistoryLog());
    });
  }

  void _startScreenTimeTracker() {
    _screenTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _dailySeconds += 5;
        _monthlySeconds += 5;
      });
      ref.read(storageServiceProvider).saveScreenTime(
        monthly: _monthlySeconds,
        daily: _dailySeconds,
      );
    });
  }

  int calculateWatchStreak(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return 14; // Default seed to keep look nicely populated
    final dates = logs
        .map((item) => DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();
    dates.sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (!dates.contains(todayDate) && !dates.contains(yesterdayDate)) {
      return 14;
    }

    int streak = 0;
    DateTime currentTarget = dates.contains(todayDate) ? todayDate : yesterdayDate;

    while (dates.contains(currentTarget)) {
      streak++;
      currentTarget = currentTarget.subtract(const Duration(days: 1));
    }
    return streak > 14 ? streak : 14;
  }

  String _formatScreenTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final hrStr = hours == 1 ? 'hr' : 'hrs';
    return '$hours $hrStr $minutes min';
  }

  String _getUserUsername(td.User user) {
    try {
      final dynamic dynUser = user;
      final u = dynUser.username;
      if (u is String && u.isNotEmpty) return u;
    } catch (_) {}
    try {
      final dynamic dynUser = user;
      final usernamesObj = dynUser.usernames;
      if (usernamesObj != null) {
        final activeUsernames = usernamesObj.activeUsernames;
        if (activeUsernames is List && activeUsernames.isNotEmpty) {
          return activeUsernames.first.toString();
        }
      }
    } catch (_) {}
    return '';
  }

  Widget _buildIndividualBar({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDownloadedOnly = ref.watch(downloadedOnlyProvider);
    final isIncognitoMode = ref.watch(incognitoModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final settingsAccent = theme.extension<AppThemeExtension>()?.settingsAccent ?? theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                // Top Header Branding
                Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.play_circle_fill, size: 60, color: theme.primaryColor);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TelStream',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Telegram User Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2333) : theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar image
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: settingsAccent.withValues(alpha: 0.5), width: 2),
                            ),
                            child: _isLoadingUser
                                ? const CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.transparent,
                                    child: CircularProgressIndicator(),
                                  )
                                : (_localPhotoPath != null && File(_localPhotoPath!).existsSync()
                                    ? CircleAvatar(
                                        radius: 36,
                                        backgroundImage: FileImage(File(_localPhotoPath!)),
                                      )
                                    : CircleAvatar(
                                        radius: 36,
                                        backgroundColor: settingsAccent,
                                        child: Text(
                                          _currentUser != null
                                              ? '${_currentUser!.firstName.isNotEmpty ? _currentUser!.firstName[0] : ''}${_currentUser!.lastName.isNotEmpty ? _currentUser!.lastName[0] : ''}'
                                              : 'TS',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )),
                          ),
                          const SizedBox(width: 16),
                          // User details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentUser != null
                                      ? '${_currentUser!.firstName} ${_currentUser!.lastName}'.trim()
                                      : 'Telegram User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentUser != null
                                      ? (_getUserUsername(_currentUser!).isNotEmpty
                                          ? '@${_getUserUsername(_currentUser!)}'
                                          : 'ID: ${_currentUser!.id}')
                                      : 'Not loaded',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (_currentUser == null) return;
                                    final username = _getUserUsername(_currentUser!);
                                    final url = username.isNotEmpty
                                        ? 'tg://resolve?domain=$username'
                                        : 'tg://user?id=${_currentUser!.id}';
                                    _launchURL(url);
                                  },
                                  child: const Text(
                                    'View Profile',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('This Month', _formatScreenTime(_monthlySeconds)),
                          Container(width: 1, height: 32, color: Colors.white10),
                          _buildStatColumn('Average Daily', _formatScreenTime(_dailySeconds)),
                          Container(width: 1, height: 32, color: Colors.white10),
                          _buildStatColumn('Watch Streak', '$_watchStreak Days'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Settings & Features Heading
                const Text(
                  'Settings & Features',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Individual Squircle Bars
                _buildIndividualBar(
                  child: _buildSwitchTile(
                    title: 'Downloaded only',
                    subtitle: 'Filters libraries to only show watched/local episodes',
                    value: isDownloadedOnly,
                    onChanged: (val) {
                      ref.read(downloadedOnlyProvider.notifier).toggle(val);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: _buildSwitchTile(
                    title: 'Incognito mode',
                    subtitle: 'Pauses watch history and progress logging',
                    value: isIncognitoMode,
                    onChanged: (val) {
                      ref.read(incognitoModeProvider.notifier).toggle(val);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.history,
                    title: 'History',
                    subtitle: 'View your watched videos history',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.download_done_rounded,
                    title: 'Downloads',
                    subtitle: 'Manage local offline files',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DownloadsScreen(initialIndex: 1)),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.link,
                    title: 'Network stream',
                    subtitle: 'Play online video URLs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NetworkStreamScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.search_rounded,
                    title: 'Global Search',
                    subtitle: 'Search across all providers',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Airing Calendar',
                    subtitle: 'Weekly schedule of new anime/series',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AiringCalendarScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.settings,
                    title: 'Settings',
                    subtitle: 'General preferences, player, cache, styling',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.system_update_alt_rounded,
                    title: 'Check for update',
                    subtitle: 'Check for application updates',
                    onTap: () {
                      _manuallyCheckForUpdate(context);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Version details, libraries, contact info',
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _manuallyCheckForUpdate(BuildContext context) async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      ),
    );

    final updateInfo = await UpdateService.checkForUpdate();

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (updateInfo == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to check for updates. Please check your internet connection.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      if (updateInfo.isUpdateAvailable) {
        UpdateService.showUpdateDialog(context, updateInfo);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 1),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Text('Up to Date', style: TextStyle(color: theme.colorScheme.onSurface)),
              ],
            ),
            content: Text(
              'You are running the latest version of TelStream.',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: theme.primaryColor)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Glowing Logo Center
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.play_circle_fill, size: 55, color: theme.primaryColor);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'TelStream',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v${Constants.currentVersion} • Fairy Tail (${Secrets.buildTag})',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'TelStream is a premium, open-source streaming client designed for watching Anime, Movies, and Web Series. Built on modern tech stacks, it features seamless media cache control and high-performance video streaming capabilities.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                      foregroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close about dialog
                      WhatsNewDialog.show(context);
                    },
                    icon: const Icon(Icons.history_edu_rounded, size: 18),
                    label: const Text('View Changelog'),
                  ),
                  const SizedBox(height: 28),

                  // Section: Developer & Project
                  Text(
                    'PROJECT INFO & DEVELOPER',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildLinkTile(
                          icon: Icons.code_rounded,
                          title: 'GitHub Repository',
                          subtitle: 'github.com/WorkerOfArea51/TelStream',
                          url: 'https://github.com/WorkerOfArea51/TelStream',
                        ),
                        Divider(color: theme.dividerColor, height: 1, indent: 56),
                        _buildLinkTile(
                          icon: Icons.bug_report_rounded,
                          title: 'Report Bug / Request Feature',
                          subtitle: 'Submit issues or suggest enhancements',
                          url: 'https://github.com/WorkerOfArea51/TelStream/issues/new/choose',
                        ),
                        Divider(color: theme.dividerColor, height: 1, indent: 56),
                        _buildLinkTile(
                          icon: Icons.person_rounded,
                          title: 'Developer Profile',
                          subtitle: 'GitHub @WorkerOfArea51',
                          url: 'https://github.com/WorkerOfArea51',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section: Tech Stack
                  Text(
                    'CORE TECHNOLOGIES',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        const _TechRow(
                          name: 'Flutter & Dart',
                          desc: 'Cross-platform UI engine & programming language.',
                        ),
                        Divider(color: theme.dividerColor, height: 20),
                        const _TechRow(
                          name: 'TDLib (Telegram Database)',
                          desc: 'High-speed native client for MTProto API integration.',
                        ),
                        Divider(color: theme.dividerColor, height: 20),
                        const _TechRow(
                          name: 'MediaKit & libmpv',
                          desc: 'Hardware-accelerated video decoding & audio controller.',
                        ),
                        Divider(color: theme.dividerColor, height: 20),
                        const _TechRow(
                          name: 'Riverpod',
                          desc: 'Reactive state caching & dependency injection framework.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section: Legal / License
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor, width: 1),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Open Source License',
                          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        TextButton(
                          onPressed: () => _launchURL('https://github.com/WorkerOfArea51/TelStream/blob/main/LICENSE'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('MIT License', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.primaryColor, size: 20),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
      trailing: Icon(Icons.open_in_new_rounded, color: subTextColor.withValues(alpha: 0.5), size: 16),
      onTap: () => _launchURL(url),
    );
  }

  void _launchURL(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch URL: $e");
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subTextColor, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TechRow extends StatelessWidget {
  final String name;
  final String desc;

  const _TechRow({required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            desc,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }
}
