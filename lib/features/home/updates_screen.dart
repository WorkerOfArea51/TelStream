import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:intl/intl.dart';
import '../../models/anime_models.dart';
import '../../core/widgets/td_thumbnail.dart';
import '../player/pip_manager.dart';
import 'home_controller.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animeState = ref.watch(animeControllerProvider);
    final moviesState = ref.watch(moviesControllerProvider);
    final webSeriesState = ref.watch(webSeriesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              ref.invalidate(animeControllerProvider);
              ref.invalidate(moviesControllerProvider);
              ref.invalidate(webSeriesControllerProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.orange,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.white60,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Anime'),
                Tab(text: 'Movies'),
                Tab(text: 'Web Series'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpdatesList(animeState, 'Anime'),
          _buildUpdatesList(moviesState, 'Movies'),
          _buildUpdatesList(webSeriesState, 'Web Series'),
        ],
      ),
    );
  }

  Widget _buildUpdatesList(AsyncValue<List<AnimeSeries>> state, String categoryTitle) {
    return state.when(
      data: (seriesList) {
        // Extract all episodes with dates and sort them
        final List<_UpdateItem> updates = [];
        
        for (var series in seriesList) {
          td.File? posterFile;
          final latestPoster = series.seasons.isNotEmpty ? series.seasons.first.posterMessage : null;
          if (latestPoster != null && latestPoster.content is td.MessagePhoto) {
            final photo = latestPoster.content as td.MessagePhoto;
            if (photo.photo.sizes.isNotEmpty) {
              posterFile = photo.photo.sizes.last.photo;
            }
          }

          for (var season in series.seasons) {
            for (int i = 0; i < season.episodes.length; i++) {
              final ep = season.episodes[i];
              updates.add(_UpdateItem(
                seriesName: series.coreName,
                episodeIndex: i,
                message: ep,
                posterFile: posterFile,
                series: series,
              ));
            }
          }
        }

        // Sort descending by date
        updates.sort((a, b) => b.message.date.compareTo(a.message.date));

        if (updates.isEmpty) {
          return _buildEmptyState();
        }

        // Group updates by date string (e.g. "May 21, 2026")
        final Map<String, List<_UpdateItem>> grouped = {};
        final todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
        final yesterdayStr = DateFormat('MMMM d, yyyy').format(DateTime.now().subtract(const Duration(days: 1)));

        for (var item in updates) {
          final dt = DateTime.fromMillisecondsSinceEpoch(item.message.date * 1000);
          var dateStr = DateFormat('MMMM d, yyyy').format(dt);
          if (dateStr == todayStr) {
            dateStr = 'Today';
          } else if (dateStr == yesterdayStr) {
            dateStr = 'Yesterday';
          }
          grouped.putIfAbsent(dateStr, () => []).add(item);
        }

        final keys = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: keys.length,
          itemBuilder: (context, groupIndex) {
            final dateHeader = keys[groupIndex];
            final items = grouped[dateHeader]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                  child: Text(
                    dateHeader,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildUpdateRow(context, item);
                  },
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '(>=_<=)',
            style: TextStyle(fontSize: 48, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'No recent updates',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateRow(BuildContext context, _UpdateItem item) {
    int? fileId;
    String epTitle = 'Episode ${item.episodeIndex + 1}';
    
    if (item.message.content is td.MessageVideo) {
      final v = item.message.content as td.MessageVideo;
      fileId = v.video.video.id;
      epTitle = v.video.fileName;
    } else if (item.message.content is td.MessageDocument) {
      final d = item.message.content as td.MessageDocument;
      fileId = d.document.document.id;
      epTitle = d.document.fileName;
    }

    return Card(
      color: const Color(0xFF1C1C1E),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.hardEdge,
          child: TdThumbnail(file: item.posterFile, width: 50, height: 70),
        ),
        title: Text(
          item.seriesName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Episode ${item.episodeIndex + 1}',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        trailing: fileId != null
            ? IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.orange, size: 28),
                onPressed: () {
                  ref.read(pipControllerProvider.notifier).playVideo(
                    context,
                    messageId: item.message.id,
                    videoFileId: fileId!,
                    videoTitle: '${item.seriesName} - $epTitle',
                    episodeList: item.series.seasons.first.episodes,
                    currentEpisodeIndex: item.episodeIndex,
                    seriesName: item.seriesName,
                  );
                },
              )
            : null,
      ),
    );
  }
}

class _UpdateItem {
  final String seriesName;
  final int episodeIndex;
  final td.Message message;
  final td.File? posterFile;
  final AnimeSeries series;

  _UpdateItem({
    required this.seriesName,
    required this.episodeIndex,
    required this.message,
    required this.posterFile,
    required this.series,
  });
}
