import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'locale_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);
    final currentLocaleCode = currentLocale?.languageCode ?? 'system';
    final l10n = AppLocalizations.of(context)!;

    final languages = [
      {'code': 'system', 'native': l10n.systemDefault, 'en': l10n.systemDefault},
      {'code': 'en', 'native': 'English', 'en': 'English'},
      {'code': 'ru', 'native': 'Русский', 'en': 'Russian'},
      {'code': 'es', 'native': 'Español', 'en': 'Spanish'},
      {'code': 'fr', 'native': 'Français', 'en': 'French'},
      {'code': 'de', 'native': 'Deutsch', 'en': 'German'},
      {'code': 'ja', 'native': '日本語', 'en': 'Japanese'},
      {'code': 'zh', 'native': '简体中文', 'en': 'Chinese Simplified'},
      {'code': 'hi', 'native': 'हिन्दी', 'en': 'Hindi'},
      {'code': 'bn', 'native': 'বাংলা', 'en': 'Bengali'},
      {'code': 'ar', 'native': 'العربية', 'en': 'Arabic'},
      {'code': 'fa', 'native': 'فارسی', 'en': 'Persian'},
      {'code': 'pt', 'native': 'Português', 'en': 'Portuguese'},
      {'code': 'it', 'native': 'Italiano', 'en': 'Italian'},
      {'code': 'ko', 'native': '한국어', 'en': 'Korean'},
      {'code': 'tr', 'native': 'Türkçe', 'en': 'Turkish'},
      {'code': 'id', 'native': 'Bahasa Indonesia', 'en': 'Indonesian'},
      {'code': 'vi', 'native': 'Tiếng Việt', 'en': 'Vietnamese'},
      {'code': 'th', 'native': 'ไทย', 'en': 'Thai'},
      {'code': 'pl', 'native': 'Polski', 'en': 'Polish'},
      {'code': 'uk', 'native': 'Українська', 'en': 'Ukrainian'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final isSelected = lang['code'] == currentLocaleCode;

          return ListTile(
            title: Text(
              lang['native']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            subtitle: lang['native'] != lang['en']
                ? Text(
                    lang['en']!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(153), // 0.6 opacity
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: isSelected
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            onTap: () {
              if (lang['code'] == 'system') {
                ref.read(localeProvider.notifier).clearLocale();
              } else {
                ref.read(localeProvider.notifier).setLocale(lang['code']!);
              }
            },
          );
        },
      ),
    );
  }
}
