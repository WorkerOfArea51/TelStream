import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/subtitle_downloader_service.dart';

class SubtitleDownloaderDialog extends ConsumerStatefulWidget {
  final Player player;
  final String defaultQuery;

  const SubtitleDownloaderDialog({
    super.key,
    required this.player,
    required this.defaultQuery,
  });

  static void show(BuildContext context, {required Player player, required String defaultQuery}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SubtitleDownloaderDialog(
          player: player,
          defaultQuery: defaultQuery,
        );
      },
    );
  }

  @override
  ConsumerState<SubtitleDownloaderDialog> createState() => _SubtitleDownloaderDialogState();
}

class _SubtitleDownloaderDialogState extends ConsumerState<SubtitleDownloaderDialog> {
  late TextEditingController _queryController;
  String _selectedLangCode = 'eng';
  List<SubtitleMatch> _searchResults = [];
  bool _isSearching = false;
  String? _downloadingId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String cleanedQuery = widget.defaultQuery;
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'[-\s:]+\s*(Season\s+\d+|S\d+)', caseSensitive: false), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'\.(mkv|mp4|avi|mov|webm)$', caseSensitive: false), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'[\s\-:]+$'), '');
    cleanedQuery = cleanedQuery.replaceAll(RegExp(r'\s+'), ' ').trim();

    _queryController = TextEditingController(text: cleanedQuery);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    final downloader = ref.read(subtitleDownloaderServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Online Subtitle Downloader',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          
          // Search Controls Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search query...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedLangCode,
                dropdownColor: Colors.black,
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'eng', child: Text('English')),
                  DropdownMenuItem(value: 'spa', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fre', child: Text('French')),
                  DropdownMenuItem(value: 'ger', child: Text('German')),
                  DropdownMenuItem(value: 'ind', child: Text('Indonesian')),
                  DropdownMenuItem(value: 'ara', child: Text('Arabic')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLangCode = val);
                  }
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSearching
                    ? null
                    : () async {
                        setState(() {
                          _isSearching = true;
                          _searchResults = [];
                          _errorMessage = null;
                        });
                        try {
                          final res = await downloader.searchSubtitles(
                            _queryController.text.trim(),
                            lang: _selectedLangCode,
                          );
                          setState(() {
                            _isSearching = false;
                            _searchResults = res;
                          });
                        } catch (e) {
                          setState(() {
                            _isSearching = false;
                            _errorMessage = e.toString().replaceAll('HttpException:', '').replaceAll('Exception:', '').trim();
                          });
                        }
                      },
                child: const Icon(Icons.search, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Results list
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry Search', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'Search for subtitles to display results',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final sub = _searchResults[index];
                              final isDownloading = _downloadingId == sub.id;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: ListTile(
                                  title: Text(
                                    sub.fileName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    sub.language,
                                    style: TextStyle(color: settingsAccent, fontSize: 11),
                                  ),
                                  trailing: isDownloading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.orange,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.download_rounded, color: Colors.white70),
                                  onTap: isDownloading
                                      ? null
                                      : () async {
                                          setState(() {
                                            _downloadingId = sub.id;
                                            _errorMessage = null;
                                          });
                                          try {
                                            final path = await downloader.downloadSubtitle(
                                              sub.downloadUrl,
                                              sub.fileName,
                                              subtitleId: sub.id,
                                            );
                                            if (path != null) {
                                              widget.player.setSubtitleTrack(SubtitleTrack.uri(path));
                                              if (context.mounted) {
                                                Navigator.pop(context); // Close panel
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Subtitle loaded successfully: ${sub.fileName}'),
                                                    backgroundColor: Colors.green,
                                                    duration: const Duration(seconds: 3),
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            setState(() {
                                              _downloadingId = null;
                                              _errorMessage = e.toString().replaceAll('HttpException:', '').replaceAll('Exception:', '').trim();
                                            });
                                          }
                                        },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
