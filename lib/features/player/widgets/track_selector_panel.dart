import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import 'subtitle_styling_tab.dart';

class TrackSelectorPanel extends StatefulWidget {
  final Player player;
  final bool isSubtitle;
  final Map<String, String> trackCodecs;
  final String currentRendererMode;
  final ValueChanged<String> onRendererModeChanged;
  final String currentDecoderMode;
  final ValueChanged<String> onDecoderModeChanged;
  final double currentSubtitleDelay;
  final ValueChanged<double> onSubtitleDelayChanged;
  final ValueChanged<dynamic> onTrackSelected;
  final VoidCallback onPickLocalSubtitle;
  final VoidCallback onOpenSubtitleDownloader;
  final VoidCallback onClose;

  // Subtitle styling parameters
  final double currentFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final String currentFontColor;
  final ValueChanged<String> onFontColorChanged;
  final String currentFontFamily;
  final ValueChanged<String> onFontFamilyChanged;

  const TrackSelectorPanel({
    super.key,
    required this.player,
    required this.isSubtitle,
    required this.trackCodecs,
    required this.currentRendererMode,
    required this.onRendererModeChanged,
    required this.currentDecoderMode,
    required this.onDecoderModeChanged,
    required this.currentSubtitleDelay,
    required this.onSubtitleDelayChanged,
    required this.onTrackSelected,
    required this.onPickLocalSubtitle,
    required this.onOpenSubtitleDownloader,
    required this.onClose,
    required this.currentFontSize,
    required this.onFontSizeChanged,
    required this.currentFontColor,
    required this.onFontColorChanged,
    required this.currentFontFamily,
    required this.onFontFamilyChanged,
  });

  @override
  State<TrackSelectorPanel> createState() => _TrackSelectorPanelState();
}

class _TrackSelectorPanelState extends State<TrackSelectorPanel> {
  int _activeTab = 0; // 0: Tracks, 1: Style

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;

