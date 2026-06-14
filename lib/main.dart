import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdlib/td_client.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_screen.dart';
import 'features/auth/auth_controller.dart';
import 'services/storage_service.dart';
import 'core/theme/app_theme.dart';

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
    final themeState = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'TelStream',
      debugShowCheckedModeBanner: false,
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.themeMode,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
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
