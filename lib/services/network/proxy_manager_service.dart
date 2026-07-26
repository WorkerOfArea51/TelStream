import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage_service.dart';
import '../../core/logger.dart';
import 'proxy_models.dart';
import 'package:tdlib/td_api.dart' as td;
import '../tdlib_service.dart';

/// Result of a public-proxy fetch operation.
///
/// Returned by [ProxyManagerNotifier.fetchPublicProxies] so the UI layer
/// can display a snackbar with the outcome. Previously the function returned
/// `Future<void>`, which made silent failures impossible to distinguish
/// from slow successes — see GitHub issue "still can't fetch public servers".
class ProxyFetchResult {
  final bool success;
  final int fetchedCount;
  final int totalSources;
  final int failedSources;
  final String? errorMessage;

  const ProxyFetchResult({
    required this.success,
    required this.fetchedCount,
    required this.totalSources,
    required this.failedSources,
    this.errorMessage,
  });

  /// Human-readable summary for a snackbar, e.g.
  /// "Fetched 247 proxies from 3 sources" or
  /// "Failed to fetch from any source: network error".
  String get summary {
    if (success) {
      if (failedSources > 0) {
        return 'Fetched $fetchedCount proxies from ${totalSources - failedSources}/$totalSources sources '
            '($failedSources source(s) failed)';
      }
      return 'Fetched $fetchedCount proxies from $totalSources source(s)';
    }
    return 'Failed to fetch proxies: ${errorMessage ?? "unknown error"}';
  }
}

// ─── Riverpod Provider ──────────────────────────────────────────────────────

final proxyManagerProvider = NotifierProvider<ProxyManagerNotifier, ProxyManagerState>(
  ProxyManagerNotifier.new,
);

// ─── State ──────────────────────────────────────────────────────────────────

class ProxyManagerState {
  final List<ProxyConfig> proxies;
  final String? activeProxyId;
  final ConnectionStatus status;
  final bool isPinging;
  final bool isFetching;        // NEW: true while fetchPublicProxies() is running
  final String? autoConnectProxyId;

  const ProxyManagerState({
    this.proxies = const [],
    this.activeProxyId,
    this.status = ConnectionStatus.disconnected,
    this.isPinging = false,
    this.isFetching = false,    // NEW
    this.autoConnectProxyId,
  });

  ProxyConfig? get activeProxy =>
      _firstWhereOrNull(proxies, (p) => p.id == activeProxyId);

  ProxyConfig? get autoConnectProxy =>
      _firstWhereOrNull(proxies, (p) => p.id == autoConnectProxyId);

  /// Proxies sorted by latency (alive first, lowest latency first).
  List<ProxyConfig> get sortedProxies {
    final alive = proxies.where((p) => p.confirmedAlive).toList()
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    final untested = proxies.where((p) => !p.hasBeenTested).toList();
    final dead = proxies.where((p) => p.isAlive == false).toList();
    return [...alive, ...untested, ...dead];
  }

