import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logger.dart';

Future<void>? _jikanQueue;
DateTime? _lastJikanRequestTime;

final airingScheduleProvider = FutureProvider.family<List<dynamic>, String>((ref, day) async {
  // Wait for previous requests in the queue to finish to avoid concurrent request bursts
  final completer = Completer<void>();
  final previous = _jikanQueue;
  _jikanQueue = completer.future;
  if (previous != null) {
    try {
      await previous;
    } catch (_) {}
  }

  try {
    // Ensure at least a 1.5-second gap between requests to respect Jikan's rate limits
    if (_lastJikanRequestTime != null) {
      final diff = DateTime.now().difference(_lastJikanRequestTime!);
      if (diff.inMilliseconds < 1500) {
        await Future.delayed(Duration(milliseconds: 1500 - diff.inMilliseconds));
      }
    }
    _lastJikanRequestTime = DateTime.now();

    final url = 'https://api.jikan.moe/v4/schedules?filter=$day';
    Log.i('Fetching Jikan airing schedule for: $day');
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final data = decoded['data'] as List<dynamic>? ?? [];
      return data;
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded. Please wait a moment and try again.');
    } else {
      throw Exception('Failed to load airing calendar (Status: ${response.statusCode})');
    }
  } finally {
    completer.complete();
  }
});

class AiringCalendarScreen extends ConsumerStatefulWidget {
  const AiringCalendarScreen({super.key});

  @override
  ConsumerState<AiringCalendarScreen> createState() => _AiringCalendarScreenState();
}

class _AiringCalendarScreenState extends ConsumerState<AiringCalendarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Start at current day of the week
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    _tabController = TabController(
      length: _days.length, 
      vsync: this, 
      initialIndex: (weekday - 1).clamp(0, 6),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: const Text(
          'Airing Calendar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Day Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: settingsAccent,
                labelColor: settingsAccent,
                unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: _dayLabels.map((label) => Tab(text: label)).toList(),
              ),
              // Search Input Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        }
                      });
                    },
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search today\'s releases...',
                      hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) {
          return _AiringCalendarTab(
            day: day,
            searchQuery: _searchQuery,
          );
        }).toList(),
      ),
    );
  }
}

class _AiringCalendarTab extends ConsumerWidget {
  final String day;
  final String searchQuery;

  const _AiringCalendarTab({
    required this.day,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(airingScheduleProvider(day));
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return scheduleAsync.when(
      data: (items) {
        // Filter by search query
        final filteredItems = items.where((item) {
          final title = (item['title'] as String? ?? '').toLowerCase();
          final englishTitle = (item['title_english'] as String? ?? '').toLowerCase();
          return title.contains(searchQuery) || englishTitle.contains(searchQuery);
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: 12),
                Text(
                  searchQuery.isNotEmpty ? 'No matches for today\'s releases' : 'No releases scheduled for today',
                  style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final size = MediaQuery.of(context).size;
        final crossAxisCount = size.width > 900 ? 4 : (size.width > 600 ? 3 : 2);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final title = item['title'] as String? ?? 'Unknown Title';
            final imageUrl = item['images']?.containsKey('jpg') == true
                ? item['images']['jpg']['large_image_url'] ?? item['images']['jpg']['image_url']
                : null;
            final score = item['score'] as num?;
            final episodes = item['episodes'] as int?;
            final broadcast = item['broadcast']?['string'] as String? ?? '';
            
            // Try to extract a clean time from the broadcast string
            String timeString = '';
            if (broadcast.isNotEmpty) {
              final match = RegExp(r'(\d{2}:\d{2})').firstMatch(broadcast);
              if (match != null) {
                timeString = '${match.group(1)} JST';
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Poster Image
                  Positioned.fill(
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              return Container(
                                color: Colors.grey.shade900,
                                child: Icon(Icons.movie, color: settingsAccent, size: 40),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: Icon(Icons.movie, color: settingsAccent, size: 40),
                          ),
                  ),
                  
                  // Top Overlay Badges
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (score != null && score > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  score.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(),
                        
                        if (episodes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$episodes Ep',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Gradient & Info
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.95),
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (timeString.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled, color: Colors.white54, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                err.toString().replaceAll('Exception:', '').trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => ref.invalidate(airingScheduleProvider(day)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

