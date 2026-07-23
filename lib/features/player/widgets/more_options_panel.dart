import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../settings/settings_provider.dart';
import '../../../core/theme/app_theme.dart';

class MoreOptionsPanel extends ConsumerWidget {
  final Player player;
  final Widget quickActionRow;
  final VoidCallback onClose;
  final Function(String) onShowToast;

  const MoreOptionsPanel({
    super.key,
    required this.player,
    required this.quickActionRow,
    required this.onClose,
    required this.onShowToast,
  });

  void _setRepeatMode(WidgetRef ref, int index) {
    final settings = ref.read(videoSettingsProvider);
    switch (index) {
      case 0: // Order
        player.setPlaylistMode(PlaylistMode.none);
        player.setShuffle(false);
        ref
            .read(videoSettingsProvider.notifier)
            .updateSettings(settings.copyWith(autoplayNextVideo: true));
        onShowToast('Repeat Mode: Order');
        break;
      case 1: // Repeat One
        player.setPlaylistMode(PlaylistMode.single);
        player.setShuffle(false);
        ref
            .read(videoSettingsProvider.notifier)
            .updateSettings(settings.copyWith(autoplayNextVideo: true));
        onShowToast('Repeat Mode: Repeat One');
        break;
      case 2: // Shuffle
        player.setPlaylistMode(PlaylistMode.none);
        player.setShuffle(true);
        ref
            .read(videoSettingsProvider.notifier)
            .updateSettings(settings.copyWith(autoplayNextVideo: true));
        onShowToast('Repeat Mode: Shuffle');
        break;
      case 3: // Repeat All
        player.setPlaylistMode(PlaylistMode.loop);
        player.setShuffle(false);
        ref
            .read(videoSettingsProvider.notifier)
            .updateSettings(settings.copyWith(autoplayNextVideo: true));
        onShowToast('Repeat Mode: Repeat All');
        break;
      case 4: // Single Play (Stop after current)
        player.setPlaylistMode(PlaylistMode.none);
        player.setShuffle(false);
        ref
            .read(videoSettingsProvider.notifier)
            .updateSettings(settings.copyWith(autoplayNextVideo: false));
        onShowToast('Repeat Mode: Single Play');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StreamBuilder<PlaylistMode>(
      stream: player.stream.playlistMode,
      initialData: player.state.playlistMode,
      builder: (context, modeSnapshot) {
        return StreamBuilder<bool>(
          stream: player.stream.shuffle,
          initialData: player.state.shuffle,
          builder: (context, shuffleSnapshot) {
            final mode = modeSnapshot.data ?? PlaylistMode.none;
            final shuffle = shuffleSnapshot.data ?? false;
            final bool autoplayNext =
                ref.watch(videoSettingsProvider).autoplayNextVideo;

            int activeIdx = 0;
            String modeLabel = 'Order';
            if (shuffle) {
              activeIdx = 2;
              modeLabel = 'Shuffle';
            } else if (mode == PlaylistMode.single) {
              activeIdx = 1;
              modeLabel = 'Repeat One';
            } else if (mode == PlaylistMode.loop) {
              activeIdx = 3;
              modeLabel = 'Repeat All';
            } else if (!autoplayNext) {
              activeIdx = 4;
              modeLabel = 'Single Play';
            } else {
              activeIdx = 0;
              modeLabel = 'Order';
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: isLandscape ? double.infinity : screenHeight * 0.85,
              ),
              height: isLandscape ? double.infinity : null,
              decoration: BoxDecoration(
                color: const Color(
                  0xEB0A0F1D,
                ), // Slate 950 with 92% opacity - clean translucency (no blur)
                borderRadius: isLandscape
                    ? const BorderRadius.horizontal(left: Radius.circular(30))
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                child: Column(
                  mainAxisSize:
                      isLandscape ? MainAxisSize.max : MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: onClose,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Play option',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            quickActionRow,
                            const SizedBox(height: 16),
                            // Repeat Mode Selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Repeat Mode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  modeLabel,
                                  style: TextStyle(
                                    color: settingsAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: List.generate(5, (index) {
                                  IconData ic;
                                  switch (index) {
                                    case 0:
                                      ic = Icons.swap_calls_outlined; // Sequence/Order
                                      break;
                                    case 1:
                                      ic = Icons.repeat_one_rounded; // Repeat One
                                      break;
                                    case 2:
                                      ic = Icons.shuffle_rounded; // Shuffle
                                      break;
                                    case 3:
                                      ic = Icons.repeat_rounded; // Repeat All
                                      break;
                                    case 4:
                                      ic = Icons.play_disabled_rounded; // Single Play
                                      break;
                                    default:
                                      ic = Icons.trending_flat_rounded;
                                  }
                                  final isSelected = activeIdx == index;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => _setRepeatMode(ref, index),
                                      behavior: HitTestBehavior.opaque,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? settingsAccent
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            ic,
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
