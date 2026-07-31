import '../../../services/metadata_extraction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/episode.dart';
import '../../../models/video_source.dart';
import '../../../services/video_metadata_cache.dart';

enum QualityPickerAction { play, download, cancel }

class QualityPickerResult {
  final VideoSource? source;
  final QualityPickerAction action;

  QualityPickerResult({this.source, required this.action});
}

class QualityPickerSheet extends ConsumerStatefulWidget {
  final Episode episode;
  final String title;
  final VideoSource? currentSource;

  const QualityPickerSheet({
    super.key,
    required this.episode,
    required this.title,
    this.currentSource,
  });

  static Future<QualityPickerResult?> showSheet(
    BuildContext context,
    Episode episode,
    String title, {
    VideoSource? currentSource,
  }) {
    return showModalBottomSheet<QualityPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QualityPickerSheet(
        episode: episode,
        title: title,
        currentSource: currentSource,
      ),
    );
  }

  @override
  ConsumerState<QualityPickerSheet> createState() => _QualityPickerSheetState();
}

class _QualityPickerSheetState extends ConsumerState<QualityPickerSheet> {
  VideoSource? _selectedSource;
  bool _isAuto = true;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double d = bytes.toDouble();
    while (d > 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.currentSource;
    _isAuto = widget.currentSource == null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = widget.episode.sources;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Select Quality',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () async {
                  for (final s in sources) {
                    await VideoMetadataCache.clearForMessage(s.messageId);
                  }
                  // Fire re-extraction immediately — don't make the user scroll.
                  ref.read(metadataExtractionServiceProvider.notifier)
                      .extractMetadataForEpisode(widget.episode);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared. Re-extracting metadata...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context, QualityPickerResult(action: QualityPickerAction.cancel));
                  }
                },
                tooltip: 'Clear Metadata Cache',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.pop(context, QualityPickerResult(action: QualityPickerAction.cancel)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withAlpha(178),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildQualityOption(
                    title: 'Auto',
                    subtitle: 'Automatically select best quality',
                    isSelected: _isAuto,
                    onTap: () {
                      Navigator.pop(context, QualityPickerResult(
                        action: QualityPickerAction.play,
                        source: null,
                      ));
                    },
                  ),
                  const SizedBox(height: 8),
                  ...sources.map((source) {
                    final isSelected = !_isAuto && _selectedSource?.messageId == source.messageId;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildQualityOption(
                        title: source.qualityLabel,
                        subtitle: _formatBytes(source.fileSizeBytes),
                        isSelected: isSelected,
                        onTap: () {
                          Navigator.pop(context, QualityPickerResult(
                            action: QualityPickerAction.play,
                            source: source,
                          ));
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, QualityPickerResult(
                      action: QualityPickerAction.download,
                      source: _isAuto ? widget.episode.defaultSource : _selectedSource,
                    ));
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white12 : Colors.black12),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected 
                ? theme.colorScheme.primary.withAlpha(25) 
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected 
                              ? theme.colorScheme.primary.withAlpha(204)
                              : theme.textTheme.bodySmall?.color?.withAlpha(178),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
