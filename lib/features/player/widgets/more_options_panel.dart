import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/src/player/native/player/native_player.dart'
    show NativePlayer;
import '../unified_player_controller.dart';

class MoreOptionsPanel extends StatelessWidget {
  final UnifiedPlayerController controller;
  final Widget? quickActionRow;
  final VoidCallback? onClose;
  final void Function(String message)? onShowToast;
  final VoidCallback? onLoopChanged;
  final bool isLooping;

  const MoreOptionsPanel({
    super.key,
    required this.controller,
    this.quickActionRow,
    this.onClose,
    this.onShowToast,
    this.onLoopChanged,
    this.isLooping = false,
  });

  NativePlayer? get _mpv {
    final p = controller.mediaKitPlayer;
    if (p == null) return null;
    return p.platform as NativePlayer?;
  }

  @override
  Widget build(BuildContext context) {
    final mpv = _mpv;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (quickActionRow != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: quickActionRow!,
          ),
          const Divider(),
        ],

        ListTile(
          leading: const Icon(Icons.loop),
          title: const Text('Loop'),
          trailing: Switch(
            value: isLooping,
            onChanged: (_) => onLoopChanged?.call(),
          ),
        ),

        if (mpv != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Advanced (media_kit only)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage),
            title: const Text('Cache Size'),
            subtitle: const Text('Demuxer cache in seconds'),
            onTap: () => _showCacheDialog(context, mpv),
          ),
        ],

        if (onClose != null)
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Close'),
            onTap: onClose,
          ),
      ],
    );
  }

  void _showCacheDialog(BuildContext context, NativePlayer mpv) {
    final ctl = TextEditingController(text: '120');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cache (seconds)'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 120'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final s = int.tryParse(ctl.text) ?? 120;
              mpv.setProperty('demuxer-max-bytes', f'{s * 1024 * 1024}');
              mpv.setProperty('demuxer-max-back-bytes', f'{s * 512 * 1024}');
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}