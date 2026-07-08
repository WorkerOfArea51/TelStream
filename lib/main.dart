import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tdlib/td_client.dart';
import 'package:path_provider/path_provider.dart';
import 'core/logger.dart';
import 'core/constants.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'features/auth/login_screen.dart';
import 'features/home/main_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/splash_screen.dart';
import 'services/storage_service.dart';
import 'services/streaming_proxy_service.dart';
import 'services/firebase_metadata_service.dart';
import 'core/theme/app_theme.dart';
import 'services/tdlib_service.dart';

void main() async {
  // 1. Catch synchronous framework errors.
  FlutterError.onError = (FlutterErrorDetails details) {
    Log.e('Flutter framework error: ${details.exception}', details.stack);
    FlutterError.presentError(details);
  };

  // 2. Catch isolate-creation errors (compute() / Isolate.run).
  Isolate.current.addErrorListener(RawReceivePort((dynamic data) {
    final list = data as List;
    Log.e('Isolate error: ${list[0]}', null, StackTrace.fromString(list[1] as String));
  }).sendPort);

  // 3. Catch all other async errors.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    ProviderContainer? container;
    Object? startupError;

    try {
      final supportDir = await getApplicationSupportDirectory();
      final dirPath = supportDir.path.replaceAll('\\', '/');
          
      final logDir = Directory(dirPath);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      await Log.init(dirPath);

      MediaKit.ensureInitialized();
      await Constants.initVersion();
      
      container = ProviderContainer();
      
      // TDLib is the hardest dependency to recover from — initialize it FIRST,
      // so if it fails, we don't waste cycles on Firebase/storage work that
      // would be useless without it.
      await TdPlugin.initialize(
        Platform.isAndroid ? 'libtdjson.so' : (Platform.isWindows ? 'tdjson.dll' : null)
      );

      if (Platform.isWindows) {
        await windowManager.ensureInitialized();
        WindowOptions windowOptions = const WindowOptions(
          size: Size(1000, 700),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      // These two can run in parallel — both are pure I/O and independent.
      await Future.wait([
        container.read(storageServiceProvider).init(),
        FirebaseMetadataService.loadAllMetadata(),
      ]);
      
      // Pre-warm the streaming proxy provider to start the HTTP server early
      container.read(streamingProxyServiceProvider);
      
    } catch (e, stack) {
      startupError = e;
      Log.e('Fatal error during startup: $e', stack);
      container?.dispose();
      container = null;
    }

    runApp(_TelStreamRoot(container: container, startupError: startupError));
  }, (error, stack) {
    Log.e('Uncaught asynchronous error: $error', stack);
  });
}

class _TelStreamRoot extends StatelessWidget {
  final ProviderContainer? container;
  final Object? startupError;

  const _TelStreamRoot({this.container, this.startupError});

  @override
  Widget build(BuildContext context) {
    if (startupError != null || container == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Fatal Error: $startupError',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return UncontrolledProviderScope(
      container: container!,
      child: const TelStreamApp(),
    );
  }
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final TdlibService _tdlib;
  _AppLifecycleObserver(this._tdlib);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tdlib.onAppStateChanged(state);
  }
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _splashCompleted = false;
  Timer? _splashTimer;
  _AppLifecycleObserver? _lifecycleObserver;
  static bool _splashShownThisSession = false;

  @override
  void initState() {
    super.initState();
    if (_splashShownThisSession) {
      _splashCompleted = true;
    } else {
      _splashShownThisSession = true;
      _splashTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _splashCompleted = true;
          });
        }
      });
    }
    
    _lifecycleObserver = _AppLifecycleObserver(ref.read(tdlibServiceProvider));
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
    super.dispose();
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