  ProxyManagerState copyWith({
    List<ProxyConfig>? proxies,
    String? activeProxyId,
    ConnectionStatus? status,
    bool? isPinging,
    bool? isFetching,            // NEW
    String? autoConnectProxyId,
    bool clearActiveProxyId = false,
    bool clearAutoConnectProxyId = false,
  }) {
    return ProxyManagerState(
      proxies: proxies ?? this.proxies,
      activeProxyId: clearActiveProxyId ? null : (activeProxyId ?? this.activeProxyId),
      status: status ?? this.status,
      isPinging: isPinging ?? this.isPinging,
      isFetching: isFetching ?? this.isFetching,    // NEW
      autoConnectProxyId: clearAutoConnectProxyId ? null : (autoConnectProxyId ?? this.autoConnectProxyId),
    );
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class ProxyManagerNotifier extends Notifier<ProxyManagerState> {
  @override
  ProxyManagerState build() {
    final storage = ref.read(storageServiceProvider);
    final savedProxies = storage.getProxyList();
    final activeId = storage.getActiveProxyId();

    return ProxyManagerState(
      proxies: savedProxies,
      activeProxyId: activeId.isNotEmpty ? activeId : null,
      status: activeId.isNotEmpty
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected,
    );
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
    if (wasActive) {
      await _saveActiveProxyId('');
      await _removeProxyFromTdlib();
    }
  }

  Future<void> updateProxy(ProxyConfig updated) async {
    state = state.copyWith(
      proxies: state.proxies.map((p) => p.id == updated.id ? updated : p).toList(),
    );
    await _save();
  }

  // ─── Ping Testing ──────────────────────────────────────────────────────

  /// Ping all proxies and update their latency/alive status.
  // ─── Cancel flag for ping operations ──────────────────────────────
  bool _pingCancelled = false;

  /// Cancel an in-progress ping operation. The ping loop will stop
  /// after the current proxy finishes its socket test, preserving
  /// partial results. The UI can call this when the user taps "Cancel".
  void cancelPing() {
    _pingCancelled = true;
    Log.i('[pingAllProxies] Cancel requested — will stop after current proxy');
  }

  /// Ping all proxies and update their latency/alive status.
  ///
  /// Uses concurrency (batches of 20) for speed and supports
  /// cancellation via [cancelPing]. Partial results are preserved
  /// even if cancelled — proxies that were already tested keep their
  /// new latency/alive data.
  ///
  /// The [maxCount] parameter limits how many proxies to ping.
  /// Defaults to 50 to avoid UI hangs. The UI can offer a "Ping All"
  /// option with maxCount=null for a full scan, but the default
  /// quick-ping is capped.
  Future<List<ProxyConfig>> pingAllProxies({int? maxCount = 50}) async {
    if (state.isPinging) return state.sortedProxies;
    _pingCancelled = false;
    state = state.copyWith(isPinging: true);

    // Take only the first maxCount proxies for quick ping,
    // or all if maxCount is null (full scan).
    final toPing = maxCount != null
        ? state.proxies.take(maxCount).toList()
        : state.proxies;

    final results = <ProxyConfig>[];
    const batchSize = 20;

    // Ping in batches of 20 for concurrency without overwhelming
    // the device's socket pool.
    for (int i = 0; i < toPing.length; i += batchSize) {
      if (_pingCancelled) {
        Log.i('[pingAllProxies] Cancelled after ${results.length} proxies');
        break;
      }

      final batch = toPing.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((proxy) => _pingProxy(proxy)),
      );

      results.addAll(batchResults);

      // Update state incrementally so UI shows progress
      final updatedProxies = <ProxyConfig>[
        ...state.proxies.map((p) {
          final pinged = results.where((r) => r.id == p.id).firstOrNull;
          return pinged ?? p;
        }),
      ];
      state = state.copyWith(proxies: updatedProxies);
    }

    // Mark ping as done (whether cancelled or completed)
    state = state.copyWith(isPinging: false);
    _pingCancelled = false;
    await _save();

    // Find the best (lowest latency alive proxy) for auto-connect
    final best = results
        .where((p) => p.confirmedAlive && p.latencyMs != null)
        .fold<ProxyConfig?>(null, (b, p) =>
            b == null || p.latencyMs! < b.latencyMs! ? p : b);

    if (best != null) {
      state = state.copyWith(autoConnectProxyId: best.id);
      Log.i('Auto-connect candidate: ${best.shortDescription} (${best.latencyMs}ms)');
    } else if (!_pingCancelled) {
      // Only warn "no alive" if we actually completed the scan
      state = state.copyWith(clearAutoConnectProxyId: true);
      Log.w('No alive proxies found among ${results.length} tested');
    }

    return state.sortedProxies;
  }

  Future<ProxyConfig> _pingProxy(ProxyConfig proxy) async {
    try {
      final start = DateTime.now();
      final socket = await Socket.connect(
        proxy.host, proxy.port,
        timeout: const Duration(seconds: 5),
      );

      if (proxy.type == ProxyType.socks5) {
        // SOCKS5 handshake: send 0x05 0x01 0x00 (version, 1 method, no-auth)
        // Server responds with 0x05 0x00 if it accepts no-auth
        socket.add([0x05, 0x01, 0x00]);
        await socket.flush();
        final response = await socket.first.timeout(const Duration(seconds: 5));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();
        return proxy.copyWith(
          latencyMs: elapsed,
          lastPingAt: DateTime.now(),
          isAlive: response.isNotEmpty && response[0] == 0x05,
        );
      } else {
        // HTTP and MTProto: measure TCP connect time only
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();
        return proxy.copyWith(
          latencyMs: elapsed,
          lastPingAt: DateTime.now(),
          isAlive: true,
        );
      }
    } catch (e) {
      return proxy.copyWith(
        latencyMs: null,
        lastPingAt: DateTime.now(),
        isAlive: false,
      );
    }
  }

  // ─── Auto-Connect ─────────────────────────────────────────────────────

  /// Connect to the lowest-latency alive proxy. Pings first if needed.
  ///
  /// If the current proxy is already connected and alive, autoconnect
  /// will NOT switch — the user's session stays uninterrupted. Only
  /// switches when the current proxy is dead or there is no active proxy.
  Future<void> autoConnect() async {
    // ─── Guard: don't switch if current proxy is alive ─────────────
    if (state.status == ConnectionStatus.connected &&
        state.activeProxy != null &&
        state.activeProxy!.confirmedAlive) {
      Log.i('Auto-connect: current proxy ${state.activeProxy!.shortDescription} '
            'is alive (${state.activeProxy!.latencyMs}ms) — no switch needed');
      return;
    }

    // ─── If we have no latency data yet, ping first ────────────────
    if (state.proxies.where((p) => p.confirmedAlive).isEmpty) {
      await pingAllProxies();
    }

    // ─── Pick the best alive proxy ─────────────────────────────────
    final best = state.autoConnectProxy;
    if (best != null && best.confirmedAlive) {
      // Only switch if it's different from current, or current is dead
      if (state.activeProxyId == best.id &&
          state.status == ConnectionStatus.connected) {
        Log.i('Auto-connect: already on best proxy ${best.shortDescription}');
        return;
      }
      await connectToProxy(best.id);
    } else {
      state = state.copyWith(status: ConnectionStatus.failed);
      Log.w('No suitable proxy for auto-connect');
    }
  }

  /// Connect to a specific proxy by ID.
  Future<void> connectToProxy(String proxyId) async {
    final proxy = ProxyManagerState._firstWhereOrNull(
        state.proxies, (p) => p.id == proxyId);
    if (proxy == null) return;

    state = state.copyWith(status: ConnectionStatus.connecting);

    final result = await _pingProxy(proxy);
    state = state.copyWith(
      proxies: state.proxies.map((p) => p.id == proxyId ? result : p).toList(),
    );

    if (!result.isAlive) {
      state = state.copyWith(status: ConnectionStatus.failed);
      return;
    }

    state = state.copyWith(
      activeProxyId: proxyId,
      status: ConnectionStatus.connected,
    );
    await _save();
    await _saveActiveProxyId(proxyId);
    await _applyProxyToTdlib(result);
    Log.i('Connected: ${proxy.shortDescription} (${result.latencyMs}ms)');
  }

  /// Disconnect — go direct/no proxy.
  Future<void> disconnect() async {
    state = state.copyWith(
      clearActiveProxyId: true,
      status: ConnectionStatus.disconnected,
    );
    await _saveActiveProxyId('');
    await _removeProxyFromTdlib();
    Log.i('Disconnected — using direct connection');
  }

  // ─── Auto-Fetch ───────────────────────────────────────────────────────

  /// Fetch public proxies from multiple known-good sources, add as
  /// isAutoFetch=true. Returns a [ProxyFetchResult] describing the
  /// outcome so the UI can show a snackbar.
  ///
  /// Each source is a [_ProxySource] with a URL, a [ProxyType], and a
  /// format hint (plain text `ip:port` per line, or JSON array).
  ///
  /// For each source:
  ///   1. Fetch with a 15-second timeout.
  ///   2. Verify HTTP 200 (treat 404/500/etc. as a failed source).
  ///   3. Parse the body according to the format hint.
  ///   4. Deduplicate by `host:port` across all sources.
  ///
  /// Does NOT auto-ping the fetched proxies — pinging 500+ proxies with
  /// a 5s timeout each would hang the UI for minutes. The user can tap
  /// "Ping All Proxies" manually after the fetch completes.
  ///
  /// If `raw.githubusercontent.com` is unreachable (blocked in some
  /// regions), the jsdelivr CDN mirror is used as a fallback.
  Future<ProxyFetchResult> fetchPublicProxies() async {
    // Guard against concurrent fetches — without this, spam-tapping the
    // button would race and corrupt the proxy list.
    if (state.isFetching) {
      return const ProxyFetchResult(
        success: false,
        fetchedCount: 0,
        totalSources: 0,
        failedSources: 0,
        errorMessage: 'A fetch is already in progress',
      );
    }

    state = state.copyWith(isFetching: true);
    Log.i('[fetchPublicProxies] Starting fetch from ${_proxySources.length} sources');

    final fetched = <ProxyConfig>[];
    final seenKeys = <String>{};  // dedup by "host:port"
    int failedSources = 0;

    for (final source in _proxySources) {
      try {
        final proxies = await _fetchFromSource(source);
        for (final proxy in proxies) {
          final key = '${proxy.host}:${proxy.port}';
          if (seenKeys.add(key)) {
            fetched.add(proxy);
          }
        }
        Log.i('[fetchPublicProxies] ${source.url}: fetched ${proxies.length} proxies');
      } catch (e) {
        failedSources++;
        Log.w('[fetchPublicProxies] ${source.url} failed: $e');
      }
    }

    // Remove old auto-fetched proxies, keep manual ones, then append the
    // newly fetched (deduplicated) list.
    final manual = state.proxies.where((p) => !p.isAutoFetch).toList();
    state = state.copyWith(
      proxies: [...manual, ...fetched],
      isFetching: false,
    );
    await _save();

    Log.i('[fetchPublicProxies] Done. ${fetched.length} unique proxies '
        'from ${_proxySources.length - failedSources}/${_proxySources.length} sources.');

    return ProxyFetchResult(
      success: fetched.isNotEmpty,
      fetchedCount: fetched.length,
      totalSources: _proxySources.length,
      failedSources: failedSources,
      errorMessage: fetched.isEmpty
          ? 'All ${_proxySources.length} sources failed. Check your network connection.'
          : null,
    );
  }

  /// Fetches and parses a single proxy source. Tries the primary URL
  /// first; if the network call fails (not a 404 — a network-level
  /// failure like a timeout or DNS error), retries via the jsdelivr CDN
  /// mirror for GitHub-hosted sources.
  Future<List<ProxyConfig>> _fetchFromSource(_ProxySource source) async {
    final body = await _httpGetWithFallback(source.url, source.isGithubRaw);
    if (body.isEmpty) return [];

    switch (source.format) {
      case _ProxyFormat.plainText:
        return _parsePlainTextSource(body, source.type);
      case _ProxyFormat.jsonArray:
        return _parseJsonSource(body, source.type);
      case _ProxyFormat.mtprotoLinks:
        // MTProto links carry their own type — ignore source.type
        return _parseMtprotoLinksSource(body);
    }
  }

  /// HTTP GET with a 15-second timeout. Verifies HTTP 200. For GitHub
  /// raw URLs, falls back to the jsdelivr CDN mirror on network-level
  /// failure (timeout, DNS error, connection refused). A 404 response
  /// is NOT retried — it means the URL is wrong, not that GitHub is
  /// blocked.
  Future<String> _httpGetWithFallback(String url, bool isGithubRaw) async {
    final primary = await _httpGet(url);
    if (primary != null) return primary;

    if (isGithubRaw) {
      // Convert raw.githubusercontent.com/USER/REPO/BRANCH/PATH →
      // cdn.jsdelivr.net/gh/USER/REPO@BRANCH/PATH
      final jsdelivrUrl = url
          .replaceFirst(
            'https://raw.githubusercontent.com/',
            'https://cdn.jsdelivr.net/gh/',
          )
          .replaceFirst('/main/', '@main/')
          .replaceFirst('/master/', '@master/');
      Log.i('[fetchPublicProxies] Primary failed, trying jsdelivr mirror: $jsdelivrUrl');
      final fallback = await _httpGet(jsdelivrUrl);
      if (fallback != null) return fallback;
    }

    throw Exception('HTTP request failed for $url (and jsdelivr mirror if applicable)');
  }

  /// Performs an HTTP GET with status-code verification. Returns the
  /// response body on HTTP 200, or `null` on any other status code or
  /// network error. Throws on timeout.
  Future<String?> _httpGet(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('HTTP request timed out'),
      );

      if (response.statusCode != 200) {
        Log.w('[fetchPublicProxies] $url returned HTTP ${response.statusCode}');
        // Drain the response to free the connection
        await response.drain<void>();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      return body;
    } on TimeoutException {
      Log.w('[fetchPublicProxies] $url timed out');
      return null;
    } on HttpException catch (e) {
      Log.w('[fetchPublicProxies] $url HTTP exception: $e');
      return null;
    } on SocketException catch (e) {
      Log.w('[fetchPublicProxies] $url socket exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Parses a plain-text source: one `ip:port` per line, ignoring
  /// empty lines and comments (lines starting with `#`).
  List<ProxyConfig> _parsePlainTextSource(String body, ProxyType type) {
    final proxies = <ProxyConfig>[];
    final lines = body.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // Accept "ip:port" or "ip : port" (with whitespace)
      final parts = line.split(':');
      if (parts.length != 2) continue;

      final host = parts[0].trim();
      final port = int.tryParse(parts[1].trim());
      if (host.isEmpty || port == null || port <= 0 || port > 65535) continue;

      proxies.add(ProxyConfig(
        id: 'auto_${host}_$port',
        host: host,
        port: port,
        type: type,
        label: 'Public ${type.name.toUpperCase()} $host:$port',
        isAutoFetch: true,
        addedAt: DateTime.now(),
      ));
    }
    return proxies;
  }

  /// Parses a JSON-array source: `[{"ip":"1.2.3.4","port":1080}, ...]`.
  /// Also accepts `{"host": "...", "port": ...}` and
  /// `{"server": "...", "port": ...}` field names for compatibility.
  List<ProxyConfig> _parseJsonSource(String body, ProxyType type) {
    final proxies = <ProxyConfig>[];
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return proxies;

      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final host = map['ip'] as String? ??
            map['host'] as String? ??
            map['server'] as String?;
        // Port can be int or string in some sources
        final portRaw = map['port'];
        final port = portRaw is int
            ? portRaw
            : portRaw is String
                ? int.tryParse(portRaw)
                : null;

        if (host == null || port == null || port <= 0 || port > 65535) continue;

        // Allow the source to override the type per-entry if present
        final typeStr = (map['type'] as String? ?? '').toLowerCase();
        final entryType = typeStr == 'http'
            ? ProxyType.http
            : typeStr == 'mtproto'
                ? ProxyType.mtproto
                : type;

        proxies.add(ProxyConfig(
          id: 'auto_${host}_$port',
          host: host,
          port: port,
          type: entryType,
          username: map['username'] as String?,
          password: map['password'] as String?,
          secret: map['secret'] as String?,
          label: 'Public ${entryType.name.toUpperCase()} $host:$port',
          isAutoFetch: true,
          addedAt: DateTime.now(),
        ));
      }
    } catch (e) {
      Log.w('[fetchPublicProxies] JSON parse error: $e');
    }
    return proxies;
  }

