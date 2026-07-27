import 'package:flutter/material.dart';
import '../../../models/episode.dart';
import '../../../models/video_source.dart';

class QualityPickerSheet extends StatelessWidget {
  final Episode episode;
  final VideoSource currentSource;
  final ValueChanged<VideoSource> onSourceSelected;

  const QualityPickerSheet({
    super.key,
    required this.episode,
    required this.currentSource,
    required this.onSourceSelected,
  });

  @override
  
  static Future<VideoSource?> showSheet(BuildContext context, Episode episode, String fileTitle, {VideoSource? currentSource}) {
    if (Theme.of(context).platform == TargetPlatform.windows || Theme.of(context).platform == TargetPlatform.linux || Theme.of(context).platform == TargetPlatform.macOS) {
      return showDialog<VideoSource>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: QualityPickerSheet(episode: episode, currentSource: currentSource ?? episode.sources.first, onSourceSelected: (s) => Navigator.pop(context, s)),
          ),
        ),
      );
    }

    return showModalBottomSheet<VideoSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => QualityPickerSheet(episode: episode, currentSource: currentSource ?? episode.sources.first, onSourceSelected: (s) => Navigator.pop(context, s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedSources = List<VideoSource>.from(episode.sources);
    sortedSources.sort((a, b) {
      final hA = a.metadata?.height ?? 0;
      final hB = b.metadata?.height ?? 0;
      if (hA != hB) {
        return hB.compareTo(hA);
      }
      return (b.fileSizeBytes ?? 0).compareTo(a.fileSizeBytes ?? 0);
    });

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select Quality',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedSources.length,
              itemBuilder: (context, index) {
                final source = sortedSources[index];
                final isSelected = source.messageId == currentSource.messageId;
                
                String label = (source.metadata?.height ?? 0) > 0 ? '${source.metadata!.height}p' : source.qualityLabel;
                if (source.fileSizeBytes != null && source.fileSizeBytes! > 0) {
                  final sizeMb = source.fileSizeBytes! / (1024 * 1024);
                  label += ' (${sizeMb.toStringAsFixed(1)} MB)';
                }

                return ListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected 
                    ? Icon(Icons.check, color: theme.colorScheme.primary) 
                    : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      onSourceSelected(source);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
