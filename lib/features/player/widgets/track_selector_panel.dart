import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class TrackSelectorPanel extends StatelessWidget {
  final Player player;
  final bool isSubtitle;
  final Map<String, String> trackCodecs;
  final String currentRendererMode;
  final ValueChanged<String> onRendererModeChanged;
  final double currentSubtitleDelay;
  final ValueChanged<double> onSubtitleDelayChanged;
  final ValueChanged<dynamic> onTrackSelected;
  final VoidCallback onPickLocalSubtitle;
  final VoidCallback onOpenSubtitleDownloader;
  final VoidCallback onClose;

  const TrackSelectorPanel({
    super.key,
    required this.player,
    required this.isSubtitle,
    required this.trackCodecs,
    required this.currentRendererMode,
    required this.onRendererModeChanged,
    required this.currentSubtitleDelay,
    required this.onSubtitleDelayChanged,
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
                  height: isSubtitle ? 420.0 : 340.0,
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
                        if (isSubtitle) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Row(
                              children: [
                                const Text(
                                  'Renderer:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildModeButton('auto', 'Smart Auto', currentRendererMode, settingsAccent),
                                      const SizedBox(width: 6),
                                      _buildModeButton('flutter', 'Overlay', currentRendererMode, settingsAccent),
                                      const SizedBox(width: 6),
                                      _buildModeButton('native', 'Native', currentRendererMode, settingsAccent),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
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
                                      final rawLang = track.language ?? '';
                                      final lang = _getLanguageName(rawLang);
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
                                      
                                      if (rawLang.isNotEmpty) {
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
                        if (isSubtitle) ...[
                          const Divider(color: Colors.white10, height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtitle Delay Sync:',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${currentSubtitleDelay > 0 ? '+' : ''}${currentSubtitleDelay.toStringAsFixed(1)}s',
                                          style: TextStyle(
                                            color: settingsAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => onSubtitleDelayChanged(0.0),
                                          child: Text(
                                            'Reset',
                                            style: TextStyle(
                                              color: settingsAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: currentSubtitleDelay.clamp(-5.0, 5.0),
                                    min: -5.0,
                                    max: 5.0,
                                    divisions: 100, // 0.1s increments
                                    activeColor: settingsAccent,
                                    inactiveColor: Colors.white24,
                                    onChanged: onSubtitleDelayChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  String _getLanguageName(String code) {
    final cleanCode = code.toLowerCase().trim();
    switch (cleanCode) {
      case 'eng':
      case 'en':
        return 'English';
      case 'jpn':
      case 'ja':
        return 'Japanese';
      case 'zho':
      case 'chi':
      case 'zh':
        return 'Chinese';
      case 'spa':
      case 'es':
        return 'Spanish';
      case 'fra':
      case 'fre':
      case 'fr':
        return 'French';
      case 'deu':
      case 'ger':
      case 'de':
        return 'German';
      case 'rus':
      case 'ru':
        return 'Russian';
      case 'kor':
      case 'ko':
        return 'Korean';
      case 'ita':
      case 'it':
        return 'Italian';
      case 'por':
      case 'pt':
        return 'Portuguese';
      case 'ind':
      case 'id':
        return 'Indonesian';
      case 'vie':
      case 'vi':
        return 'Vietnamese';
      case 'ara':
      case 'ar':
        return 'Arabic';
      case 'hin':
      case 'hi':
        return 'Hindi';
      case 'ben':
      case 'bn':
        return 'Bengali';
      default:
        return code.toUpperCase();
    }
  }

  Widget _buildModeButton(String mode, String label, String currentMode, Color activeColor) {
    final isSelected = mode == currentMode;
    return Expanded(
      child: InkWell(
        onTap: () => onRendererModeChanged(mode),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white10,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