  /// Parses an MTProto-links source: one Telegram proxy deep-link per
  /// line, in either of these formats:
  ///
  ///   https://t.me/proxy?server=HOST&port=PORT&secret=SECRET
  ///   tg://proxy?server=HOST&port=PORT&secret=SECRET
  ///
  /// This is the format used by `SoliSpirit/mtproto/all_proxies.txt`,
  /// the canonical public MTProto proxy list (auto-updated every 12
  /// hours, ~222 entries as of 2026-07-26).
  ///
  /// The `secret` field is passed through verbatim — it can be either
  /// a base64 dd-secret (e.g. `eeNEgYdJvXrFGRMCIMJdCQ`) or a hex TLS
  /// fingerprint secret (e.g. `ee1603010200010001fc030386e24c3add...`).
  /// Both are valid for TDLib's `ProxyTypeMtproto`.
  /// Parses an MTProto-links source supporting TWO formats:
  ///
  /// **Format 1 — Standard deep-links** (used by most Telegram proxy lists):
  ///   https://t.me/proxy?server=HOST&port=PORT&secret=SECRET
  ///   tg://proxy?server=HOST&port=PORT&secret=SECRET
  ///
  /// **Format 2 — Import URLs** (used by SoliSpirit/mtpro/all_proxies.txt):
  ///   https://me.proxy.server.HOST/import?PORT&secret=SECRET
  ///   https://me.proxy.server.HOST.co.uk/import?PORT&secret=SECRET&id=...
  ///
  /// In Format 2, the HOST is embedded in the subdomain path
  /// (`me.proxy.server.<host>/import`) and the PORT is the numeric
  /// query parameter immediately after `?` (before `&secret=...`).
  /// The `secret` field is passed through verbatim.
  ///
  /// Lines that don't match either format are silently skipped.
  List<ProxyConfig> _parseMtprotoLinksSource(String body) {
    final proxies = <ProxyConfig>[];
    final lines = body.split('\n');

    // Regex for standard deep-links (Format 1)
    final deepLinkRegex = RegExp(
      r'^(?:https?://t\.me/proxy\?|tg://proxy\?)(.+)$',
      caseSensitive: false,
    );

    // Regex for import URLs (Format 2)
    // Captures: host from path, port from query, secret from query
    // Pattern: https://me.proxy.server.<host>/import?<port>&secret=<secret>[&...]
    final importRegex = RegExp(
      r'^https?://me\.proxy\.server\.([^/]+)/import\?(\d+)&secret=([a-zA-Z0-9+/=_\-]+)',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      // ─── Try Format 1: Standard deep-link ────────────────────────
      final deepMatch = deepLinkRegex.firstMatch(line);
      if (deepMatch != null) {
        final uri = Uri.tryParse(line);
        if (uri == null) continue;

        final host = uri.queryParameters['server'];
        final portStr = uri.queryParameters['port'];
        final secret = uri.queryParameters['secret'];

        if (host == null || host.isEmpty) continue;
        final port = int.tryParse(portStr ?? '');
        if (port == null || port <= 0 || port > 65535) continue;
        if (secret == null || secret.isEmpty) continue;

        final cleanHost = host.endsWith('.')
            ? host.substring(0, host.length - 1) : host;

        proxies.add(ProxyConfig(
          id: 'auto_mtproto_${cleanHost}_$port',
          host: cleanHost,
          port: port,
          type: ProxyType.mtproto,
          secret: secret,
          label: 'MTProto $cleanHost:$port',
          isAutoFetch: true,
          addedAt: DateTime.now(),
        ));
        continue;  // Parsed successfully, skip Format 2 check
      }

      // ─── Try Format 2: Import URL ────────────────────────────────
      final importMatch = importRegex.firstMatch(line);
      if (importMatch != null) {
        final rawHost = importMatch.group(1)!;
        final port = int.tryParse(importMatch.group(2)!) ?? 0;
        final secret = importMatch.group(3)!;

        if (port <= 0 || port > 65535) continue;
        if (secret.isEmpty) continue;

        // The host in import URLs often contains dots from the domain
        // structure (e.g. "dbavi.co.uk" or "bathlade.sadar.co.uk").
        // Extract just the first meaningful part as the server identifier,
        // or use the full subdomain if it resolves.
        //
        // For MTProto proxy connections, the HOST field must be the
        // actual server hostname that the Telegram client will connect to.
        // In the import URL format, `me.proxy.server.HOST` means HOST
        // is the subdomain that routes to the proxy server.
        //
        // Strategy: use the full path segment after "me.proxy.server."
        // as the host. This includes multi-level subdomains like
        // "dbavi.co.uk" or "bathlade.sadar.co.uk".
        final cleanHost = rawHost.endsWith('.')
            ? rawHost.substring(0, rawHost.length - 1) : rawHost;

        proxies.add(ProxyConfig(
          id: 'auto_mtproto_${cleanHost}_$port',
          host: cleanHost,
          port: port,
          type: ProxyType.mtproto,
          secret: secret,
          label: 'MTProto $cleanHost:$port',
          isAutoFetch: true,
          addedAt: DateTime.now(),
        ));
        continue;
      }

      // ─── Neither format matched — skip line ──────────────────────
      Log.w('[parseMtprotoLinks] Unrecognized line format: $line');
    }
    return proxies;
  }

