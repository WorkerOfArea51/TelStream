// FILE: lib/features/settings/proxy_settings_screen.dart
// VERSION: v2 (future)
// CHANGES:
//   1. Cancel button during ping, progress display (alive/total count)
//   2. Fetch feedback: snackbar with ProxyFetchResult + retry button
//   3. Fetch loading indicator + disabled during fetch (isFetching guard)
//   4. Scan mode selector: Quick Ping (50) vs Full Scan via PopupMenuButton
//   5. Top-10 proxy display + "Show all" button
//   6. Three-state proxy icons: alive=green, dead=red, untested=grey
//   7. Fixed: MTProto secret uses separate secretController (not passwordController)
//   8. Connect button uses confirmedAlive instead of isAlive
// Replace the entire current file with this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/network/proxy_manager_service.dart';
import '../../services/network/proxy_models.dart';
import '../../core/theme/app_theme.dart';

class ProxySettingsScreen extends ConsumerStatefulWidget {
  const ProxySettingsScreen({super.key});
  @override
  ConsumerState<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends ConsumerState<ProxySettingsScreen> {
  bool _fullScan = false;
  bool _showAll = false;

  Future<void> _pingAll() async =>
    ref.read(proxyManagerProvider.notifier).pingAllProxies(maxCount: _fullScan ? null : 50);

  void _cancelPing() => ref.read(proxyManagerProvider.notifier).cancelPing();

  Future<void> _autoConnect() async =>
    ref.read(proxyManagerProvider.notifier).autoConnect();

  // CHANGED: receives ProxyFetchResult, shows snackbar
  Future<void> _fetchPublic() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(proxyManagerProvider.notifier).fetchPublicProxies();
    if (messenger != null && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.summary),
        duration: Duration(seconds: result.success ? 3 : 6),
        behavior: SnackBarBehavior.floating,
        action: result.success ? null : SnackBarAction(label: 'Retry', onPressed: _fetchPublic),
      ));
    }
  }

  Future<void> _connectTo(String id) async =>
    ref.read(proxyManagerProvider.notifier).connectToProxy(id);

  Future<void> _disconnect() async =>
    ref.read(proxyManagerProvider.notifier).disconnect();

  Future<void> _removeProxy(String id) async =>
    ref.read(proxyManagerProvider.notifier).removeProxy(id);

  // CHANGED: separate secretController for MTProto
  void _showAddProxyDialog() {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final secretCtrl = TextEditingController();   // NEW
    final labelCtrl = TextEditingController();
    ProxyType selectedType = ProxyType.socks5;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Add Proxy'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (e.g. "My VPN")', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port', isDense: true), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          DropdownButton<ProxyType>(value: selectedType, isExpanded: true,
            items: ProxyType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => selectedType = v); }),
          if (selectedType == ProxyType.socks5 || selectedType == ProxyType.http) ...[
            const SizedBox(height: 8),
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username (optional)', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Password (optional)', isDense: true), obscureText: true),
          ],
          if (selectedType == ProxyType.mtproto) ...[
            const SizedBox(height: 8),
            TextField(controller: secretCtrl, decoration: const InputDecoration(labelText: 'Secret', isDense: true)),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final host = hostCtrl.text.trim();
            final port = int.tryParse(portCtrl.text.trim()) ?? 0;
            if (host.isEmpty || port <= 0) return;
            final proxy = ProxyConfig(
              id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
              host: host, port: port, type: selectedType,
              username: usernameCtrl.text.trim(),
              password: selectedType == ProxyType.mtproto ? null : passwordCtrl.text.trim(),  // FIXED
              secret: selectedType == ProxyType.mtproto ? secretCtrl.text.trim() : null,      // FIXED
              label: labelCtrl.text.trim(), addedAt: DateTime.now(),
            );
            ref.read(proxyManagerProvider.notifier).addProxy(proxy);
            Navigator.pop(ctx);
          }, child: const Text('Add')),
        ],
      ),
    ));
  }

  Color _latencyColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 100) return Colors.green;
    if (ms < 300) return Colors.orange;
    return Colors.red;
  }
  String _latencyLabel(int? ms) => ms == null ? '—' : '$ms ms';

  IconData _statusIcon(ConnectionStatus s) => switch (s) {
    ConnectionStatus.connected => Icons.check_circle,
    ConnectionStatus.connecting => Icons.sync,
    ConnectionStatus.failed => Icons.error,
    ConnectionStatus.disconnected => Icons.cloud_off,
  };
  Color _statusColor(ConnectionStatus s) => switch (s) {
    ConnectionStatus.connected => Colors.green,
    ConnectionStatus.connecting => Colors.orange,
    ConnectionStatus.failed => Colors.red,
    ConnectionStatus.disconnected => Colors.grey,
  };

  // CHANGED: three-state icons for proxy alive status
  IconData _proxyIcon(ProxyConfig p) => p.isAlive == true ? Icons.check_circle
      : p.isAlive == false ? Icons.cancel : Icons.help_outline;
  Color _proxyIconColor(ProxyConfig p) => p.isAlive == true ? Colors.green
      : p.isAlive == false ? Colors.red : Colors.grey;

  List<ProxyConfig> _getDisplayProxies(ProxyManagerState s) {
    if (_showAll) return s.sortedProxies;
    final alive = s.sortedProxies.where((p) => p.confirmedAlive).take(10).toList();
    if (alive.length < 10) {
      final rest = s.sortedProxies.where((p) => !p.confirmedAlive).take(10 - alive.length).toList();
      return [...alive, ...rest];
    }
    return alive;
  }

  Widget _buildSectionHeader(String title, Color accent) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title.toUpperCase(), style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  @override
  Widget build(BuildContext context) {
    final proxyState = ref.watch(proxyManagerProvider);
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final accent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final aliveCount = proxyState.proxies.where((p) => p.confirmedAlive).length;
    final totalCount = proxyState.proxies.length;

    return Scaffold(
      backgroundColor: customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Proxy Settings', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ─── Connection Status ─────────────────────────────────
        _buildSectionHeader('Connection Status', accent),
        Card(elevation: 0, color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Icon(_statusIcon(proxyState.status), color: _statusColor(proxyState.status), size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(proxyState.status == ConnectionStatus.connected
                    ? 'Connected via ${proxyState.activeProxy?.shortDescription ?? "proxy"}'
                    : proxyState.status == ConnectionStatus.disconnected ? 'Direct connection (no proxy)'
                    : proxyState.status == ConnectionStatus.connecting ? 'Connecting...' : 'Connection failed',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
                if (proxyState.activeProxy != null && proxyState.activeProxy!.latencyMs != null)
                  Text('Latency: ${proxyState.activeProxy!.latencyMs} ms', style: TextStyle(color: subColor, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _autoConnect, child: const Text('Auto-Connect'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: proxyState.status == ConnectionStatus.connected ? _disconnect : null,
                child: const Text('Disconnect'))),
            ]),
          ])),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('Actions', accent),
        Card(elevation: 0, color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
          child: Column(children: [
            // ─── Ping (cancel + progress + scan mode) ───────
            ListTile(
              leading: proxyState.isPinging
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(accent)))
                : Icon(Icons.network_check, color: accent),
              title: Text('Ping Proxies', style: TextStyle(color: textColor)),
              subtitle: proxyState.isPinging
                ? Text('$aliveCount/$totalCount alive', style: TextStyle(color: Colors.orange, fontSize: 12))
                : Text(_fullScan ? 'Full scan: ALL proxies (slower)' : 'Quick ping: top 50 (~5 sec)',
                    style: TextStyle(color: subColor, fontSize: 12)),
              // CHANGED: tap to cancel when pinging, tap to start when idle
              onTap: proxyState.isPinging ? _cancelPing : (proxyState.isFetching ? null : _pingAll),
              trailing: proxyState.isPinging
                ? TextButton(onPressed: _cancelPing, child: Text('Cancel', style: TextStyle(color: Colors.redAccent)))
                : PopupMenuButton<bool>(icon: Icon(Icons.more_vert, color: subColor),
                    onSelected: (isFull) { setState(() => _fullScan = isFull); _pingAll(); },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: false, child: Text('Quick Ping (top 50)')),
                      const PopupMenuItem(value: true, child: Text('Full Scan (all proxies)')),
                    ]),
            ),
            Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
            // ─── Fetch (loading indicator + disabled during fetch) ──
            ListTile(
              leading: proxyState.isFetching
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(accent)))
                : Icon(Icons.cloud_download, color: accent),
              title: Text('Fetch Public Proxies', style: TextStyle(color: textColor)),
              subtitle: Text(proxyState.isFetching ? 'Fetching from sources...'
                  : 'Get free MTProto/SOCKS5/HTTP proxies',
                style: TextStyle(color: proxyState.isFetching ? accent : subColor, fontSize: 12)),
              onTap: proxyState.isFetching ? null : _fetchPublic,
            ),
            Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
            ListTile(leading: Icon(Icons.add_circle_outline, color: accent),
              title: Text('Add Manual Proxy', style: TextStyle(color: textColor)),
              subtitle: Text('Add SOCKS5/HTTP/MTProto', style: TextStyle(color: subColor, fontSize: 12)),
              onTap: _showAddProxyDialog),
          ]),
        ),

        const SizedBox(height: 24),
        // ─── Proxy List (top 10 + expand) ────────────────────
        _buildSectionHeader('Saved Proxies ($totalCount) — $aliveCount alive', accent),

        if (proxyState.proxies.isEmpty)
          Card(elevation: 0, color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
            child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No proxies saved yet', style: TextStyle(color: subColor, fontSize: 14)),
              const SizedBox(height: 8),
              Text('Fetch public proxies or add manually', style: TextStyle(color: subColor, fontSize: 12)),
            ]))),
          )
        else
          ..._getDisplayProxies(proxyState).map((proxy) => Card(elevation: 0, color: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: proxy.id == proxyState.activeProxyId ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: proxy.id == proxyState.activeProxyId ? 2 : 1)),
            child: ListTile(
              leading: Icon(_proxyIcon(proxy), color: _proxyIconColor(proxy), size: 24),
              title: Row(children: [
                Expanded(child: Text(proxy.label.isNotEmpty ? proxy.label : proxy.shortDescription,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _latencyColor(proxy.latencyMs).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _latencyColor(proxy.latencyMs))),
                  child: Text(_latencyLabel(proxy.latencyMs), style: TextStyle(
                    color: _latencyColor(proxy.latencyMs), fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
              subtitle: Text('${proxy.type.name.toUpperCase()} | ${proxy.host}:${proxy.port}'
                '${proxy.isAutoFetch ? " | Auto-fetched" : ""}', style: TextStyle(color: subColor, fontSize: 11)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // CHANGED: confirmedAlive instead of isAlive
                if (proxy.id != proxyState.activeProxyId && proxy.confirmedAlive)
                  IconButton(icon: const Icon(Icons.power_settings_new, size: 20), color: accent,
                    onPressed: () => _connectTo(proxy.id), tooltip: 'Connect'),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20), color: Colors.redAccent,
                  onPressed: () => _removeProxy(proxy.id), tooltip: 'Remove'),
              ]),
            ),
          )),
        if (totalCount > 10 && !_showAll)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(onPressed: () => setState(() => _showAll = true),
              child: Text('Show all $totalCount proxies'))),
        if (_showAll && totalCount > 10)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(onPressed: () => setState(() => _showAll = false),
              child: const Text('Show top 10 only'))),
      ]),
    );
  }
}
