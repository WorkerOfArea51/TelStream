import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage_service.dart';
import '../../core/logger.dart';
import 'proxy_models.dart';
import 'package:tdlib/td_api.dart' as td;
import '../tdlib_service.dart';

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
  final String? autoConnectProxyId;
  final int? tdlibProxyId;  // [Bug #4] Cache TDLib-assigned proxy ID for EnableProxy

  const ProxyManagerState({
    this.proxies = const [],
    this.activeProxyId,
    this.status = ConnectionStatus.disconnected,
    this.isPinging = false,
    this.autoConnectProxyId,
    this.tdlibProxyId,
  });

  ProxyConfig? get activeProxy =>
      _firstWhereOrNull(proxies, (p) => p.id == activeProxyId);

  ProxyConfig? get autoConnectProxy =>
      _firstWhereOrNull(proxies, (p) => p.id == autoConnectProxyId);

  /// Proxies sorted by latency (alive first, lowest latency first).
  List<ProxyConfig> get sortedProxies {
    final alive = proxies.where((p) => p.isAlive).toList()
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    final dead = proxies.where((p) => !p.isAlive).toList();
    return [...alive, ...dead];
  }

  ProxyManagerState copyWith({
    List<ProxyConfig>? proxies,
    String? activeProxyId,
    ConnectionStatus? status,
    bool? isPinging,
    String? autoConnectProxyId,
    int? tdlibProxyId,
    bool clearActiveProxyId = false,
    bool clearAutoConnectProxyId = false,
    bool clearTdlibProxyId = false,
  }) {
    return ProxyManagerState(
      proxies: proxies ?? this.proxies,
      activeProxyId: clearActiveProxyId ? null : (activeProxyId ?? this.activeProxyId),
      status: status ?? this.status,
      isPinging: isPinging ?? this.isPinging,
      autoConnectProxyId: clearAutoConnectProxyId ? null : (autoConnectProxyId ?? this.autoConnectProxyId),
      tdlibProxyId: clearTdlibProxyId ? null : (tdlibProxyId ?? this.tdlibProxyId),
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

    // [Bug #1 FIX] Always start as disconnected — the proxy hasn't been
    // applied to TDLib yet, so claiming "connected" is a lie.
    // restoreSavedProxy() (called from auth_controller after TDLib init)
    // will set status to connected once it actually applies the proxy.
    return ProxyManagerState(
      proxies: savedProxies,
      activeProxyId: activeId.isNotEmpty ? activeId : null,
      status: ConnectionStatus.disconnected,  // ← honest state
    );
  }

  // ─── [Bug #1 FIX] Restore saved proxy on app restart ──────────────────

  /// Called by auth_controller AFTER TDLib init completes.
  /// Pings the saved proxy, verifies it is alive, and applies it to TDLib
  /// BEFORE TDLib attempts its first network connection.
  Future<void> restoreSavedProxy() async {
    if (state.activeProxyId == null) {
      Log.i('No saved proxy to restore');
      return;
    }

    final proxy = state.activeProxy;
    if (proxy == null) {
      Log.w('Saved proxy ID exists but proxy not found in list');
      return;
    }

    state = state.copyWith(status: ConnectionStatus.connecting);

    // Ping first to verify proxy is still alive
    final pingResult = await _pingProxy(proxy);

    // Update the proxy's alive status in the state
    state = state.copyWith(
      proxies: state.proxies.map((p) => p.id == proxy.id ? pingResult : p).toList(),
    );

    if (!pingResult.isAlive) {
      // Don't clear saved ID — proxy might come back later
      state = state.copyWith(status: ConnectionStatus.failed);
      Log.w('Saved proxy is dead: ${proxy.shortDescription}');
      return;
    }

    // Apply to TDLib
    final tdlibProxyId = await _applyProxyToTdlib(pingResult);
    state = state.copyWith(
      status: ConnectionStatus.connected,
      tdlibProxyId: tdlibProxyId,
    );
    Log.i('Restored proxy: ${proxy.shortDescription} (${pingResult.latencyMs}ms)');
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
      clearTdlibProxyId: wasActive,  // [Bug #4] Clear cached TDLib ID too
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
  Future<List<ProxyConfig>> pingAllProxies() async {
    if (state.isPinging) return state.sortedProxies;
    state = state.copyWith(isPinging: true);

    final results = <ProxyConfig>[];
    for (final proxy in state.proxies) {
      results.add(await _pingProxy(proxy));
    }

    state = state.copyWith(proxies: results, isPinging: false);
    await _save();

    // Find the best (lowest latency alive proxy) for auto-connect
    final best = results
        .where((p) => p.isAlive && p.latencyMs != null)
        .fold<ProxyConfig?>(null, (b, p) =>
            b == null || p.latencyMs! < b.latencyMs! ? p : b);

    if (best != null) {
      state = state.copyWith(autoConnectProxyId: best.id);
      Log.i('Auto-connect: ${best.shortDescription} (${best.latencyMs}ms)');
    } else {
      state = state.copyWith(clearAutoConnectProxyId: true);
      Log.w('No alive proxies found');
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
        // Server responds with [0x05, 0x00] if it accepts no-auth
        // Server responds with [0x05, 0xFF] if it rejects no-auth
        socket.add([0x05, 0x01, 0x00]);
        await socket.flush();
        final response = await socket.first.timeout(const Duration(seconds: 5));
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        socket.destroy();

        // [Bug #3 FIX] Check BOTH version byte AND method byte.
        // A server that rejects no-auth responds with [0x05, 0xFF].
        // Only checking response[0] == 0x05 would falsely mark it as alive.
        final isAlive = response.length >= 2
            && response[0] == 0x05   // SOCKS5 version
            && response[1] == 0x00;  // Server accepts no-auth method

        return proxy.copyWith(
          latencyMs: elapsed,
          lastPingAt: DateTime.now(),
          isAlive: isAlive,
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
  Future<void> autoConnect() async {
    if (state.proxies.where((p) => p.isAlive).isEmpty) {
      await pingAllProxies();
    }
    final best = state.autoConnectProxy;
    if (best != null && best.isAlive) {
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

    // [Bug #4 FIX] If we already have a cached TDLib proxy ID, use EnableProxy
    // instead of AddProxy. This prevents duplicate proxy entries in TDLib.
    if (state.tdlibProxyId != null) {
      await _enableExistingTdlibProxy(state.tdlibProxyId!);
      Log.i('Re-connected (EnableProxy): ${proxy.shortDescription} (${result.latencyMs}ms)');
    } else {
      // First connection — AddProxy and cache the returned ID
      final tdlibId = await _applyProxyToTdlib(result);
      if (tdlibId != null) {
        state = state.copyWith(tdlibProxyId: tdlibId);
      }
      Log.i('Connected (AddProxy): ${proxy.shortDescription} (${result.latencyMs}ms)');
    }
  }

  /// Disconnect — go direct/no proxy.
  Future<void> disconnect() async {
    state = state.copyWith(
      clearActiveProxyId: true,
      clearTdlibProxyId: true,  // [Bug #4] Clear cached TDLib ID on disconnect
      status: ConnectionStatus.disconnected,
    );
    await _saveActiveProxyId('');
    await _removeProxyFromTdlib();
    Log.i('Disconnected — using direct connection');
  }

  // ─── Auto-Fetch ───────────────────────────────────────────────────────

  /// Fetch public proxies from known sources, add as isAutoFetch=true.
  Future<void> fetchPublicProxies() async {
    // [Bug #5 FIX] Added SoliSpirit/mtproto as primary source
    // (Telegram-specific MTProto proxies advertised in changelog).
    const sources = [
      // Telegram-specific MTProto proxies
      'https://raw.githubusercontent.com/SoliSpirit/mtproto/main/list',
      // Generic SOCKS5 proxies
      'https://raw.githubusercontent.com/free-proxy-list/free-proxy-list/main/proxies.json',
    ];

    final fetched = <ProxyConfig>[];
    for (final url in sources) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close();

        final uri = Uri.parse(url);
        // [Bug #5 FIX] Detect format: MTProto list is plain text (server:port:secret),
        // generic proxy lists are JSON.
        final isPlainText = uri.path.contains('list') || uri.path.contains('mtproto');

        if (isPlainText) {
          // Parse SoliSpirit plain text format: each line is host:port:secret
          // The secret may contain colons (dd-prefix), so everything after
          // the second colon is the secret.
          final lines = body.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

            final parts = trimmed.split(':');
            if (parts.length < 3) continue;

            final host = parts[0];
            final port = int.tryParse(parts[1]);
            if (port == null) continue;

            // Everything after host:port is the secret (may contain colons)
            final secret = parts.sublist(2).join(':');

            fetched.add(ProxyConfig(
              id: 'auto_${host}_$port',
              host: host,
              port: port,
              type: ProxyType.mtproto,
              secret: secret,
              label: 'Public MTPROTO $host:$port',
              isAutoFetch: true,
              addedAt: DateTime.now(),
            ));
          }
        } else {
          // Parse JSON format (free-proxy-list)
          final jsonList = jsonDecode(body) as List;
          for (final item in jsonList) {
            final map = item as Map<String, dynamic>;
            final host = map['ip'] as String? ?? map['host'] as String?;
            final port = map['port'] as int?;
            if (host == null || port == null) continue;

            final typeStr = (map['type'] as String? ?? 'socks5').toLowerCase();
            final type = typeStr == 'http' ? ProxyType.http
                : typeStr == 'mtproto' ? ProxyType.mtproto
                : ProxyType.socks5;

            fetched.add(ProxyConfig(
              id: 'auto_${host}_$port',
              host: host,
              port: port,
              type: type,
              username: map['username'] as String?,
              password: map['password'] as String?,
              secret: map['secret'] as String?,
              label: 'Public ${type.name.toUpperCase()} $host:$port',
              isAutoFetch: true,
              addedAt: DateTime.now(),
            ));
          }
        }
      } catch (e) {
        Log.w('Failed to fetch from $url: $e');
      }
    }

    // Remove old auto-fetched, keep manual ones
    final manual = state.proxies.where((p) => !p.isAutoFetch);
    state = state.copyWith(proxies: [...manual, ...fetched]);
    await _save();

    // Ping the new ones
    await pingAllProxies();
  }

  // [Bug #7 FIX] Disconnect active proxy if it's auto-fetched before clearing
  Future<void> clearAutoFetchedProxies() async {
    final activeProxy = state.activeProxy;
    if (activeProxy != null && activeProxy.isAutoFetch) {
      await disconnect();
    }
    state = state.copyWith(
      proxies: state.proxies.where((p) => !p.isAutoFetch).toList(),
    );
    await _save();
  }

  // ─── TDLib Wiring ─────────────────────────────────────────────────────

  // [Bug #4 FIX] Returns the TDLib-assigned proxy ID so we can cache it
  // and use EnableProxy on reconnects instead of creating duplicates.
  Future<int?> _applyProxyToTdlib(ProxyConfig proxy) async {
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

    final result = await tdlibService.sendAsync(td.AddProxy(
      server: proxy.host,
      port: proxy.port,
      enable: true,
      type: tdProxy,
    ));

    // Cache the TDLib-assigned proxy ID from the AddProxy response
    if (result is td.Proxy) {
      Log.i('TDLib assigned proxy ID: ${result.id}');
      return result.id;
    }

    return null;
  }

  // [Bug #4 FIX] Use EnableProxy on reconnects instead of AddProxy
  Future<void> _enableExistingTdlibProxy(int proxyId) async {
    final tdlibService = ref.read(tdlibServiceProvider);
    await tdlibService.sendAsync(td.EnableProxy(proxyId: proxyId));
    Log.i('Enabled existing TDLib proxy ID: $proxyId');
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
