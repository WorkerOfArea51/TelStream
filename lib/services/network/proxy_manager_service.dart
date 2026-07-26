// FILE: lib/services/network/proxy_manager_service.dart
// VERSION: v2 (future)
// CHANGES:
//   1. Added ProxyFetchResult class + isFetching state field
//   2. fetchPublicProxies: 6 sources (MTProto/SOCKS5/HTTP/JSON/ProxyScrape), jsdelivr CDN fallback,
//      no auto-ping after fetch, returns ProxyFetchResult for UI snackbar, concurrent-fetch guard
//   3. pingAllProxies: cancel mechanism, batched concurrency (20), maxCount parameter (default 50),
//      incremental state updates for live progress
//   4. autoConnect: guard clause — won't switch if current proxy is alive
//   5. All p.isAlive → p.confirmedAlive (matches new bool? model)
//   6. HttpClient always closed in finally block (fixes resource leak)
//   7. Added _ProxyFormat enum + dual-format MTProto parser (deep-links + import URLs)
// Replace the entire current file with this.

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage_service.dart';
import '../../core/logger.dart';
import 'proxy_models.dart';
import 'package:tdlib/td_api.dart' as td;
import '../tdlib_service.dart';

// ─── Fetch Result ────────────────────────────────────────────────────────────