  Future<void> clearAutoFetchedProxies() async {
    state = state.copyWith(
      proxies: state.proxies.where((p) => !p.isAutoFetch).toList(),
    );
    await _save();
  }

  // ─── TDLib Wiring ─────────────────────────────────────────────────────

  Future<void> _applyProxyToTdlib(ProxyConfig proxy) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    
    td.ProxyType tdProxy;
    if (proxy.type == ProxyType.socks5) {
      tdProxy = td.ProxyTypeSocks5(
        username: proxy.username ?? '',
        password: proxy.password ?? '',
      );
    } else if (proxy.type == ProxyType.mtproto) {
      tdProxy = td.ProxyTypeMtproto(secret: proxy.secret ?? '');
    } else {
      tdProxy = td.ProxyTypeHttp(
        username: proxy.username ?? '',
        password: proxy.password ?? '',
        httpOnly: false,
      );
    }

    await tdlibService.sendAsync(td.AddProxy(
      server: proxy.host,
      port: proxy.port,
      enable: true,
      type: tdProxy,
    ));
  }

  Future<void> _removeProxyFromTdlib() async {
    final tdlibService = ref.read(tdlibServiceProvider);
    await tdlibService.sendAsync(const td.DisableProxy());
  }

  // ─── Persistence ──────────────────────────────────────────────────────

  Future<void> _save() async {
    ref.read(storageServiceProvider).saveProxyList(state.proxies);
  }

  Future<void> _saveActiveProxyId(String id) async {
    ref.read(storageServiceProvider).setActiveProxyId(id);
  }
}

