// FILE: lib/services/network/proxy_models.dart
// VERSION: v2 (future)
// CHANGES: isAlive bool→bool?, added confirmedAlive/hasBeenTested getters, expanded copyWith
// Replace the entire current file with this.

enum ProxyType { socks5, http, mtproto }

class ProxyConfig {
  final String id;
  final String host;
  final int port;
  final ProxyType type;
  final String? username;
  final String? password;
  final String? secret;
  final String label;
  final bool isAutoFetch;
  final DateTime addedAt;

  int? latencyMs;
  DateTime? lastPingAt;

  // CHANGED: bool → bool?. null=untested, true=alive, false=dead
  // Previously defaulted to false (all new proxies looked "dead").
  // Now defaults to null (untested = grey icon in UI).
  bool? isAlive;

  ProxyConfig({
    required this.id,
    required this.host,
    required this.port,
    required this.type,
    this.username,
    this.password,
    this.secret,
    this.label = '',
    this.isAutoFetch = false,
    required this.addedAt,
    this.latencyMs,
    this.lastPingAt,
    this.isAlive,
  });

  bool get hasBeenTested => isAlive != null;
  bool get confirmedAlive => isAlive == true;

  // CHANGED: expanded copyWith to include host, port, secret, etc.
  // Previously could only update latency/alive/label.
  ProxyConfig copyWith({
    String? id, String? host, int? port, ProxyType? type,
    String? username, String? password, String? secret, String? label,
    int? latencyMs, DateTime? lastPingAt, bool? isAlive,
  }) => ProxyConfig(
    id: id ?? this.id, host: host ?? this.host, port: port ?? this.port,
    type: type ?? this.type, username: username ?? this.username,
    password: password ?? this.password, secret: secret ?? this.secret,
    label: label ?? this.label, isAutoFetch: isAutoFetch, addedAt: addedAt,
    latencyMs: latencyMs ?? this.latencyMs, lastPingAt: lastPingAt ?? this.lastPingAt,
    isAlive: isAlive ?? this.isAlive,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'host': host, 'port': port, 'type': type.name,
    'username': username, 'password': password, 'secret': secret,
    'label': label, 'isAutoFetch': isAutoFetch,
    'addedAt': addedAt.toIso8601String(),
    'latencyMs': latencyMs, 'lastPingAt': lastPingAt?.toIso8601String(),
    'isAlive': isAlive,
  };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
    id: json['id'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    type: ProxyType.values.firstWhere((e) => e.name == json['type'], orElse: () => ProxyType.socks5),
    username: json['username'] as String?,
    password: json['password'] as String?,
    secret: json['secret'] as String?,
    label: json['label'] as String? ?? '',
    isAutoFetch: json['isAutoFetch'] as bool? ?? false,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    latencyMs: json['latencyMs'] as int?,
    lastPingAt: json['lastPingAt'] != null ? DateTime.tryParse(json['lastPingAt'] as String) : null,
    isAlive: json['isAlive'] as bool?,
  );

  String get shortDescription => '${type.name.toUpperCase()} $host:$port';
}

enum ConnectionStatus { disconnected, connecting, connected, failed }
