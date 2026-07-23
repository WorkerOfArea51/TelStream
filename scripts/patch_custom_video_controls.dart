import 'dart:io';

void main() {
  final file = File('lib/features/player/custom_video_controls.dart');
  var content = file.readAsStringSync();
  
  // Add import
  content = content.replaceFirst(
    "import 'widgets/player_header_bar.dart';",
    "import 'widgets/player_header_bar.dart';\nimport 'widgets/aspect_ratio_panel.dart';"
  );
  
  // Remove _buildScreenRatioButton, _buildPillRatioButton, _buildSwitchRow, _buildRatioPanel
  final startIdx = content.indexOf('  Widget _buildScreenRatioButton(');
  final endIdx = content.indexOf('  Future<void> _loadTrackCodecs() async {');
  
  if (startIdx != -1 && endIdx != -1) {
    content = content.replaceRange(startIdx, endIdx, '');
  } else {
    print('Could not find the target range');
    exit(1);
  }
  
  // Replace the call to _buildRatioPanel()
  final callReplacement = '''            child: AspectRatioPanel(
              onClose: _closeAspectRatioPanel,
              currentFit: _fit,
              customAspectRatio: _customAspectRatio,
              onSelectRatio: _applyAspectRatioString,
              rememberRatio: _rememberRatio,
              onToggleRememberRatio: (val) {
                setState(() {
                  _rememberRatio = val;
                });
                ref.read(storageServiceProvider).setRememberAspectRatio(val);
                if (val) {
                  ref.read(storageServiceProvider).setSavedAspectRatio(_currentAspectRatioString);
                }
              },
              tapToSwitchRatio: _tapToSwitchRatio,
              onToggleTapToSwitch: (val) {
                setState(() {
                  _tapToSwitchRatio = val;
                });
                ref.read(storageServiceProvider).setTapToSwitchAspectRatio(val);
              },
            ),''';
  
  content = content.replaceFirst('            child: _buildRatioPanel(),', callReplacement);
  
  file.writeAsStringSync(content);
  print('Successfully patched custom_video_controls.dart');
}