class ProxyFetchResult {
  final bool success;
  final int fetchedCount;
  final int totalSources;
  final int failedSources;
  final String? errorMessage;
  const ProxyFetchResult({required this.success, required this.fetchedCount,
    required this.totalSources, required this.failedSources, this.errorMessage});
  String get summary {
    if (success) {
      if (failedSources > 0) return 'Fetched $fetchedCount proxies from ${totalSources - failedSources}/$totalSources sources ($failedSources failed)';
      return 'Fetched $fetchedCount proxies from $totalSources source(s)';
    }
    return 'Failed: ${errorMessage ?? "unknown error"}';
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final proxyManagerProvider = NotifierProvider<ProxyManagerNotifier, ProxyManagerState>(
  ProxyManagerNotifier.new,
);

// ─── State ───────────────────────────────────────────────────────────────────

class ProxyManagerState {
  final List<ProxyConfig> proxies;
  final String? activeProxyId;
  final ConnectionStatus status;
  final bool isPinging;
  final bool isFetching;          // NEW
  final String? autoConnectProxyId;
  final int? tdlibProxyId;

  const ProxyManagerState({this.proxies = const [], this.activeProxyId,
    this.status = ConnectionStatus.disconnected, this.isPinging = false,
    this.isFetching = false, this.autoConnectProxyId, this.tdlibProxyId});

  ProxyConfig? get activeProxy => _firstWhereOrNull(proxies, (p) => p.id == activeProxyId);
  ProxyConfig? get autoConnectProxy => _firstWhereOrNull(proxies, (p) => p.id == autoConnectProxyId);

  // CHANGED: three-tier sort — alive > untested > dead
  List<ProxyConfig> get sortedProxies {
    final alive = proxies.where((p) => p.confirmedAlive).toList()
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    final untested = proxies.where((p) => !p.hasBeenTested).toList();
    final dead = proxies.where((p) => p.isAlive == false).toList();
    return [...alive, ...untested, ...dead];
  }

  ProxyManagerState copyWith({List<ProxyConfig>? proxies, String? activeProxyId,
    ConnectionStatus? status, bool? isPinging, bool? isFetching,
    String? autoConnectProxyId, int? tdlibProxyId, bool clearActiveProxyId = false,
    bool clearAutoConnectProxyId = false, bool clearTdlibProxyId = false}) =>
    ProxyManagerState(
      proxies: proxies ?? this.proxies,
      activeProxyId: clearActiveProxyId ? null : (activeProxyId ?? this.activeProxyId),
      status: status ?? this.status,
      isPinging: isPinging ?? this.isPinging,
      isFetching: isFetching ?? this.isFetching,
      autoConnectProxyId: clearAutoConnectProxyId ? null : (autoConnectProxyId ?? this.autoConnectProxyId),
      tdlibProxyId: clearTdlibProxyId ? null : (tdlibProxyId ?? this.tdlibProxyId),
    );

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) { if (test(item)) return item; }
    return null;
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ProxyManagerNotifier extends Notifier<ProxyManagerState> {
  @override
  ProxyManagerState build() {
    final storage = ref.read(storageServiceProvider);
    final savedProxies = storage.getProxyList();
    final activeId = storage.getActiveProxyId();
    return ProxyManagerState(
      proxies: savedProxies,
      activeProxyId: activeId.isNotEmpty ? activeId : null,
      status: ConnectionStatus.disconnected,
    );
  }

  Future<void> restoreSavedProxy() async {
    if (state.activeProxyId == null) {
      Log.i('No saved proxy to restore');
      return;
    }
    
    final proxy = state.activeProxy;
    if (proxy == null) return;

    // Ping first to verify proxy still alive
    final pingResult = await _pingProxy(proxy);
    if (!pingResult.confirmedAlive) {
      // Don't clear saved ID --- proxy might come back later
      state = state.copyWith(status: ConnectionStatus.failed);
      return;
    }
    
    // Apply to TDLib
    final tdlibProxyId = await _applyProxyToTdlib(proxy);
    state = state.copyWith(status: ConnectionStatus.connected, tdlibProxyId: tdlibProxyId);
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────

  Future<void> addProxy(ProxyConfig proxy) async {
    state = state.copyWith(proxies: [...state.proxies, proxy]);
    await _save();
    Log.i('Added proxy: ${proxy.shortDescription}');
  }

  Future<void> removeProxy(String proxyId) async {
    final wasActive = state.activeProxyId == proxyId;
    state = state.copyWith(
      proxies: state.proxies.where((p) => p.id != proxyId).toList(),
      clearActiveProxyId: wasActive,
      status: wasActive ? ConnectionStatus.disconnected : state.status,
    );
    await _save();
    if (wasActive) { await _saveActiveProxyId(''); await _removeProxyFromTdlib(); }
  }

  Future<void> updateProxy(ProxyConfig updated) async {
    state = state.copyWith(proxies: state.proxies.map((p) => p.id == updated.id ? updated : p).toList());
    await _save();
  }

  // ─── Ping Testing ──────────────────────────────────────────────────────

  bool _pingCancelled = false;

  void cancelPing() { _pingCancelled = true; Log.i('[ping] Cancel requested'); }

  // CHANGED: cancel support, batched concurrency, maxCount, incremental updates
  Future<List<ProxyConfig>> pingAllProxies({int? maxCount = 50}) async {
    if (state.isPinging) return state.sortedProxies;
    _pingCancelled = false;
    state = state.copyWith(isPinging: true);

    final toPing = maxCount != null ? state.proxies.take(maxCount).toList() : state.proxies;
    final results = <ProxyConfig>[];
    const batchSize = 20;

    for (int i = 0; i < toPing.length; i += batchSize) {
      if (_pingCancelled) { Log.i('[ping] Cancelled after ${results.length}'); break; }
      final batch = toPing.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch.map((p) => _pingProxy(p)));
      results.addAll(batchResults);

      // Incremental update so UI shows live progress
      state = state.copyWith(proxies: state.proxies.map((p) {
        final pinged = results.where((r) => r.id == p.id).firstOrNull;
        return pinged ?? p;
      }).toList());
    }

    state = state.copyWith(isPinging: false);
    _pingCancelled = false;
    await _save();

    final best = results.where((p) => p.confirmedAlive && p.latencyMs != null)
        .fold<ProxyConfig?>(null, (b, p) => b == null || p.latencyMs! < b.latencyMs! ? p : b);
    if (best != null) {
      state = state.copyWith(autoConnectProxyId: best.id);
      Log.i('Auto-connect candidate: ${best.shortDescription} (${best.latencyMs}ms)');
    } else if (!_pingCancelled) {
      state = state.copyWith(clearAutoConnectProxyId: true);
      Log.w('No alive proxies found');
    }
    return state.sortedProxies;
  }

  Future<ProxyConfig> _pingProxy(ProxyConfig proxy) async {
    try {
      final start = DateTime.now();
      final socket = await Socket.connect(proxy.host, proxy.port, timeout: const Duration(seconds: 5));
      if (proxy.type == ProxyType.socks5) {
        socket.add([0x05, 0x01, 0x00]);
        await socket.flush();
        final response = await socket.first.timeout(const Duration(seconds: 5));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();
        final isAlive = response.length >= 2 && response[0] == 0x05 && response[1] == 0x00;
        return proxy.copyWith(latencyMs: elapsed, lastPingAt: DateTime.now(),
          isAlive: isAlive);
      } else {
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();
        return proxy.copyWith(latencyMs: elapsed, lastPingAt: DateTime.now(), isAlive: true);
      }
    } catch (e) {
      return proxy.copyWith(latencyMs: null, lastPingAt: DateTime.now(), isAlive: false);
    }
  }

  // ─── Auto-Connect ─────────────────────────────────────────────────────

  // CHANGED: guard clause — won't switch if current proxy is alive
  Future<void> autoConnect() async {
    if (state.status == ConnectionStatus.connected &&
        state.activeProxy != null && state.activeProxy!.confirmedAlive) {
      Log.i('Auto-connect: current proxy alive — no switch needed');
      return;
    }
    if (state.proxies.where((p) => p.confirmedAlive).isEmpty) await pingAllProxies();
    final best = state.autoConnectProxy;
    if (best != null && best.confirmedAlive) {
      if (state.activeProxyId == best.id && state.status == ConnectionStatus.connected) return;
      await connectToProxy(best.id);
    } else {
      state = state.copyWith(status: ConnectionStatus.failed);
      Log.w('No suitable proxy for auto-connect');
    }
  }

  Future<void> connectToProxy(String proxyId) async {
    final proxy = ProxyManagerState._firstWhereOrNull(state.proxies, (p) => p.id == proxyId);
    if (proxy == null) return;
    state = state.copyWith(status: ConnectionStatus.connecting);
    final result = await _pingProxy(proxy);
    state = state.copyWith(proxies: state.proxies.map((p) => p.id == proxyId ? result : p).toList());
    if (result.isAlive != true) { state = state.copyWith(status: ConnectionStatus.failed); return; }
    state = state.copyWith(activeProxyId: proxyId, status: ConnectionStatus.connected);
    await _save(); await _saveActiveProxyId(proxyId); 
    
    if (state.tdlibProxyId != null) {
      await _enableExistingTdlibProxy(state.tdlibProxyId!);
    } else {
      final tdlibProxyId = await _applyProxyToTdlib(result);
      state = state.copyWith(tdlibProxyId: tdlibProxyId);
    }
    
    Log.i('Connected: ${proxy.shortDescription} (${result.latencyMs}ms)');
  }

  Future<void> disconnect() async {
    state = state.copyWith(clearActiveProxyId: true, status: ConnectionStatus.disconnected);
    await _saveActiveProxyId(''); await _removeProxyFromTdlib();
    Log.i('Disconnected');
  }

  // ─── Auto-Fetch ───────────────────────────────────────────────────────

  // CHANGED: 6 sources, returns ProxyFetchResult, no auto-ping, jsdelivr fallback, concurrent guard
  Future<ProxyFetchResult> fetchPublicProxies() async {
    if (state.isFetching) {
      return const ProxyFetchResult(success: false, fetchedCount: 0,
        totalSources: 0, failedSources: 0, errorMessage: 'Fetch already in progress');
    }
    state = state.copyWith(isFetching: true);

    final fetched = <ProxyConfig>[];
    final seenKeys = <String>{};
    int failedSources = 0;

    for (final source in _proxySources) {
      try {
        final proxies = await _fetchFromSource(source);
        for (final proxy in proxies) {
          if (seenKeys.add('${proxy.host}:${proxy.port}')) fetched.add(proxy);
        }
      } catch (e) { failedSources++; Log.w('[fetch] ${source.url} failed: $e'); }
    }

    final manual = state.proxies.where((p) => !p.isAutoFetch).toList();
    state = state.copyWith(proxies: [...manual, ...fetched], isFetching: false);
    await _save();

    return ProxyFetchResult(success: fetched.isNotEmpty, fetchedCount: fetched.length,
      totalSources: _proxySources.length, failedSources: failedSources,
      errorMessage: fetched.isEmpty ? 'All sources failed. Check network.' : null);
  }

  // ─── Fetch Infrastructure ────────────────────────────────────────────

  Future<List<ProxyConfig>> _fetchFromSource(_ProxySource source) async {
    final body = await _httpGetWithFallback(source.url, source.isGithubRaw);
    if (body.isEmpty) return [];
    switch (source.format) {
      case _ProxyFormat.plainText: return _parsePlainText(body, source.type);
      case _ProxyFormat.jsonArray: return _parseJson(body, source.type);
      case _ProxyFormat.mtprotoLinks: return _parseMtprotoLinks(body);
    }
  }

  Future<String> _httpGetWithFallback(String url, bool isGithubRaw) async {
    final primary = await _httpGet(url);
    if (primary != null) return primary;
    if (isGithubRaw) {
      final jsdelivr = url
          .replaceFirst('https://raw.githubusercontent.com/', 'https://cdn.jsdelivr.net/gh/')
          .replaceFirst('/main/', '@main/').replaceFirst('/master/', '@master/');
      final fallback = await _httpGet(jsdelivr);
      if (fallback != null) return fallback;
    }
    throw Exception('HTTP request failed for $url');
  }

  // CHANGED: always closes HttpClient in finally block
  Future<String?> _httpGet(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Timed out'));
      if (response.statusCode != 200) { await response.drain<void>(); return null; }
      return await response.transform(utf8.decoder).join();
    } on TimeoutException catch (_) { return null; }
      on HttpException catch (_) { return null; }
      on SocketException catch (_) { return null; }
    finally { client.close(); }
  }

  // ─── Parsers ─────────────────────────────────────────────────────────

  List<ProxyConfig> _parsePlainText(String body, ProxyType type) {
    final proxies = <ProxyConfig>[];
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(':');
      if (parts.length != 2) continue;
      final host = parts[0].trim();
      final port = int.tryParse(parts[1].trim());
      if (host.isEmpty || port == null || port <= 0 || port > 65535) continue;
      proxies.add(ProxyConfig(id: 'auto_${host}_$port', host: host, port: port,
        type: type, label: 'Public ${type.name.toUpperCase()} $host:$port',
        isAutoFetch: true, addedAt: DateTime.now()));
    }
    return proxies;
  }

