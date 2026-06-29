import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';

/// Custom theme extension to support modular configurations for settings/player sub-panels.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color? settingsBackground;
  final Color? settingsAccent;

  const AppThemeExtension({
    required this.settingsBackground,
    required this.settingsAccent,
  });

  @override
  AppThemeExtension copyWith({
    Color? settingsBackground,
    Color? settingsAccent,
  }) {
    return AppThemeExtension(
      settingsBackground: settingsBackground ?? this.settingsBackground,
      settingsAccent: settingsAccent ?? this.settingsAccent,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      settingsBackground: Color.lerp(settingsBackground, other.settingsBackground, t),
      settingsAccent: Color.lerp(settingsAccent, other.settingsAccent, t),
    );
  }
}

/// Token preset for color themes.
class ColorThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color settingsPrimaryColor;
  
  // Backgrounds
  final Color scaffoldBgDark;
  final Color settingsBgDark;
  final Color cardBgDark;
  
  final Color scaffoldBgLight;
  final Color settingsBgLight;
  final Color cardBgLight;

  const ColorThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.settingsPrimaryColor,
    required this.scaffoldBgDark,
    required this.settingsBgDark,
    required this.cardBgDark,
    required this.scaffoldBgLight,
    required this.settingsBgLight,
    required this.cardBgLight,
  });
}

/// Active themes available in the app.
final List<ColorThemePreset> appThemes = [
  const ColorThemePreset(
    id: 'classic',
    name: 'TelStream Classic',
    primaryColor: Colors.orange,
    settingsPrimaryColor: Colors.orange,
    scaffoldBgDark: Colors.black,
    settingsBgDark: Colors.black,
    cardBgDark: Color(0xFF1C1C1E),
    scaffoldBgLight: Color(0xFFF3F4F6),
    settingsBgLight: Color(0xFFE5E7EB),
    cardBgLight: Colors.white,
  ),
];

class AppThemeState {
  final ThemeMode themeMode;
  final String colorThemeId;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  AppThemeState({
    required this.themeMode,
    required this.colorThemeId,
    required this.lightTheme,
    required this.darkTheme,
  });

  ColorThemePreset get activePreset {
    return appThemes.firstWhere(
      (theme) => theme.id == colorThemeId,
      orElse: () => appThemes.first,
    );
  }
}

class AppThemeNotifier extends Notifier<AppThemeState> {
  @override
  AppThemeState build() {
    final storageService = ref.watch(storageServiceProvider);
    final themeMode = _parseThemeMode(storageService.getThemeMode());
    final colorThemeId = 'classic'; // Locked to classic

    return AppThemeState(
      themeMode: themeMode,
      colorThemeId: colorThemeId,
      lightTheme: _buildTheme(appThemes.first, false, false),
      darkTheme: _buildTheme(appThemes.first, true, true), // Force amoled = true for Dark Mode
    );
  }

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'amoled':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  void _updateState(ThemeMode mode, String colorThemeId) {
    state = AppThemeState(
      themeMode: mode,
      colorThemeId: 'classic',
      lightTheme: _buildTheme(appThemes.first, false, false),
      darkTheme: _buildTheme(appThemes.first, true, true), // Force amoled = true for Dark Mode
    );
  }

  Future<void> updateThemeMode(String modeStr) async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.setThemeMode(modeStr);
    _updateState(_parseThemeMode(modeStr), 'classic');
  }

  Future<void> updateColorTheme(String colorThemeId) async {
    // Locked to classic
    _updateState(state.themeMode, 'classic');
  }

  ThemeData _buildTheme(ColorThemePreset preset, bool isDark, bool isAmoled) {
    final scaffoldBg = isDark
        ? (isAmoled ? Colors.black : preset.scaffoldBgDark)
        : preset.scaffoldBgLight;

    final settingsBg = isDark
        ? (isAmoled ? Colors.black : preset.settingsBgDark)
        : preset.settingsBgLight;

    final cardBg = isDark
        ? (isAmoled ? const Color(0xFF0F0F0F) : preset.cardBgDark)
        : preset.cardBgLight;

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: preset.primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: preset.primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: preset.primaryColor,
        surface: scaffoldBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? (isAmoled ? Colors.black : scaffoldBg) : Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? (isAmoled ? Colors.black : scaffoldBg) : Colors.white,
        selectedItemColor: preset.primaryColor,
        unselectedItemColor: subTextColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? (isAmoled ? Colors.black : scaffoldBg) : Colors.white,
        indicatorColor: preset.primaryColor.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: preset.primaryColor);
          }
          return IconThemeData(color: subTextColor);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(color: preset.primaryColor, fontWeight: FontWeight.bold);
          }
          return style.copyWith(color: subTextColor);
        }),
      ),
      extensions: [
        AppThemeExtension(
          settingsBackground: settingsBg,
          settingsAccent: isDark ? preset.settingsPrimaryColor : preset.primaryColor,
        ),
      ],
      textTheme: const TextTheme().apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
    );
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeState>(() {
  return AppThemeNotifier();
});
