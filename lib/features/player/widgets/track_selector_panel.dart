import '../../../core/utils/subtitle_color_utils.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/expressive_container.dart';

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
  final double currentAudioDelay;
  final ValueChanged<double> onAudioDelayChanged;
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
    required this.currentAudioDelay,
    required this.onAudioDelayChanged,
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



  void _updateAudioDelay(double val) {
    final roundedVal = double.parse(val.toStringAsFixed(1));
    if (widget.player.platform is NativePlayer) {
      try {
        (widget.player.platform as NativePlayer).setProperty('audio-delay', roundedVal.toString());
      } catch (_) {}
    }
    widget.onAudioDelayChanged(roundedVal);
  }

  Widget _buildPresetCard(String sampleText, String colorHex, Color activeColor) {
    final isSelected = widget.currentFontColor.toUpperCase() == colorHex.toUpperCase();
    final colorVal = SubtitleColorUtils.parseColor(colorHex);

    return GestureDetector(
      onTap: () => widget.onFontColorChanged(colorHex),
      child: Container(
        width: 68,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white10,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Text(
          sampleText,
          style: TextStyle(
            color: colorVal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

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

            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

            return Container(
              height: isLandscape ? double.infinity : (widget.isSubtitle ? 520.0 : 340.0),
              decoration: BoxDecoration(
                color: const Color(0xEB0A0F1D), // Slate 950 with 92% opacity - clean translucency (no blur)
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
                  
                  // Left arrow back and Title layout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: widget.onClose,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isSubtitle ? 'Subtitles' : 'Audio Tracks',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
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

                    // Subtitle Style Tab Main Screen
                    if (widget.isSubtitle && _activeTab == 1)
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          children: [
                            // 1. Mode Select Bar
                            const Text(
                              'Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildRendererModeButton('native', 'Built-in', settingsAccent),
                                const SizedBox(width: 12),
                                _buildRendererModeButton('flutter', 'Custom', settingsAccent),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Helper text or custom styles depending on active Mode
                            if (widget.currentRendererMode == 'native') ...[
                              Text(
                                'To set more subtitle options, like color, please change subtitle rendering',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else ...[
                              // Custom Mode Styles (Sample, presets, colors, size slider)
                              const SizedBox(height: 12),
                              // Live Preview Container
                              Container(
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  'Sample Subtitle',
                                  style: TextStyle(
                                    color: SubtitleColorUtils.parseColor(widget.currentFontColor),
                                    fontSize: (widget.currentFontSize * 0.45).clamp(12.0, 24.0),
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(offset: Offset(-1.5, -1.5), color: Colors.black, blurRadius: 1.0),
                                      Shadow(offset: Offset(1.5, -1.5), color: Colors.black, blurRadius: 1.0),
                                      Shadow(offset: Offset(1.5, 1.5), color: Colors.black, blurRadius: 1.0),
                                      Shadow(offset: Offset(-1.5, 1.5), color: Colors.black, blurRadius: 1.0),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Preset styles
                              const Text(
                                'Preset styles',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildPresetCard('Aa', '#FFFFFF', settingsAccent),
                                  _buildPresetCard('Aa', '#00FFFF', settingsAccent),
                                  _buildPresetCard('Aa', '#FFFF00', settingsAccent),
                                  _buildPresetCard('Aa', '#00FF00', settingsAccent),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Font color list selection
                              const Text(
                                'Font color',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 36,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: SubtitleColorUtils.colors.length,
                                  itemBuilder: (context, idx) {
                                    final colorInfo = SubtitleColorUtils.colors[idx];
                                    final colorHex = colorInfo['hex']!;
                                    final isSelected = widget.currentFontColor.toUpperCase() == colorHex.toUpperCase();
                                    final colorVal = SubtitleColorUtils.parseColor(colorHex);

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: GestureDetector(
                                        onTap: () => widget.onFontColorChanged(colorHex),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: colorVal,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? settingsAccent : Colors.white24,
                                              width: isSelected ? 2.5 : 1.0,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  color: colorVal.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                                  size: 16,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Font Size Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Font size',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${widget.currentFontSize.round()}px',
                                    style: TextStyle(color: settingsAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                                  value: widget.currentFontSize,
                                  min: 16.0,
                                  max: 72.0,
                                  divisions: 56,
                                  activeColor: settingsAccent,
                                  inactiveColor: Colors.white24,
                                  onChanged: widget.onFontSizeChanged,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            const Divider(color: Colors.white10, height: 24),

                            // Subtitle Delay Sync (Always visible in Style menu)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtitle Delay Sync:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
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
                            const SizedBox(height: 6),
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
                                divisions: 100,
                                activeColor: settingsAccent,
                                inactiveColor: Colors.white24,
                                onChanged: widget.onSubtitleDelayChanged,
                              ),
                            ),
                          ],
                        ),
                      )
                    // Tracks Tab List
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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

                            // Online download and folder selector placed below current subs (inside Tracks tab)
                            if (widget.isSubtitle) ...[
                              const Divider(color: Colors.white10, height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Material3ExpressiveContainer(
                                        shape: ExpressiveShape.squircle,
                                        size: 40,
                                        onTap: widget.onOpenSubtitleDownloader,
                                        inactiveColor: Colors.white.withValues(alpha: 0.08),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.cloud_download_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Search Online',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Material3ExpressiveContainer(
                                        shape: ExpressiveShape.squircle,
                                        size: 40,
                                        onTap: widget.onPickLocalSubtitle,
                                        inactiveColor: Colors.white.withValues(alpha: 0.08),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Open Local File',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Audio Delay Sync (Placed below the audio tracks inside Tracks tab)
                            if (!widget.isSubtitle) ...[
                              const Divider(color: Colors.white10, height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Audio delay',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${widget.currentAudioDelay > 0 ? '+' : ''}${widget.currentAudioDelay.toStringAsFixed(1)}s',
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
                                              onPressed: () => _updateAudioDelay(0.0),
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
                                    const SizedBox(height: 6),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      ),
                                      child: Slider(
                                        value: widget.currentAudioDelay.clamp(-5.0, 5.0),
                                        min: -5.0,
                                        max: 5.0,
                                        divisions: 100,
                                        activeColor: settingsAccent,
                                        inactiveColor: Colors.white24,
                                        onChanged: _updateAudioDelay,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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

  Widget _buildRendererModeButton(String modeId, String label, Color settingsAccent) {
    final isSelected = widget.currentRendererMode == modeId;
    return Expanded(
      child: InkWell(
        onTap: () {
          widget.onRendererModeChanged(modeId);
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
}