  List<ProxyConfig> _parseJson(String body, ProxyType type) {
    final proxies = <ProxyConfig>[];
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return proxies;
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final host = map['ip'] as String? ?? map['host'] as String? ?? map['server'] as String?;
        final portRaw = map['port'];
        final port = portRaw is int ? portRaw : portRaw is String ? int.tryParse(portRaw) : null;
        if (host == null || port == null || port <= 0 || port > 65535) continue;
        final typeStr = (map['type'] as String? ?? '').toLowerCase();
        final entryType = typeStr == 'http' ? ProxyType.http
            : typeStr == 'mtproto' ? ProxyType.mtproto : type;
        proxies.add(ProxyConfig(id: 'auto_${host}_$port', host: host, port: port,
          type: entryType, username: map['username'] as String?,
          password: map['password'] as String?, secret: map['secret'] as String?,
          label: 'Public ${entryType.name.toUpperCase()} $host:$port',
          isAutoFetch: true, addedAt: DateTime.now()));
      }
    } catch (e) { Log.w('[parseJson] Error: $e'); }
    return proxies;
  }

  // CHANGED: dual-format parser — handles both tg://proxy AND me.proxy.server import URLs
  List<ProxyConfig> _parseMtprotoLinks(String body) {
    final proxies = <ProxyConfig>[];
    final deepLinkRx = RegExp(r'^(?:https?://t\.me/proxy\?|tg://proxy\?)(.+)$', caseSensitive: false);
    final importRx = RegExp(r'^https?://me\.proxy\.server\.([^/]+)/import\?(\d+)&secret=([a-zA-Z0-9+/=_\-]+)',
      caseSensitive: false);

    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // Format 1: tg://proxy?server=...&port=...&secret=...
      final deepMatch = deepLinkRx.firstMatch(line);
      if (deepMatch != null) {
        final uri = Uri.tryParse(line);
        if (uri == null) continue;
        final host = uri.queryParameters['server'];
        final port = int.tryParse(uri.queryParameters['port'] ?? '');
        final secret = uri.queryParameters['secret'];
        if (host == null || host.isEmpty || port == null || port <= 0 || port > 65535) continue;
        if (secret == null || secret.isEmpty) continue;
        final clean = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
        proxies.add(ProxyConfig(id: 'auto_mtproto_${clean}_$port', host: clean, port: port,
          type: ProxyType.mtproto, secret: secret, label: 'MTProto $clean:$port',
          isAutoFetch: true, addedAt: DateTime.now()));
        continue;
      }

      // Format 2: https://me.proxy.server.HOST/import?PORT&secret=SECRET
      final importMatch = importRx.firstMatch(line);
      if (importMatch != null) {
        final rawHost = importMatch.group(1)!;
        final port = int.tryParse(importMatch.group(2)!) ?? 0;
        final secret = importMatch.group(3)!;
        if (port <= 0 || port > 65535 || secret.isEmpty) continue;
        final clean = rawHost.endsWith('.') ? rawHost.substring(0, rawHost.length - 1) : rawHost;
        proxies.add(ProxyConfig(id: 'auto_mtproto_${clean}_$port', host: clean, port: port,
          type: ProxyType.mtproto, secret: secret, label: 'MTProto $clean:$port',
          isAutoFetch: true, addedAt: DateTime.now()));
      }
    }
    return proxies;
  }

  Future<void> clearAutoFetchedProxies() async {
    final activeProxy = state.activeProxy;
    if (activeProxy != null && activeProxy.isAutoFetch) {
      await disconnect();
    }
    state = state.copyWith(proxies: state.proxies.where((p) => !p.isAutoFetch).toList());
    await _save();
  }

  // ─── TDLib ────────────────────────────────────────────────────────────

  Future<int?> _applyProxyToTdlib(ProxyConfig proxy) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    td.ProxyType tdProxy;
    if (proxy.type == ProxyType.socks5) {
      tdProxy = td.ProxyTypeSocks5(username: proxy.username ?? '', password: proxy.password ?? '');
    } else if (proxy.type == ProxyType.mtproto) {
      tdProxy = td.ProxyTypeMtproto(secret: proxy.secret ?? '');
    } else {
      tdProxy = td.ProxyTypeHttp(username: proxy.username ?? '', password: proxy.password ?? '', httpOnly: false);
    }
    final result = await tdlibService.sendAsync(td.AddProxy(server: proxy.host, port: proxy.port, enable: true, type: tdProxy));
    if (result is td.Proxy) {
      return result.id;
    }
    return null;
  }

  Future<void> _enableExistingTdlibProxy(int proxyId) async {
    await ref.read(tdlibServiceProvider).sendAsync(td.EnableProxy(proxyId: proxyId));
  }

  Future<void> _removeProxyFromTdlib() async {
    await ref.read(tdlibServiceProvider).sendAsync(const td.DisableProxy());
  }

  // ─── Persistence ──────────────────────────────────────────────────────

  Future<void> _save() async => ref.read(storageServiceProvider).saveProxyList(state.proxies);
  Future<void> _saveActiveProxyId(String id) async => ref.read(storageServiceProvider).setActiveProxyId(id);
}

