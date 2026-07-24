import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/tdlib_service.dart';

class TelegramProfileCard extends ConsumerStatefulWidget {
  const TelegramProfileCard({super.key});

  @override
  ConsumerState<TelegramProfileCard> createState() => _TelegramProfileCardState();
}

class _TelegramProfileCardState extends ConsumerState<TelegramProfileCard> {
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
      final storage = ref.read(storageServiceProvider);
      storage.incrementScreenTime(5).then((_) {
        if (mounted) {
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

  String _formatScreenTime(int totalSeconds, BuildContext context) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    return '$hours ${AppLocalizations.of(context)!.hoursShort(hours)} $minutes ${AppLocalizations.of(context)!.minutesShort}';
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

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildStatColumn(BuildContext context, String label, String value) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final settingsAccent = theme.extension<AppThemeExtension>()?.settingsAccent ?? theme.primaryColor;

    return Container(
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
                          : AppLocalizations.of(context)!.telegramUser,
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
                          : AppLocalizations.of(context)!.notLoaded,
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
                        AppLocalizations.of(context)!.viewProfile,
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
              _buildStatColumn(context, AppLocalizations.of(context)!.thisMonth, _formatScreenTime(_monthlySeconds, context)),
              Container(width: 1, height: 32, color: Colors.white10),
              _buildStatColumn(context, AppLocalizations.of(context)!.averageDaily, _formatScreenTime(_averageDailySeconds, context)),
              Container(width: 1, height: 32, color: Colors.white10),
              _buildStatColumn(context, AppLocalizations.of(context)!.watchStreak, AppLocalizations.of(context)!.nDaysStreak(_watchStreak)),
            ],
          ),
        ],
      ),
    );
  }
}
