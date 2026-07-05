import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../logger.dart';

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
      settingsBackground: Color.lerp(
        settingsBackground,
        other.settingsBackground,
        t,
      ),
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
  const ColorThemePreset(
    id: 'netflixRed',
    name: 'Netflix Red',
    primaryColor: Color(0xFFE50914), // Netflix Red
    settingsPrimaryColor: Color(0xFFE50914),
    scaffoldBgDark: Colors.black,
    settingsBgDark: Color(0xFF141414),
    cardBgDark: Color(0xFF1F1F1F),
    scaffoldBgLight: Color(0xFFF3F4F6),
    settingsBgLight: Color(0xFFE5E7EB),
    cardBgLight: Colors.white,
  ),
  const ColorThemePreset(
    id: 'sunsetCyberpunk',
    name: 'Sunset Cyberpunk',
    primaryColor: Color(0xFFFF007F), // Neon Pink
    settingsPrimaryColor: Color(0xFFFF007F),
    scaffoldBgDark: Color(0xFF120826), // Violet-Black
    settingsBgDark: Color(0xFF1E0E3D),
    cardBgDark: Color(0xFF28154D),
    scaffoldBgLight: Color(0xFFFFF0F5), // Lavender Blush
    settingsBgLight: Color(0xFFF3E5F5),
    cardBgLight: Colors.white,
  ),
  const ColorThemePreset(
    id: 'auroraAbyss',
    name: 'Aurora Abyss',
    primaryColor: Color(0xFF00E5FF), // Cyan
    settingsPrimaryColor: Color(0xFF00E5FF),
    scaffoldBgDark: Color(0xFF05191C), // Deep Teal
    settingsBgDark: Color(0xFF0C292E),
    cardBgDark: Color(0xFF143B42),
    scaffoldBgLight: Color(0xFFE0F7FA), // Light Cyan
    settingsBgLight: Color(0xFFE0F2F1),
    cardBgLight: Colors.white,
  ),
  const ColorThemePreset(
    id: 'midnightSlate',
    name: 'Midnight Slate',
    primaryColor: Colors.indigoAccent,
    settingsPrimaryColor: Colors.indigoAccent,
    scaffoldBgDark: Color(0xFF0F172A), // Slate 900
    settingsBgDark: Color(0xFF1E293B), // Slate 800
    cardBgDark: Color(0xFF334155), // Slate 700
    scaffoldBgLight: Color(0xFFF1F5F9), // Slate 100
    settingsBgLight: Color(0xFFE2E8F0),
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
  static final Map<String, ThemeData> _themeCache = {};

  ThemeData _buildThemeCached(ColorThemePreset preset, bool isDark, bool isAmoled) {
    final key = '${preset.id}|$isDark|$isAmoled';
    return _themeCache.putIfAbsent(key, () => _buildTheme(preset, isDark, isAmoled));
  }

  @override
  AppThemeState build() {
    final storageService = ref.watch(storageServiceProvider);
    final themeModeStr = storageService.getThemeMode();
    final themeMode = _parseThemeMode(themeModeStr);
    final colorThemeId = storageService.getTheme();

    final preset = appThemes.firstWhere(
      (theme) => theme.id == colorThemeId,
      orElse: () {
        Log.w('Unknown color theme id: $colorThemeId — falling back to first');
        return appThemes.first;
      },
    );

    final isAmoled = (themeModeStr == 'amoled');

    return AppThemeState(
      themeMode: themeMode,
      colorThemeId: colorThemeId,
      lightTheme: _buildThemeCached(preset, false, false),
      darkTheme: _buildThemeCached(preset, true, isAmoled),
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

  void _updateState(ThemeMode mode, String colorThemeId, bool isAmoled) {
    final preset = appThemes.firstWhere(
      (theme) => theme.id == colorThemeId,
      orElse: () {
        Log.w('Unknown color theme id: $colorThemeId — falling back to first');
        return appThemes.first;
      },
    );

    state = AppThemeState(
      themeMode: mode,
      colorThemeId: colorThemeId,
      lightTheme: _buildThemeCached(preset, false, false),
      darkTheme: _buildThemeCached(preset, true, isAmoled),
    );
  }

  Future<void> updateThemeMode(String modeStr) async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.setThemeMode(modeStr);
    _updateState(_parseThemeMode(modeStr), state.colorThemeId, modeStr == 'amoled');
  }

  Future<void> updateColorTheme(String colorThemeId) async {
    final storageService = ref.read(storageServiceProvider);
    final themeModeStr = storageService.getThemeMode();
    await storageService.setTheme(colorThemeId);
    _updateState(state.themeMode, colorThemeId, themeModeStr == 'amoled');
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

    // Fix contrast issues in light mode for bright neon colors
    Color effectivePrimary = preset.primaryColor;
    if (!isDark) {
      final hsl = HSLColor.fromColor(effectivePrimary);
      if (hsl.lightness > 0.4) {
        effectivePrimary = hsl.withLightness(0.4).toColor();
      }
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: effectivePrimary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: effectivePrimary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: effectivePrimary,
        surface: scaffoldBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? (isAmoled ? Colors.black : scaffoldBg)
            : Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? (isAmoled ? Colors.black : scaffoldBg)
            : Colors.white,
        selectedItemColor: effectivePrimary,
        unselectedItemColor: subTextColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? (isAmoled ? Colors.black : scaffoldBg)
            : Colors.white,
        indicatorColor: effectivePrimary.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: effectivePrimary);
          }
          return IconThemeData(color: subTextColor);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(
              color: effectivePrimary,
              fontWeight: FontWeight.bold,
            );
          }
          return style.copyWith(color: subTextColor);
        }),
      ),
      extensions: [
        AppThemeExtension(
          settingsBackground: settingsBg,
          settingsAccent: isDark
              ? preset.settingsPrimaryColor
              : effectivePrimary,
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