// ─── Source Configuration ────────────────────────────────────────────────────

enum _ProxyFormat { plainText, jsonArray, mtprotoLinks }

class _ProxySource {
  final String url; final ProxyType type; final _ProxyFormat format; final bool isGithubRaw;
  const _ProxySource({required this.url, required this.type, required this.format, this.isGithubRaw = false});
}

const _proxySources = [
  // MTProto — PRIMARY source for bypassing Telegram DPI censorship
  _ProxySource(url: 'https://raw.githubusercontent.com/SoliSpirit/mtproto/main/list',
    type: ProxyType.mtproto, format: _ProxyFormat.plainText, isGithubRaw: true),
  // SOCKS5
  _ProxySource(url: 'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt',
    type: ProxyType.socks5, format: _ProxyFormat.plainText, isGithubRaw: true),
  _ProxySource(url: 'https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks5.txt',
    type: ProxyType.socks5, format: _ProxyFormat.plainText, isGithubRaw: true),
  // HTTP
  _ProxySource(url: 'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt',
    type: ProxyType.http, format: _ProxyFormat.plainText, isGithubRaw: true),
  // JSON (original source, kept for compatibility)
  _ProxySource(url: 'https://raw.githubusercontent.com/free-proxy-list/free-proxy-list/main/proxies.json',
    type: ProxyType.socks5, format: _ProxyFormat.jsonArray, isGithubRaw: true),
  // Non-GitHub fallback
  _ProxySource(url: 'https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000',
    type: ProxyType.socks5, format: _ProxyFormat.plainText, isGithubRaw: false),
];
