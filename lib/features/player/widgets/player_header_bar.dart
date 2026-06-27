import 'package:flutter/material.dart';

class PlayerHeaderBar extends StatelessWidget {
  final String videoTitle;
  final VoidCallback onBack;
  final int? sleepTimerSecondsRemaining;
  final String Function(int) formatSleepTimeRemaining;
  final String decoderModeLabel;
  final VoidCallback onToggleDecoderMode;
  final VoidCallback onShowSubtitles;
  final VoidCallback onShowAudioTracks;
  final VoidCallback onShowQueue;
  final Widget quickActionRow;
  final Color settingsAccent;

  const PlayerHeaderBar({
    super.key,
    required this.videoTitle,
    required this.onBack,
    required this.sleepTimerSecondsRemaining,
    required this.formatSleepTimeRemaining,
    required this.decoderModeLabel,
    required this.onToggleDecoderMode,
    required this.onShowSubtitles,
    required this.onShowAudioTracks,
    required this.onShowQueue,
    required this.quickActionRow,
    required this.settingsAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                videoTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sleepTimerSecondsRemaining != null)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Text(
                  formatSleepTimeRemaining(sleepTimerSecondsRemaining!),
                  style: TextStyle(
                    color: settingsAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: InkWell(
                onTap: onToggleDecoderMode,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    decoderModeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.closed_caption_outlined, color: Colors.white),
              onPressed: onShowSubtitles,
            ),
            IconButton(
              icon: const Icon(Icons.music_note_outlined, color: Colors.white),
              onPressed: onShowAudioTracks,
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play_outlined, color: Colors.white),
              onPressed: onShowQueue,
            ),
          ],
        ),
        quickActionRow,
      ],
    );
  }
}
