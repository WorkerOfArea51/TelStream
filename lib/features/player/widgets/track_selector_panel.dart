import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class TrackSelectorPanel extends StatelessWidget {
  final Player player;
  final bool isSubtitle;
  final Map<String, String> trackCodecs;
  final ValueChanged<dynamic> onTrackSelected;
  final VoidCallback onPickLocalSubtitle;
  final VoidCallback onOpenSubtitleDownloader;
  final VoidCallback onClose;

  const TrackSelectorPanel({
    super.key,
    required this.player,
    required this.isSubtitle,
    required this.trackCodecs,
    required this.onTrackSelected,
    required this.onPickLocalSubtitle,
    required this.onOpenSubtitleDownloader,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StreamBuilder<Tracks>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (context, tracksSnapshot) {
        return StreamBuilder<Track>(
          stream: player.stream.track,
          initialData: player.state.track,
          builder: (context, trackSnapshot) {
            final tracksObj = tracksSnapshot.data;
            final currentTrackObj = trackSnapshot.data;
            
            final List<dynamic> rawTracks = isSubtitle
                ? (tracksObj?.subtitle ?? [])
                : (tracksObj?.audio ?? []);
            final currentTrack = isSubtitle
                ? currentTrackObj?.subtitle
                : currentTrackObj?.audio;
            
            final List<dynamic> options = [];
            if (isSubtitle) {
              options.add(SubtitleTrack.no());
              options.add(SubtitleTrack.auto());
            } else {
              options.add(AudioTrack.auto());
            }
            
            for (final track in rawTracks) {
              if (track.id != 'no' && track.id != 'auto') {
                options.add(track);
              }
            }
            
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                child: Container(
                  height: 340,
                  decoration: BoxDecoration(
                    color: const Color(0xE60F172A), // Slate 900 with 90% opacity
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 45,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                isSubtitle ? Icons.subtitles : Icons.headphones,
                                color: settingsAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isSubtitle ? 'Subtitles' : 'Audio Tracks',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (isSubtitle) ...[
                                IconButton(
                                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                                  tooltip: 'Download Subtitles Online',
                                  onPressed: onOpenSubtitleDownloader,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.folder_open, color: Colors.white),
                                  tooltip: 'Load Local Subtitle File',
                                  onPressed: onPickLocalSubtitle,
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white60),
                                onPressed: onClose,
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: options.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No tracks available',
                                    style: TextStyle(color: Colors.white38, fontSize: 15),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final track = options[index];
                                    final isSelected = currentTrack != null &&
                                        track.id == currentTrack.id &&
                                        track.title == currentTrack.title &&
                                        track.language == currentTrack.language;
                                    
                                    Widget titleWidget;
                                    Widget? leadingWidget;
                                    
                                    if (track.id == 'auto') {
                                      leadingWidget = Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? settingsAccent.withValues(alpha: 0.2) : Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.autorenew,
                                          color: isSelected ? settingsAccent : Colors.white70,
                                          size: 18,
                                        ),
                                      );
                                      titleWidget = const Text(
                                        'Automatic Select',
                                        style: TextStyle(fontSize: 15),
                                      );
                                    } else if (track.id == 'no') {
                                      leadingWidget = Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.block,
                                          color: isSelected ? Colors.redAccent : Colors.white70,
                                          size: 18,
                                        ),
                                      );
                                      titleWidget = const Text(
                                        'Disable (None)',
                                        style: TextStyle(fontSize: 15),
                                      );
                                    } else {
                                      final lang = (track.language ?? '').toUpperCase();
                                      final tTitle = track.title ?? 'Track ${track.id}';
                                      
                                      final typeKey = isSubtitle ? 'sub' : 'audio';
                                      final codec = trackCodecs['$typeKey/${track.id}'];
                                      String formatSuffix = '';
                                      if (codec != null && codec.isNotEmpty) {
                                        var cleanCodec = codec.toUpperCase();
                                        if (cleanCodec == 'SUBRIP' || cleanCodec.contains('S_TEXT') || cleanCodec.contains('UTF8') || cleanCodec.contains('UTF-8')) {
                                          cleanCodec = 'SRT';
                                        } else if (cleanCodec.contains('PGS') || cleanCodec.contains('HDMV')) {
                                          cleanCodec = 'PGS';
                                        } else if (cleanCodec.contains('ASS') || cleanCodec.contains('SSA') || cleanCodec.contains('SUBSTATION')) {
                                          cleanCodec = 'ASS';
                                        } else if (cleanCodec.contains('VOB') || cleanCodec.contains('DVD')) {
                                          cleanCodec = 'SUB';
                                        } else if (cleanCodec.contains('VTT')) {
                                          cleanCodec = 'VTT';
                                        }
                                        formatSuffix = ' ($cleanCodec)';
                                      }
                                      final displayTitle = '$tTitle$formatSuffix';
                                      
                                      if (lang.isNotEmpty) {
                                        leadingWidget = Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected ? settingsAccent.withValues(alpha: 0.2) : Colors.white10,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? settingsAccent.withValues(alpha: 0.4) : Colors.white24,
                                            ),
                                          ),
                                          child: Text(
                                            lang,
                                            style: TextStyle(
                                              color: isSelected ? settingsAccent : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      titleWidget = Text(
                                        displayTitle,
                                        style: const TextStyle(fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => onTrackSelected(track),
                                        borderRadius: BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? settingsAccent.withValues(alpha: 0.12) 
                                                : Colors.white.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? settingsAccent.withValues(alpha: 0.4) 
                                                  : Colors.white.withValues(alpha: 0.05),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (leadingWidget != null) ...[
                                                leadingWidget,
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: DefaultTextStyle(
                                                  style: TextStyle(
                                                    color: isSelected ? settingsAccent : Colors.white,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                  child: titleWidget,
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check_circle,
                                                  color: settingsAccent,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