    return StreamBuilder<Tracks>(
      stream: widget.player.stream.tracks,
      initialData: widget.player.state.tracks,
      builder: (context, tracksSnapshot) {
        return StreamBuilder<Track>(
          stream: widget.player.stream.track,
          initialData: widget.player.state.track,
          builder: (context, trackSnapshot) {
            final tracksObj = tracksSnapshot.data;
            final currentTrackObj = trackSnapshot.data;
            
            final List<dynamic> rawTracks = widget.isSubtitle
                ? (tracksObj?.subtitle ?? [])
                : (tracksObj?.audio ?? []);
            final currentTrack = widget.isSubtitle
                ? currentTrackObj?.subtitle
                : currentTrackObj?.audio;
            
            final List<dynamic> options = [];
            if (widget.isSubtitle) {
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
            
            // Check if current track is ASS or PGS/Graphical to show recommended mode banners
            bool isAssCodecSelected = false;
            bool isGraphicalCodecSelected = false;
            if (widget.isSubtitle && currentTrack != null && currentTrack.id != 'no' && currentTrack.id != 'auto') {
              final codec = widget.trackCodecs['sub/${currentTrack.id}'];
              if (codec != null) {
                final codecLower = codec.toLowerCase();
                if (codecLower.contains('ass') || codecLower.contains('ssa') || codecLower.contains('substation')) {
                  isAssCodecSelected = true;
                } else if (codecLower.contains('pgs') || 
                           codecLower.contains('hdmv') || 
                           codecLower.contains('dvd') || 
                           codecLower.contains('vob') || 
                           codecLower.contains('dvb') || 
                           codecLower == 'xsub') {
                  isGraphicalCodecSelected = true;
                }
              }
            }

            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

            return ClipRRect(
              borderRadius: isLandscape
                  ? const BorderRadius.horizontal(left: Radius.circular(30))
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  height: isLandscape ? double.infinity : (widget.isSubtitle ? 500.0 : 340.0),
                  decoration: BoxDecoration(
                    color: const Color(0x990A0F1D), // Slate 950 with 60% opacity for premium glassmorphism
                    borderRadius: isLandscape
                        ? const BorderRadius.horizontal(left: Radius.circular(30))
                        : const BorderRadius.vertical(top: Radius.circular(24)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                widget.isSubtitle ? Icons.subtitles : Icons.headphones,
                                color: settingsAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.isSubtitle ? 'Subtitles' : 'Audio Tracks',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (widget.isSubtitle) ...[
                                IconButton(
                                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                                  tooltip: 'Download Subtitles Online',
                                  onPressed: widget.onOpenSubtitleDownloader,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.folder_open, color: Colors.white),
                                  tooltip: 'Load Local Subtitle File',
                                  onPressed: widget.onPickLocalSubtitle,
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white60),
                                onPressed: widget.onClose,
                              ),
                            ],
                          ),
                        ),
                        
                        // Dual tab switcher (Tracks vs Style)
                        if (widget.isSubtitle) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Row(
                              children: [
                                _buildTabButton(0, 'Tracks', settingsAccent),
                                const SizedBox(width: 12),
                                _buildTabButton(1, 'Style', settingsAccent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        
                        const Divider(color: Colors.white10, height: 1),
                        
                        // Body Section switching depending on active tab
                        if (widget.isSubtitle && _activeTab == 1)
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: SubtitleStylingTab(
                                currentFontSize: widget.currentFontSize,
                                onFontSizeChanged: widget.onFontSizeChanged,
                                currentFontColor: widget.currentFontColor,
                                onFontColorChanged: widget.onFontColorChanged,
                                currentFontFamily: widget.currentFontFamily,
                                onFontFamilyChanged: widget.onFontFamilyChanged,
                                currentRendererMode: widget.currentRendererMode,
                                settingsAccent: settingsAccent,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.isSubtitle) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Renderer Mode:',
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
                                              _buildModeButton('flutter', 'Overlay (Custom)', widget.currentRendererMode, settingsAccent),
                                              const SizedBox(width: 8),
                                              _buildModeButton('native', 'Native (Built-in)', widget.currentRendererMode, settingsAccent),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAssCodecSelected)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: widget.currentRendererMode == 'native' 
                                              ? settingsAccent.withValues(alpha: 0.1)
                                              : Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: widget.currentRendererMode == 'native'
                                                ? settingsAccent.withValues(alpha: 0.3)
                                                : Colors.orange.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              widget.currentRendererMode == 'native' ? Icons.info_outline : Icons.warning_amber_rounded, 
                                              color: widget.currentRendererMode == 'native' ? settingsAccent : Colors.orangeAccent, 
                                              size: 16
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.currentRendererMode == 'native'
                                                    ? 'Native mode selected. Subtitles will display styled ASS layout.'
                                                    : 'Selected subtitle has ASS format. Native mode is recommended.',
                                                style: TextStyle(
                                                  color: widget.currentRendererMode == 'native' ? Colors.white70 : Colors.orangeAccent, 
                                                  fontSize: 11, 
                                                  fontWeight: FontWeight.w500
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (isGraphicalCodecSelected)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: widget.currentRendererMode == 'flutter'
                                              ? Colors.redAccent.withValues(alpha: 0.1)
                                              : (widget.currentDecoderMode == 'mediacodec'
                                                  ? Colors.orange.withValues(alpha: 0.1)
                                                  : settingsAccent.withValues(alpha: 0.1)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: widget.currentRendererMode == 'flutter'
                                                ? Colors.redAccent.withValues(alpha: 0.3)
                                                : (widget.currentDecoderMode == 'mediacodec'
                                                    ? Colors.orange.withValues(alpha: 0.3)
                                                    : settingsAccent.withValues(alpha: 0.3)),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              widget.currentRendererMode == 'flutter'
                                                  ? Icons.error_outline
                                                  : (widget.currentDecoderMode == 'mediacodec'
                                                      ? Icons.warning_amber_rounded
                                                      : Icons.info_outline),
                                              color: widget.currentRendererMode == 'flutter'
                                                  ? Colors.redAccent
                                                  : (widget.currentDecoderMode == 'mediacodec'
                                                      ? Colors.orangeAccent
                                                      : settingsAccent),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.currentRendererMode == 'flutter'
                                                    ? 'PGS/VobSub subtitles cannot render in Overlay mode.'
                                                    : (widget.currentDecoderMode == 'mediacodec'
                                                        ? 'PGS subtitles require HW+ or SW decoder to render natively.'
                                                        : 'Native rendering active with compatible decoder.'),
                                                style: TextStyle(
                                                  color: widget.currentRendererMode == 'flutter'
                                                      ? Colors.redAccent
                                                      : (widget.currentDecoderMode == 'mediacodec'
                                                          ? Colors.orangeAccent
                                                          : Colors.white70),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (widget.currentRendererMode == 'flutter')
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => widget.onRendererModeChanged('native'),
                                                child: Text(
                                                  'Use Native',
                                                  style: TextStyle(color: settingsAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              )
                                            else if (widget.currentDecoderMode == 'mediacodec')
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => widget.onDecoderModeChanged('mediacodec-copy'),
                                                child: Text(
                                                  'Use HW+',
                                                  style: TextStyle(color: settingsAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const Divider(color: Colors.white10, height: 1),
                                ],
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
                                              
                                              final typeKey = widget.isSubtitle ? 'sub' : 'audio';
                                              final codec = widget.trackCodecs['$typeKey/${track.id}'];
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
                                              padding: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
                                              child: InkWell(
                                                onTap: () => widget.onTrackSelected(track),
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
                        
                        if (widget.isSubtitle && _activeTab == 0) ...[
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
                                          '${widget.currentSubtitleDelay > 0 ? '+' : ''}${widget.currentSubtitleDelay.toStringAsFixed(1)}s',
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
                                          onPressed: () => widget.onSubtitleDelayChanged(0.0),
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
                                    value: widget.currentSubtitleDelay.clamp(-5.0, 5.0),
                                    min: -5.0,
                                    max: 5.0,
                                    divisions: 100, // 0.1s increments
                                    activeColor: settingsAccent,
                                    inactiveColor: Colors.white24,
                                    onChanged: widget.onSubtitleDelayChanged,
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

  Widget _buildTabButton(int index, String label, Color settingsAccent) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? settingsAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? settingsAccent : Colors.white10,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? settingsAccent : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
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
        onTap: () => widget.onRendererModeChanged(mode),
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
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
