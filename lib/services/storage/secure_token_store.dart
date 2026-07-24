import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/logger.dart';

class SecureTokenStore {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  String? _anilistTokenCache;
  String? _malTokenCache;
  String? _traktTokenCache;
  String? _openSubtitlesApiKeyCache;
  String? _subdlApiKeyCache;

  bool _isInitialized = false;

  Future<void> init() async {
    try {
      _anilistTokenCache = await _secureStorage.read(key: 'anilist_token');
      _malTokenCache = await _secureStorage.read(key: 'mal_token');
      _traktTokenCache = await _secureStorage.read(key: 'trakt_token');
      _openSubtitlesApiKeyCache = await _secureStorage.read(key: 'os_api_key');
      _subdlApiKeyCache = await _secureStorage.read(key: 'subdl_api_key');
      _isInitialized = true;
    } catch (e) {
      Log.e('Failed to load secure tokens', e);
      _isInitialized = true;
    }
  }

  void _checkInit() {
    if (!_isInitialized) {
      Log.w('SecureTokenStore accessed before init() completed!');
    }
  }

  // --- Tokens ---

  String? getAnilistToken() {
    _checkInit();
    return _anilistTokenCache;
  }

  Future<void> setAnilistToken(String? value) async {
    _anilistTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'anilist_token');
    } else {
      await _secureStorage.write(key: 'anilist_token', value: value);
    }
  }

  String? getMalToken() {
    _checkInit();
    return _malTokenCache;
  }

  Future<void> setMalToken(String? value) async {
    _malTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'mal_token');
    } else {
      await _secureStorage.write(key: 'mal_token', value: value);
    }
  }

  String? getTraktToken() {
    _checkInit();
    return _traktTokenCache;
  }

  Future<void> setTraktToken(String? value) async {
    _traktTokenCache = value;
    if (value == null) {
      await _secureStorage.delete(key: 'trakt_token');
    } else {
      await _secureStorage.write(key: 'trakt_token', value: value);
    }
  }

  String getOpenSubtitlesApiKey() {
    _checkInit();
    return _openSubtitlesApiKeyCache ?? '';
  }

  Future<void> setOpenSubtitlesApiKey(String? value) async {
    _openSubtitlesApiKeyCache = value;
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: 'os_api_key');
    } else {
      await _secureStorage.write(key: 'os_api_key', value: value);
    }
  }

  String getSubdlApiKey() {
    _checkInit();
    return _subdlApiKeyCache ?? '';
  }

  Future<void> setSubdlApiKey(String? value) async {
    _subdlApiKeyCache = value;
    if (value == null || value.isEmpty) {
      await _secureStorage.delete(key: 'subdl_api_key');
    } else {
      await _secureStorage.write(key: 'subdl_api_key', value: value);
    }
  }
}
