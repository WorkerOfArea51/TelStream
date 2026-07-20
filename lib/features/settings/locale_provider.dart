import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final storageService = ref.watch(storageServiceProvider);
    final localeStr = storageService.getLocale();
    if (localeStr == null || localeStr.isEmpty) {
      return null; // System locale
    }
    return Locale(localeStr);
  }

  Future<void> setLocale(String localeCode) async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.setLocale(localeCode);
    state = Locale(localeCode);
  }
  
  Future<void> clearLocale() async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.setLocale('');
    state = null;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(() {
  return LocaleNotifier();
});
