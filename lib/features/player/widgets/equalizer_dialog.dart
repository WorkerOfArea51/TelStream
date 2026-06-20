import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/settings_provider.dart';
import '../../../core/theme/app_theme.dart';

class EqualizerDialog extends ConsumerWidget {
  final VoidCallback onFiltersUpdated;

  const EqualizerDialog({
    super.key,
    required this.onFiltersUpdated,
  });

  static void show(BuildContext context, {required VoidCallback onFiltersUpdated}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => EqualizerDialog(onFiltersUpdated: onFiltersUpdated),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    
    final presets = const <String, List<double>>{
      'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
      'Bass Boost': [5.0, 3.0, 0.0, 0.0, -1.0],
      'Vocal': [-2.0, 1.0, 3.0, 2.0, 1.0],
      'Rock': [3.0, 1.5, -1.0, 1.5, 3.0],
      'Pop': [-1.0, 2.0, 3.0, 2.0, -2.0],
    };

    return StatefulBuilder(
      builder: (context, setModalState) {
        final settings = ref.watch(videoSettingsProvider);
        final isEnabled = settings.equalizerEnabled;
        final activePreset = settings.equalizerPreset;
        final bands = settings.equalizerBands;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.equalizer, color: settingsAccent),
                      const SizedBox(width: 8),
                      const Text(
                        'Audio Equalizer',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Switch(
                        value: isEnabled,
                        activeThumbColor: settingsAccent,
                        onChanged: (val) {
                          ref.read(videoSettingsProvider.notifier).updateSettings(
                            settings.copyWith(equalizerEnabled: val),
                          );
                          setModalState(() {});
                          onFiltersUpdated();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 8),
              
              // Presets horizontal list
              Opacity(
                opacity: isEnabled ? 1.0 : 0.5,
                child: IgnorePointer(
                  ignoring: !isEnabled,
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        ...presets.keys.map((presetName) {
                          final isSelected = activePreset == presetName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(presetName),
                              selected: isSelected,
                              selectedColor: settingsAccent,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(videoSettingsProvider.notifier).updateSettings(
                                    settings.copyWith(
                                      equalizerPreset: presetName,
                                      equalizerBands: presets[presetName]!,
                                    ),
                                  );
                                  setModalState(() {});
                                  onFiltersUpdated();
                                }
                              },
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: const Text('Custom'),
                            selected: activePreset == 'Custom',
                            selectedColor: settingsAccent,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            labelStyle: TextStyle(
                              color: activePreset == 'Custom' ? Colors.black : Colors.white,
                              fontWeight: activePreset == 'Custom' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5 Sliders row
              Opacity(
                opacity: isEnabled ? 1.0 : 0.5,
                child: IgnorePointer(
                  ignoring: !isEnabled,
                  child: Container(
                    height: 180,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final frequencyLabels = const ['100Hz', '300Hz', '1kHz', '3kHz', '10kHz'];
                        final label = frequencyLabels[index];
                        final val = bands.length > index ? bands[index] : 0.0;

                        return Column(
                          children: [
                            Text(
                              label,
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: val,
                                  min: -12.0,
                                  max: 12.0,
                                  divisions: 48, // 0.5 dB precision
                                  activeColor: settingsAccent,
                                  inactiveColor: Colors.white12,
                                  onChanged: (newVal) {
                                    final newBands = List<double>.from(bands);
                                    if (newBands.length > index) {
                                      newBands[index] = double.parse(newVal.toStringAsFixed(1));
                                    }
                                    ref.read(videoSettingsProvider.notifier).updateSettings(
                                      settings.copyWith(
                                        equalizerPreset: 'Custom',
                                        equalizerBands: newBands,
                                      ),
                                    );
                                    setModalState(() {});
                                    onFiltersUpdated();
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${val > 0 ? '+' : ''}${val.toStringAsFixed(1)} dB',
                              style: const TextStyle(color: Colors.white54, fontSize: 9),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
