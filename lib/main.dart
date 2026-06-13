import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdlib/td_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_screen.dart';
import 'features/auth/auth_controller.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  MediaKit.ensureInitialized();
  
  await TdPlugin.initialize(Platform.isAndroid ? 'libtdjson.so' : null);
  
  final container = ProviderContainer();
  await container.read(storageServiceProvider).init();
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TelStreamApp(),
    ),
  );
}

class TelStreamApp extends ConsumerWidget {
  const TelStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(appThemeProvider);
    final activeTheme = AppThemes.getTheme(themeType);

    return MaterialApp(
      title: 'TelStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: activeTheme.brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: activeTheme.primaryColor,
          brightness: activeTheme.brightness,
          primary: activeTheme.primaryColor,
          surface: activeTheme.cardColor,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: activeTheme.textColor,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: activeTheme.primaryColor,
          unselectedItemColor: activeTheme.textColor.withOpacity(0.6),
        ),
      ),
      builder: (context, child) {
        return ThemeBackground(child: child ?? const SizedBox.shrink());
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    
    if (authState.step == AuthStep.authenticated) {
      return const MainScreen();
    }
    return const LoginScreen();
  }
}