// ─── Proxy Source Configuration ─────────────────────────────────────────────

/// Format of a proxy-list source.
enum _ProxyFormat {
  /// Plain text: one `ip:port` per line. Empty lines and `#`-comments ignored.
  plainText,

  /// JSON array: `[{"ip":"1.2.3.4","port":1080}, ...]`.
  jsonArray,

  /// MTProto links: handles TWO formats:
  ///   1. Standard deep-links: `tg://proxy?server=...&port=...&secret=...`
  ///      or `https://t.me/proxy?server=...&port=...&secret=...`
  ///   2. Import URLs: `https://me.proxy.server.<subdomain>/import?<port>&secret=...`
  ///      used by the SoliSpirit/mtpro source.
  mtprotoLinks,
}

/// A single public-proxy source.
class _ProxySource {
  final String url;
  final ProxyType type;
  final _ProxyFormat format;

  /// True if this is a `raw.githubusercontent.com` URL (eligible for
  /// jsdelivr CDN fallback).
  final bool isGithubRaw;

  const _ProxySource({
    required this.url,
    required this.type,
    required this.format,
    this.isGithubRaw = false,
  });
}

/// The list of public-proxy sources to fetch from.
///
/// These URLs were verified to return HTTP 200 on 2026-07-26.
/// If a source goes down in the future, the fetch will gracefully
/// skip it and continue with the remaining sources.
const List<_ProxySource> _proxySources = [
  // ─── MTProto sources ──────────────────────────────────────────────

  // PRIMARY: SoliSpirit/mtpro — canonical MTProto proxy list, auto-updated
  // every 12 hours. The repo name is "mtpro" (not "mtproto").
  // NOTE: This source uses the me.proxy.server URL format, parsed by
  // the new _parseMtprotoImportSource method.
  _ProxySource(
    url: 'https://raw.githubusercontent.com/SoliSpirit/mtpro/master/all_proxies.txt',
    type: ProxyType.mtproto,
    format: _ProxyFormat.mtprotoLinks,  // Updated parser handles both formats
    isGithubRaw: true,
  ),

  // SECONDARY: fallback MTProto deep-link source in standard t.me/tg:// format.
  // Some older Telegram proxy lists use the traditional deep-link format,
  // which the regex-based parser handles well.
  _ProxySource(
    url: 'https://raw.githubusercontent.com/free-proxy-list/telegram-proxy-list/main/proxies.txt',
    type: ProxyType.mtproto,
    format: _ProxyFormat.mtprotoLinks,
    isGithubRaw: true,
  ),

  // ─── SOCKS5 sources ───────────────────────────────────────────────
  _ProxySource(
    url: 'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/socks5.txt',
    type: ProxyType.socks5,
    format: _ProxyFormat.plainText,
    isGithubRaw: true,
  ),
  _ProxySource(
    url: 'https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/socks5.txt',
    type: ProxyType.socks5,
    format: _ProxyFormat.plainText,
    isGithubRaw: true,
  ),

  // ─── HTTP sources ─────────────────────────────────────────────────
  _ProxySource(
    url: 'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt',
    type: ProxyType.http,
    format: _ProxyFormat.plainText,
    isGithubRaw: true,
  ),

  // ─── Non-GitHub fallback ──────────────────────────────────────────
  _ProxySource(
    url: 'https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000',
    type: ProxyType.socks5,
    format: _ProxyFormat.plainText,
    isGithubRaw: false,
  ),
];
