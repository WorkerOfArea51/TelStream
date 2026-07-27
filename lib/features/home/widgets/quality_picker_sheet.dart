import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;

import '../../../models/episode.dart';
import '../../../models/video_source.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/title_normalizer.dart';

class QualityPickerSheet extends ConsumerWidget {
  final Episode episode;
  final String title;

  const QualityPickerSheet({
    super.key,
    required this.episode,
    required this.title,
  });

  static Future<VideoSource?> show(BuildContext context, Episode episode, String title) {
    if (Theme.of(context).platform == TargetPlatform.windows || Theme.of(context).platform == TargetPlatform.linux || Theme.of(context).platform == TargetPlatform.macOS) {
      return showDialog<VideoSource>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: QualityPickerSheet(episode: episode, title: title),
          ),
        ),
      );
    }

    return showModalBottomSheet<VideoSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => QualityPickerSheet(episode: episode, title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDesktop = theme.platform == TargetPlatform.windows || theme.platform == TargetPlatform.linux || theme.platform == TargetPlatform.macOS;

    // Sort sources: highest resolution first, then by size
    final sortedSources = List<VideoSource>.from(episode.sources)
      ..sort((a, b) {
        if (b.height != a.height) return b.height.compareTo(a.height);
        
        final sizeA = _getSize(a.message);
        final sizeB = _getSize(b.message);
        return sizeB.compareTo(sizeA);
      });

    Widget content = Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: isDesktop ? BorderRadius.circular(16) : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDesktop)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.high_quality, color: settingsAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Quality',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedSources.length,
              itemBuilder: (context, index) {
                final source = sortedSources[index];
                final sizeMb = (_getSize(source.message) / 1024 / 1024).toStringAsFixed(1);
                
                String qualityText = source.width > 0 ? '${source.height}p' : source.qualityLabel;
                if (qualityText.isEmpty) qualityText = 'Unknown Quality';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: settingsAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: settingsAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      qualityText,
                      style: TextStyle(
                        color: settingsAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${TitleNormalizer.getMessageFileName(source.message).split('.').last.toUpperCase()} Video',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('$sizeMb MB'),
                  trailing: Icon(Icons.download_rounded, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
                  onTap: () {
                    Navigator.of(context).pop(source);
                  },
                );
              },
            ),
          ),
          if (isDesktop) const SizedBox(height: 16) else SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );

    return content;
  }

  int _getSize(td.Message msg) {
    if (msg.content is td.MessageVideo) {
      return (msg.content as td.MessageVideo).video.video.expectedSize;
    } else if (msg.content is td.MessageDocument) {
      return (msg.content as td.MessageDocument).document.document.expectedSize;
    }
    return 0;
  }
}
