import '../../../core/utils/subtitle_color_utils.dart';
import 'package:flutter/material.dart';

class SubtitleStylingTab extends StatelessWidget {
  final double currentFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final String currentFontColor;
  final ValueChanged<String> onFontColorChanged;
  final String currentFontFamily;
  final ValueChanged<String> onFontFamilyChanged;
  final String currentRendererMode;
  final Color settingsAccent;

  const SubtitleStylingTab({
    super.key,
    required this.currentFontSize,
    required this.onFontSizeChanged,
    required this.currentFontColor,
    required this.onFontColorChanged,
    required this.currentFontFamily,
    required this.onFontFamilyChanged,
    required this.currentRendererMode,
    required this.settingsAccent,
  });



  Widget _buildPresetCard(String sampleText, String colorHex, String fontFamily, Color activeColor) {
    final isSelected = currentFontColor.toUpperCase() == colorHex.toUpperCase();
    final colorVal = SubtitleColorUtils.parseColor(colorHex);

    return GestureDetector(
      onTap: () => onFontColorChanged(colorHex),
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
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live Preview
          const Text(
            'Live Preview',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
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
                color: SubtitleColorUtils.parseColor(currentFontColor),
                fontSize: (currentFontSize * 0.45).clamp(12.0, 24.0),
                fontFamily: currentFontFamily,
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
          const SizedBox(height: 12),

          // Warning if native is selected that it has limited styling on some ASS tracks
          if (currentRendererMode == 'native')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Note: Font style customization works fully on Overlay mode. Native mode styling is dependent on the video file track settings.',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ),

          // 2. Preset styles
          const Text(
            'Preset Styles',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPresetCard('Aa', '#FFFFFF', 'Roboto', settingsAccent),
              _buildPresetCard('Aa', '#00FFFF', 'Roboto', settingsAccent),
              _buildPresetCard('Aa', '#FFFF00', 'Roboto', settingsAccent),
              _buildPresetCard('Aa', '#00FF00', 'Roboto', settingsAccent),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Color Selection
          const Text(
            'Font Color',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: SubtitleColorUtils.colors.length,
              itemBuilder: (context, idx) {
                final colorInfo = SubtitleColorUtils.colors[idx];
                final colorHex = colorInfo['hex']!;
                final isSelected = currentFontColor.toUpperCase() == colorHex.toUpperCase();
                final colorVal = SubtitleColorUtils.parseColor(colorHex);

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => onFontColorChanged(colorHex),
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
          const SizedBox(height: 12),

          // 4. Font Size
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Font Size',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${currentFontSize.round()}px',
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
              value: currentFontSize,
              min: 16.0,
              max: 72.0,
              divisions: 56, // 1px steps
              activeColor: settingsAccent,
              inactiveColor: Colors.white24,
              onChanged: onFontSizeChanged,
            ),
          ),
          const SizedBox(height: 4),

          // 5. Font Family
          const Text(
            'Font Family',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Roboto', 'Arial', 'sans-serif', 'DejaVuSans'].map((font) {
              final isSelected = currentFontFamily.toLowerCase() == font.toLowerCase();
              return InkWell(
                onTap: () => onFontFamilyChanged(font),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? settingsAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? settingsAccent : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    font,
                    style: TextStyle(
                      color: isSelected ? settingsAccent : Colors.white70,
                      fontFamily: font,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

