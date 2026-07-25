
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

  Future<void> _pingAll() async {
    await ref.read(proxyManagerProvider.notifier).pingAllProxies();
  }

  Future<void> _autoConnect() async {
    await ref.read(proxyManagerProvider.notifier).autoConnect();
  }

  Future<void> _fetchPublic() async {
    await ref.read(proxyManagerProvider.notifier).fetchPublicProxies();
  }

  Future<void> _connectTo(String id) async {
    await ref.read(proxyManagerProvider.notifier).connectToProxy(id);
  }

  Future<void> _disconnect() async {
    await ref.read(proxyManagerProvider.notifier).disconnect();
  }

  Future<void> _removeProxy(String id) async {
    await ref.read(proxyManagerProvider.notifier).removeProxy(id);
  }

  void _showAddProxyDialog() {
    final hostController = TextEditingController();
    final portController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final labelController = TextEditingController();
    ProxyType selectedType = ProxyType.socks5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Proxy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (e.g. "My VPN")',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host (e.g. 1.2.3.4)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(
                    labelText: 'Port (e.g. 1080)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButton<ProxyType>(
                  value: selectedType,
                  isExpanded: true,
                  items: ProxyType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name.toUpperCase()),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                if (selectedType == ProxyType.socks5 || selectedType == ProxyType.http) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password (optional)',
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                ],
                if (selectedType == ProxyType.mtproto) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Secret',
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final host = hostController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 0;
                if (host.isEmpty || port <= 0) return;

                final proxy = ProxyConfig(
                  id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                  host: host,
                  port: port,
                  type: selectedType,
                  username: usernameController.text.trim(),
                  password: passwordController.text.trim(),
                  label: labelController.text.trim(),
                  addedAt: DateTime.now(),
                );

                ref.read(proxyManagerProvider.notifier).addProxy(proxy);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Color _latencyColor(int? ms) {
    if (ms == null) return Colors.grey;
    if (ms < 100) return Colors.green;
    if (ms < 300) return Colors.orange;
    return Colors.red;
  }

  String _latencyLabel(int? ms) {
    if (ms == null) return '—';
    return '$ms ms';
  }

  IconData _statusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.check_circle;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.failed:
        return Icons.error;
      case ConnectionStatus.disconnected:
        return Icons.cloud_off;
    }
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.failed:
        return Colors.red;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxyState = ref.watch(proxyManagerProvider);
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    final settingsAccent = customTheme?.settingsAccent ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: customTheme?.settingsBackground ?? theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Proxy Settings', style: TextStyle(
          color: textColor, fontWeight: FontWeight.bold,
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Connection Status Card ────────────────────────────────────
          _buildSectionHeader('Connection Status', settingsAccent),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_statusIcon(proxyState.status),
                          color: _statusColor(proxyState.status), size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proxyState.status == ConnectionStatus.connected
                                  ? 'Connected via ${proxyState.activeProxy?.shortDescription ?? "proxy"}'
                                  : proxyState.status == ConnectionStatus.disconnected
                                      ? 'Direct connection (no proxy)'
                                      : proxyState.status == ConnectionStatus.connecting
                                          ? 'Connecting...'
                                          : 'Connection failed',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (proxyState.activeProxy != null && proxyState.activeProxy!.latencyMs != null)
                              Text(
                                'Latency: ${proxyState.activeProxy!.latencyMs} ms',
                                style: TextStyle(color: subColor, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _autoConnect,
                          child: const Text('Auto-Connect'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: proxyState.status == ConnectionStatus.connected
                              ? _disconnect : null,
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Actions ────────────────────────────────────────────────────
          _buildSectionHeader('Actions', settingsAccent),
          Card(
            elevation: 0,
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.network_check, color: settingsAccent),
                  title: Text('Ping All Proxies', style: TextStyle(color: textColor)),
                  subtitle: proxyState.isPinging
                      ? Text('Pinging...', style: TextStyle(color: Colors.orange, fontSize: 12))
                      : Text('Test latency of all saved proxies', style: TextStyle(color: subColor, fontSize: 12)),
                  onTap: proxyState.isPinging ? null : _pingAll,
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.cloud_download, color: settingsAccent),
                  title: Text('Fetch Public Proxies', style: TextStyle(color: textColor)),
                  subtitle: Text('Get free SOCKS5/MTProto proxies', style: TextStyle(color: subColor, fontSize: 12)),
                  onTap: _fetchPublic,
                ),
                Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: settingsAccent),
                  title: Text('Add Manual Proxy', style: TextStyle(color: textColor)),
                  subtitle: Text('Add your own SOCKS5/HTTP/MTProto proxy', style: TextStyle(color: subColor, fontSize: 12)),
                  onTap: _showAddProxyDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Proxy List ─────────────────────────────────────────────────
          _buildSectionHeader('Saved Proxies (${proxyState.proxies.length})', settingsAccent),

          if (proxyState.proxies.isEmpty)
            Card(
              elevation: 0,
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('No proxies saved yet',
                        style: TextStyle(color: subColor, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('Fetch public proxies or add one manually',
                        style: TextStyle(color: subColor, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else
            ...proxyState.sortedProxies.map((proxy) => Card(
              elevation: 0,
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: proxy.id == proxyState.activeProxyId
                      ? settingsAccent
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  width: proxy.id == proxyState.activeProxyId ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  proxy.isAlive ? Icons.check_circle : Icons.cancel,
                  color: proxy.isAlive ? Colors.green : Colors.red,
                  size: 24,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        proxy.label.isNotEmpty ? proxy.label : proxy.shortDescription,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _latencyColor(proxy.latencyMs).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _latencyColor(proxy.latencyMs),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _latencyLabel(proxy.latencyMs),
                        style: TextStyle(
                          color: _latencyColor(proxy.latencyMs),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${proxy.type.name.toUpperCase()} | ${proxy.host}:${proxy.port}'
                  '${proxy.isAutoFetch ? " | Auto-fetched" : ""}',
                  style: TextStyle(color: subColor, fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (proxy.id != proxyState.activeProxyId)
                      IconButton(
                        icon: const Icon(Icons.power_settings_new, size: 20),
                        color: proxy.isAlive ? settingsAccent : Colors.grey,
                        onPressed: proxy.isAlive ? () => _connectTo(proxy.id) : null,
                        tooltip: 'Connect',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent,
                      onPressed: () => _removeProxy(proxy.id),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
