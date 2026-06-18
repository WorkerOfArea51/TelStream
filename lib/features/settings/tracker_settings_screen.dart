import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';
import '../../core/theme/app_theme.dart';

class TrackerSettingsScreen extends ConsumerStatefulWidget {
  const TrackerSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TrackerSettingsScreen> createState() => _TrackerSettingsScreenState();
}

class _TrackerSettingsScreenState extends ConsumerState<TrackerSettingsScreen> {
  late final TextEditingController _anilistController;
  late final TextEditingController _malController;
  late final TextEditingController _traktController;
  late final TextEditingController _tmdbController;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _anilistController = TextEditingController(text: storage.getAnilistToken() ?? '');
    _malController = TextEditingController(text: storage.getMalToken() ?? '');
    _traktController = TextEditingController(text: storage.getTraktToken() ?? '');
    _tmdbController = TextEditingController(text: storage.getTmdbApiKey() ?? '');
  }

  @override
  void dispose() {
    _anilistController.dispose();
    _malController.dispose();
    _traktController.dispose();
    _tmdbController.dispose();
    super.dispose();
  }

  Future<void> _launchUrlHelper(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _savePreferences() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setAnilistToken(_anilistController.text.trim());
    await storage.setMalToken(_malController.text.trim());
    await storage.setTraktToken(_traktController.text.trim());
    await storage.setTmdbApiKey(_tmdbController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracker settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsBg = customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor;
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: settingsBg,
      appBar: AppBar(
        title: Text(
          'Tracker Accounts',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            tooltip: 'Save Settings',
            onPressed: _savePreferences,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info header card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: settingsAccent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Login to MyAnimeList, AniList, or Trakt.tv to automatically sync watch progress in the background once you reach 80% watched of an episode.',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // AniList Section
          _buildTrackerSection(
            title: 'AniList',
            icon: Icons.favorite_border,
            controller: _anilistController,
            hintText: 'Paste AniList Access Token',
            helperUrl: 'https://anilist.co/settings/developer',
            instructions: '1. Visit AniList Developer Settings.\n2. Create a Client or use an existing Developer Token.\n3. Paste the generated Access Token here.',
            accentColor: Colors.blueAccent,
            isDark: isDark,
            theme: theme,
          ),

          const SizedBox(height: 24),

          // MAL Section
          _buildTrackerSection(
            title: 'MyAnimeList (MAL)',
            icon: Icons.star_outline,
            controller: _malController,
            hintText: 'Paste MyAnimeList Access Token',
            helperUrl: 'https://myanimelist.net/apiconfig',
            instructions: '1. Open MyAnimeList API Settings.\n2. Authorize an application to fetch your Developer Token.\n3. Paste your OAuth2 access token here.',
            accentColor: Colors.tealAccent,
            isDark: isDark,
            theme: theme,
          ),

          const SizedBox(height: 24),

          // Trakt.tv Section
          _buildTrackerSection(
            title: 'Trakt.tv',
            icon: Icons.movie_outlined,
            controller: _traktController,
            hintText: 'Paste Trakt.tv Access Token',
            helperUrl: 'https://trakt.tv/oauth/applications',
            instructions: '1. Create a new App in Trakt API Developer dashboard.\n2. Obtain/generate a personal Access Token.\n3. Paste your Trakt access token here.',
            accentColor: Colors.redAccent,
            isDark: isDark,
            theme: theme,
          ),

          const SizedBox(height: 24),

          // TMDB Section
          _buildTrackerSection(
            title: 'The Movie Database (TMDB)',
            icon: Icons.movie_filter_outlined,
            controller: _tmdbController,
            hintText: 'Paste TMDB API Key (v3)',
            helperUrl: 'https://www.themoviedb.org/settings/api',
            instructions: '1. Log in to TMDB and open API Settings.\n2. Request an API key (v3) for developer use.\n3. Paste your 32-character API key here. (Leave empty to use the system default key)',
            accentColor: Colors.orangeAccent,
            isDark: isDark,
            theme: theme,
            obscureText: false,
          ),

          const SizedBox(height: 40),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: settingsAccent,
                foregroundColor: settingsAccent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _savePreferences,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerSection({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required String helperUrl,
    required String instructions,
    required Color accentColor,
    required bool isDark,
    required ThemeData theme,
    bool obscureText = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _launchUrlHelper(helperUrl),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Get Token', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            instructions,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
              prefixIcon: Icon(Icons.key, color: isDark ? Colors.white30 : Colors.black38, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
