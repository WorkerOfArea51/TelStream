import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdlib/td_client.dart';
import 'package:path_provider/path_provider.dart';
import 'core/logger.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/splash_screen.dart';
import 'services/storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appData = Platform.environment['APPDATA'] ?? '';
  final dirPath = Platform.isWindows 
      ? '$appData/com.darkmatter/telstream'.replaceAll('\\', '/')
      : (await getApplicationSupportDirectory()).path;
  Log.init(dirPath);

  MediaKit.ensureInitialized();
  
  await TdPlugin.initialize(Platform.isAndroid ? 'libtdjson.so' : (Platform.isWindows ? 'tdjson.dll' : null));
  
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

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _splashCompleted = false;

  @override
  void initState() {
    super.initState();
    // Keep splash animation showing for at least 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _splashCompleted = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashCompleted) {
      return const SplashScreen();
    }

    final authState = ref.watch(authControllerProvider);
    if (authState.step == AuthStep.authenticated) {
      return const MainScreen();
    }
    return const LoginScreen();
  }
}
