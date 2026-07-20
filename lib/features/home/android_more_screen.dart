import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/tdlib_service.dart';
import '../../services/update_service.dart';
import '../../core/widgets/m3_animated_menu_tile.dart';
import 'widgets/custom_about_dialog.dart';
import '../settings/settings_screen.dart';
import 'history_screen.dart';
import 'network_stream_screen.dart';
import 'downloads_screen.dart';
import 'global_search_screen.dart';
import 'airing_calendar_screen.dart';
import '../settings/user_channels_screen.dart';
import '../../l10n/app_localizations.dart';

class AndroidMoreScreen extends ConsumerStatefulWidget {
  const AndroidMoreScreen({super.key});

  @override
  ConsumerState<AndroidMoreScreen> createState() => _AndroidMoreScreenState();
}

class _AndroidMoreScreenState extends ConsumerState<AndroidMoreScreen>
    with WidgetsBindingObserver {
  td.User? _currentUser;
  String? _localPhotoPath;
  bool _isLoadingUser = true;

  int _monthlySeconds = 0;
  int _averageDailySeconds = 0;
  int _watchStreak = 0;
  Timer? _screenTimeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTelegramUser();
    _loadStats();
    _startScreenTimeTracker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTelegramUser() async {
    try {
      final tdlib = ref.read(tdlibServiceProvider);
      final me = await tdlib.sendAsync(const td.GetMe());
      if (!mounted) return;
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
              priority: 1,
              offset: 0,
              limit: 0,
              synchronous: true,
            ));
            if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  void _loadStats() {
    final storage = ref.read(storageServiceProvider);
    final logs = storage.getScreenTimeDailyLogs();
    
    final now = DateTime.now();
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    int monthlySum = 0;
    int activeDays = 0;
    logs.forEach((date, seconds) {
      if (date.startsWith(monthPrefix)) {
        monthlySum += seconds;
        if (seconds > 0) {
          activeDays++;
        }
      }
    });

    setState(() {
      _monthlySeconds = monthlySum;
      _averageDailySeconds = activeDays > 0 ? (monthlySum ~/ activeDays) : 0;
      _watchStreak = calculateWatchStreak(storage.getHistoryLog());
    });
  }

  void _startScreenTimeTracker() {
    _screenTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      // Don't accrue screen time while the app is backgrounded.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final storage = ref.read(storageServiceProvider);
      storage.incrementScreenTime(5).then((_) {
        if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          _loadStats();
        }
      });
    });
  }

  int calculateWatchStreak(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return 0;
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
      return 0;
    }

    int streak = 0;
    DateTime currentTarget = dates.contains(todayDate) ? todayDate : yesterdayDate;

    while (dates.contains(currentTarget)) {
      streak++;
      currentTarget = currentTarget.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _formatScreenTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final l10n = AppLocalizations.of(context)!;
    return '$hours ${l10n.hoursShort(hours)} $minutes ${l10n.minutesShort}';
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
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                // Top Header Branding (Horizontal Row matching 2nd photo's header position)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.play_circle_fill, size: 24, color: theme.primaryColor);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'TelStream',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

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
                                  child: Text(
                                    l10n.viewProfile,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          _buildStatColumn(l10n.thisMonth, _formatScreenTime(_monthlySeconds)),
                          Container(width: 1, height: 32, color: Colors.white10),
                          _buildStatColumn(l10n.averageDaily, _formatScreenTime(_averageDailySeconds)),
                          Container(width: 1, height: 32, color: Colors.white10),
                          _buildStatColumn(l10n.watchStreak, '$_watchStreak Days'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Settings & Features Heading
                Text(
                  l10n.settingsAndFeatures,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Individual Squircle Bars
                _buildIndividualBar(
                  child: _buildSwitchTile(
                    title: l10n.downloadedOnly,
                    subtitle: l10n.downloadedOnlySubtitle,
                    value: isDownloadedOnly,
                    onChanged: (val) {
                      ref.read(downloadedOnlyProvider.notifier).toggle(val);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: _buildSwitchTile(
                    title: l10n.incognitoMode,
                    subtitle: l10n.incognitoModeSubtitle,
                    value: isIncognitoMode,
                    onChanged: (val) {
                      ref.read(incognitoModeProvider.notifier).toggle(val);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.playlist_add_rounded,
                    title: l10n.myChannelsTitle,
                    subtitle: l10n.myChannelsSubtitle,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserChannelsScreen()),
                      );
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.history,
                    title: l10n.history,
                    subtitle: l10n.historySubtitle,
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
                    title: l10n.downloads,
                    subtitle: l10n.downloadsSubtitle,
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
                    title: l10n.networkStream,
                    subtitle: l10n.networkStreamSubtitle,
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
                    title: l10n.globalSearch,
                    subtitle: l10n.globalSearchSubtitle,
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
                    title: l10n.airingCalendar,
                    subtitle: l10n.airingCalendarSubtitle,
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
                    title: l10n.settings,
                    subtitle: l10n.settingsSubtitle,
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
                    title: l10n.checkForUpdate,
                    subtitle: l10n.checkForUpdateSubtitle,
                    onTap: () {
                      _manuallyCheckForUpdate(context);
                    },
                  ),
                ),
                _buildIndividualBar(
                  child: M3AnimatedMenuTile(
                    icon: Icons.info_outline,
                    title: l10n.about,
                    subtitle: l10n.aboutSubtitle,
                    onTap: () {
                      CustomAboutDialog.show(context);
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

    await UpdateService.checkAndShowDialogIfAvailable(context, manual: true, showErrorSnack: true);

    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
    }
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

