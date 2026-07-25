import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../l10n/app_localizations.dart';

import '../../services/storage_service.dart';
import '../../core/logger.dart';

class ProxySettingsScreen extends ConsumerStatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  ConsumerState<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends ConsumerState<ProxySettingsScreen> {
  bool _proxyEnabled = false;
  String _proxyType = 'socks5';
  
  final _serverController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mtprotoSecretController = TextEditingController();
  
  bool _autoFetch = false;
  bool _isFetching = false;
  List<Map<String, dynamic>> _fetchedProxies = [];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _mtprotoSecretController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final storage = ref.read(storageServiceProvider);
    setState(() {
      _proxyEnabled = storage.getProxyEnabled();
      _proxyType = storage.getProxyType();
      
      _serverController.text = storage.getProxyServer();
      _portController.text = storage.getProxyPort().toString();
      _usernameController.text = storage.getProxyUsername();
      _passwordController.text = storage.getProxyPassword();
      _mtprotoSecretController.text = storage.getMtprotoSecret();
      
      _autoFetch = storage.getProxyAutoFetch();
    });
  }

  void _saveSettings() {
    final storage = ref.read(storageServiceProvider);
    storage.setProxyEnabled(_proxyEnabled);
    storage.setProxyType(_proxyType);
    
    storage.setProxyServer(_serverController.text.trim());
    storage.setProxyPort(int.tryParse(_portController.text.trim()) ?? 1080);
    storage.setProxyUsername(_usernameController.text.trim());
    storage.setProxyPassword(_passwordController.text.trim());
    storage.setMtprotoSecret(_mtprotoSecretController.text.trim());
    
    storage.setProxyAutoFetch(_autoFetch);
  }

  Future<void> _fetchMtprotoProxies() async {
    setState(() => _isFetching = true);
    try {
      final response = await http.get(Uri.parse('https://raw.githubusercontent.com/SoliSpirit/mtproto/main/proxy-list.json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            _fetchedProxies = data.cast<Map<String, dynamic>>();
          });
        } else if (data is Map && data.containsKey('proxies')) {
          setState(() {
            _fetchedProxies = (data['proxies'] as List).cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      Log.e('Failed to fetch MTProto proxies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch proxy list: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  void _applyProxy(Map<String, dynamic> proxyData) {
    setState(() {
      _serverController.text = proxyData['server']?.toString() ?? '';
      _portController.text = proxyData['port']?.toString() ?? '443';
      _mtprotoSecretController.text = proxyData['secret']?.toString() ?? '';
      _proxyEnabled = true;
    });
    _saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proxy applied successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.proxySettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(l10n.proxyEnabled),
            subtitle: Text(l10n.proxyRequiredInBannedRegions),
            value: _proxyEnabled,
            onChanged: (val) {
              setState(() => _proxyEnabled = val);
              _saveSettings();
            },
          ),
          const Divider(),
          
          ListTile(
            title: Text(l10n.proxyType),
            trailing: DropdownButton<String>(
              value: _proxyType,
              items: [
                DropdownMenuItem(value: 'socks5', child: Text(l10n.socks5)),
                DropdownMenuItem(value: 'mtproto', child: Text(l10n.mtproto)),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _proxyType = val);
                  _saveSettings();
                }
              },
            ),
          ),
          
          TextField(
            controller: _serverController,
            decoration: InputDecoration(
              labelText: l10n.proxyServer,
              hintText: 'e.g. 192.168.1.1',
            ),
            onChanged: (_) => _saveSettings(),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: l10n.proxyPort,
              hintText: 'e.g. 1080',
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _saveSettings(),
          ),
          const SizedBox(height: 16),
          
          if (_proxyType == 'socks5') ...[
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.proxyUsername,
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l10n.proxyPassword,
              ),
              obscureText: true,
              onChanged: (_) => _saveSettings(),
            ),
          ] else if (_proxyType == 'mtproto') ...[
            TextField(
              controller: _mtprotoSecretController,
              decoration: InputDecoration(
                labelText: l10n.mtprotoSecret,
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(l10n.autoFetchProxy),
              value: _autoFetch,
              onChanged: (val) {
                setState(() => _autoFetch = val);
                _saveSettings();
                if (val && _fetchedProxies.isEmpty) {
                  _fetchMtprotoProxies();
                }
              },
            ),
            if (_autoFetch) ...[
              ElevatedButton.icon(
                onPressed: _isFetching ? null : _fetchMtprotoProxies,
                icon: _isFetching 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(l10n.fetchProxies),
              ),
              const SizedBox(height: 16),
              if (_fetchedProxies.isNotEmpty) ...[
                const Text('Available Proxies:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  height: 200,
                  child: ListView.builder(
                    itemCount: _fetchedProxies.length,
                    itemBuilder: (context, index) {
                      final proxy = _fetchedProxies[index];
                      return ListTile(
                        dense: true,
                        title: Text('${proxy['server']}:${proxy['port']}'),
                        subtitle: Text(proxy['secret']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: ElevatedButton(
                          onPressed: () => _applyProxy(proxy),
                          child: const Text('Use'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
