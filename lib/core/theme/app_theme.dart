import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

enum AppThemeType {
  sunsetCyberpunk,
  auroraAbyss,
  solarisFlare,
  classicNavy,
}

class AppThemeData {
  final String name;
  final Brightness brightness;
  final Color primaryColor;
  final Color cardColor;
  final Color scaffoldBackgroundColor;
  final LinearGradient backgroundGradient;
  final LinearGradient accentGradient;
  final Color textColor;
  final Color subtitleColor;

  const AppThemeData({
    required this.name,
    required this.brightness,
    required this.primaryColor,
    required this.cardColor,
    required this.scaffoldBackgroundColor,
    required this.backgroundGradient,
    required this.accentGradient,
    required this.textColor,
    required this.subtitleColor,
  });
}

class AppThemes {
  static final sunsetCyberpunk = AppThemeData(
    name: 'Sunset Cyberpunk',
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFF5E36),
    cardColor: const Color(0xFF140F26),
    scaffoldBackgroundColor: Colors.transparent,
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF0F0C20), Color(0xFF060410)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: const LinearGradient(
      colors: [Color(0xFFFF007F), Color(0xFFFF5E36)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    textColor: Colors.white,
    subtitleColor: Colors.white70,
  );

  static final auroraAbyss = AppThemeData(
    name: 'Aurora Abyss',
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF00FF87),
    cardColor: const Color(0xFF06141B),
    scaffoldBackgroundColor: Colors.transparent,
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF02161E), Color(0xFF010609)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: const LinearGradient(
      colors: [Color(0xFF00FF87), Color(0xFF60EFFF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    textColor: Colors.white,
    subtitleColor: Colors.white70,
  );

  static final solarisFlare = AppThemeData(
    name: 'Solaris Flare',
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFFB703),
    cardColor: const Color(0xFF1A1107),
    scaffoldBackgroundColor: Colors.transparent,
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF160E05), Color(0xFF050301)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: const LinearGradient(
      colors: [Color(0xFFFFB703), Color(0xFFD62828)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    textColor: Colors.white,
    subtitleColor: Colors.white70,
  );

  static final classicNavy = AppThemeData(
    name: 'Classic Navy',
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF00B4D8),
    cardColor: const Color(0xFF0C162D),
    scaffoldBackgroundColor: Colors.transparent,
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF081636), Color(0xFF000E26)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: const LinearGradient(
      colors: [Color(0xFF00B4D8), Color(0xFF3A0CA3)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    textColor: Colors.white,
    subtitleColor: Colors.white70,
  );

  static AppThemeData getTheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.sunsetCyberpunk:
        return sunsetCyberpunk;
      case AppThemeType.auroraAbyss:
        return auroraAbyss;
      case AppThemeType.solarisFlare:
        return solarisFlare;
      case AppThemeType.classicNavy:
        return classicNavy;
    }
  }
}

class ThemeBackground extends ConsumerWidget {
  final Widget child;

  const ThemeBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(appThemeProvider);
    final themeData = AppThemes.getTheme(themeType);

    return Container(
      decoration: BoxDecoration(
        gradient: themeData.backgroundGradient,
      ),
      child: child,
    );
  }
}
