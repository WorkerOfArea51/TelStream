import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import 'app_theme.dart';

class AppThemeNotifier extends Notifier<AppThemeType> {
  @override
  AppThemeType build() {
    final storage = ref.read(storageServiceProvider);
    final themeStr = storage.getTheme();
    return AppThemeType.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppThemeType.sunsetCyberpunk,
    );
  }

  Future<void> setTheme(AppThemeType type) async {
    state = type;
    await ref.read(storageServiceProvider).setTheme(type.name);
  }
}

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppThemeType>(AppThemeNotifier.new);
