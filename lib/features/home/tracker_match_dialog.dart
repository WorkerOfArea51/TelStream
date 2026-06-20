import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../services/tracker_service.dart';
import '../../core/theme/app_theme.dart';

class TrackerMatchDialog extends ConsumerStatefulWidget {
  final String seriesName;

  const TrackerMatchDialog({
    super.key,
    required this.seriesName,
  });

  @override
  ConsumerState<TrackerMatchDialog> createState() => _TrackerMatchDialogState();
}

class _TrackerMatchDialogState extends ConsumerState<TrackerMatchDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualIdController = TextEditingController();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.text = widget.seriesName;
    _tabController.addListener(_handleTabChange);
    _loadCurrentManualId();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {
      _searchResults = [];
      _errorMessage = null;
    });
    _loadCurrentManualId();
  }

  String _getTrackerType() {
    switch (_tabController.index) {
      case 0:
        return 'anilist';
      case 1:
        return 'mal';
      case 2:
      default:
        return 'trakt';
    }
  }

  void _loadCurrentManualId() {
    final storage = ref.read(storageServiceProvider);
    final type = _getTrackerType();
    String currentId = '';
    
    if (type == 'anilist') {
      currentId = storage.getAnilistIdForSeries(widget.seriesName)?.toString() ?? '';
    } else if (type == 'mal') {
      currentId = storage.getMalIdForSeries(widget.seriesName)?.toString() ?? '';
    } else {
      currentId = storage.getTraktIdForSeries(widget.seriesName) ?? '';
    }
    
    _manualIdController.text = currentId;
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _errorMessage = null;
    });

    try {
      final trackerService = ref.read(trackerServiceProvider);
      final type = _getTrackerType();
      List<Map<String, dynamic>> results = [];

      if (type == 'anilist') {
        results = await trackerService.searchAnilistList(query);
      } else if (type == 'mal') {
        results = await trackerService.searchMalList(query);
      } else {
        results = await trackerService.searchTraktList(query);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkMedia(dynamic id, String title) async {
    final storage = ref.read(storageServiceProvider);
    final type = _getTrackerType();

    try {
      if (type == 'anilist') {
        final intId = id is int ? id : int.tryParse(id.toString()) ?? 0;
        await storage.setAnilistIdForSeries(widget.seriesName, intId);
      } else if (type == 'mal') {
        final intId = id is int ? id : int.tryParse(id.toString()) ?? 0;
        await storage.setMalIdForSeries(widget.seriesName, intId);
      } else {
        await storage.setTraktIdForSeries(widget.seriesName, id.toString());
      }

      _loadCurrentManualId();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Linked to $title successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _unlinkMedia() async {
    final storage = ref.read(storageServiceProvider);
    final type = _getTrackerType();

    try {
      await storage.unlinkTrackerForSeries(widget.seriesName, type);
      _loadCurrentManualId();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unlinked tracker successfully!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlink: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveManualId() async {
    final manualVal = _manualIdController.text.trim();
    if (manualVal.isEmpty) {
      await _unlinkMedia();
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final type = _getTrackerType();

    try {
      if (type == 'anilist') {
        final intId = int.tryParse(manualVal);
        if (intId == null) throw const FormatException('AniList ID must be an integer');
        await storage.setAnilistIdForSeries(widget.seriesName, intId);
      } else if (type == 'mal') {
        final intId = int.tryParse(manualVal);
        if (intId == null) throw const FormatException('MAL ID must be an integer');
        await storage.setMalIdForSeries(widget.seriesName, intId);
      } else {
        await storage.setTraktIdForSeries(widget.seriesName, manualVal);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linked manual ID successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid ID format: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 45,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.link, color: settingsAccent, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Tracker Matcher',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: settingsAccent,
            labelColor: settingsAccent,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
            tabs: const [
              Tab(text: 'AniList'),
              Tab(text: 'MyAnimeList'),
              Tab(text: 'Trakt.tv'),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Link Status Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualIdController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Active Link ID',
                              labelStyle: TextStyle(color: settingsAccent, fontSize: 13),
                              hintText: 'No linked ID (Auto-search)',
                              hintStyle: const TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_manualIdController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.link_off, color: Colors.orangeAccent),
                            tooltip: 'Unlink Tracker',
                            onPressed: _unlinkMedia,
                          ),
                        IconButton(
                          icon: const Icon(Icons.save_rounded, color: Colors.green),
                          tooltip: 'Save Manual ID',
                          onPressed: _saveManualId,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search title...',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: settingsAccent, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: settingsAccent,
                          foregroundColor: settingsAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _performSearch,
                        child: const Icon(Icons.search, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Results List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                            ? Center(child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)))
                            : _searchResults.isEmpty
                                ? Center(
                                    child: Text(
                                      'Search for a title to match manually',
                                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
                                      final isCurrentlyLinked = _manualIdController.text == item['id'].toString();
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: isCurrentlyLinked ? settingsAccent.withValues(alpha: 0.08) : theme.cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrentlyLinked ? settingsAccent.withValues(alpha: 0.3) : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            item['title'].toString(),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'ID: ${item['id']}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          trailing: isCurrentlyLinked
                                              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                              : Icon(Icons.link, color: settingsAccent, size: 20),
                                          onTap: () => _linkMedia(item['id'], item['title'].toString()),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
