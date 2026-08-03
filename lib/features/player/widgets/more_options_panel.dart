import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../unified_player_controller.dart';

/// Shows engine-specific advanced options.
///
/// mpv-only options (hwdec, cache, audio-delay) are hidden when the active
/// engine is not media_kit. Engine-agnostic options (speed, loop) are always
/// shown.
class MoreOptionsPanel extends StatelessWidget {
  final UnifiedPlayerController controller;
  final Widget? quickActionRow;
  final VoidCallback? onClose;
  final void Function(String message)? onShowToast;
  final void Function(double speed)? onSpeedChanged;
  final void Function(bool loop)? onLoopChanged;

  const MoreOptionsPanel({
    super.key,
    required this.controller,
    this.quickActionRow,
    this.onClose,
    this.onShowToast,
    this.onSpeedChanged,
    this.onLoopChanged,
  });

  /// Returns the NativePlayer when the active engine is media_kit, else null.
  /// All mpv-specific options gate on this and bail out gracefully when null.
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

        // ─── Engine-agnostic options ──────────────────────────────
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Playback Speed'),
          subtitle: Text('${controller.state.rate.toStringAsFixed(2)}x'),
          onTap: () => _showSpeedDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.loop),
          title: const Text('Loop'),
          trailing: Switch(
            value: false,
            onChanged: (v) => onLoopChanged?.call(v),
          ),
        ),

        // ─── media_kit-only options ───────────────────────────────
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
            leading: const Icon(Icons.memory),
            title: const Text('Hardware Decoder'),
            subtitle: const Text('mediacodec / mediacodec-copy / no'),
            onTap: () => _showHwdecDialog(context, mpv),
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: const Text('Audio Sync Offset'),
            subtitle: const Text('Adjust audio delay (ms)'),
            onTap: () => _showAudioSyncDialog(context, mpv),
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

  // ─── Engine-agnostic dialogs ────────────────────────────────────
  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Playback Speed'),
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
          return SimpleDialogOption(
            child: Text('${s}x'),
            onPressed: () {
              Navigator.pop(context);
              onSpeedChanged?.call(s);
            },
          );
        }).toList(),
      ),
    );
  }

  // ─── media_kit-only dialogs ─────────────────────────────────────
  // Each receives a non-null NativePlayer, so no nullable access inside
  // the closure body — this is what eliminates the "mkPlayer undefined"
  // class of errors at the source.
  void _showHwdecDialog(BuildContext context, NativePlayer mpv) {
    const modes = ['mediacodec', 'mediacodec-copy', 'no'];
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Hardware Decoder'),
        children: modes.map((m) {
          return SimpleDialogOption(
            child: Text(m),
            onPressed: () {
              Navigator.pop(context);
              mpv.setProperty('hwdec', m);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showAudioSyncDialog(BuildContext context, NativePlayer mpv) {
    final ctl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Audio Sync (ms)'),
        content: TextField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(hintText: 'e.g. -250'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final ms = int.tryParse(ctl.text) ?? 0;
              mpv.setProperty('audio-delay', (ms / 1000).toString());
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
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
              mpv.setProperty('demuxer-max-bytes', '${s * 1024 * 1024}');
              mpv.setProperty('demuxer-max-back-bytes', '${s * 512 * 1024}');
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
