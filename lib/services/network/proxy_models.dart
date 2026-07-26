/// Supported proxy types for connecting to Telegram servers.
enum ProxyType {
  socks5,
  http,
  mtproto,
}

/// A single proxy configuration with latency metadata.
class ProxyConfig {
  final String id;            // Unique identifier (e.g. "manual_1" or "auto_host_port")
  final String host;
  final int port;
  final ProxyType type;
  final String? username;     // Optional auth for SOCKS5/HTTP
  final String? password;     // Optional auth for SOCKS5/HTTP
  final String? secret;       // Optional secret for MTProto proxy
  final String label;         // User-friendly name (e.g. "My VPN Proxy")
  final bool isAutoFetch;     // Whether this was auto-fetched (not manually added)
  final DateTime addedAt;

  // Latency metadata — populated by ping testing
  int? latencyMs;             // Last measured latency in milliseconds
  DateTime? lastPingAt;       // When the last ping was performed

  /// Three-state alive status:
  ///   true  = pinged and responded (green icon)
  ///   false = pinged and failed (red icon)
  ///   null  = not yet tested (grey/neutral icon)
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
    this.isAlive,  // null by default = untested
  });

  ProxyConfig copyWith({
    String? id,
    String? host,
    int? port,
    ProxyType? type,
    String? username,
    String? password,
    String? secret,
    String? label,
    int? latencyMs,
    DateTime? lastPingAt,
    bool? isAlive,
  }) {
    return ProxyConfig(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
      secret: secret ?? this.secret,
      label: label ?? this.label,
      isAutoFetch: isAutoFetch,
      addedAt: addedAt,
      latencyMs: latencyMs ?? this.latencyMs,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      isAlive: isAlive ?? this.isAlive,
    );
  }

  /// Whether this proxy has been tested (pinged) at least once.
  bool get hasBeenTested => isAlive != null;

  /// Whether this proxy is confirmed alive (pinged and responded).
  /// Returns false if untested (isAlive == null).
  bool get confirmedAlive => isAlive == true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'host': host,
    'port': port,
    'type': type.name,
    'username': username,
    'password': password,
    'secret': secret,
    'label': label,
    'isAutoFetch': isAutoFetch,
    'addedAt': addedAt.toIso8601String(),
    'latencyMs': latencyMs,
    'lastPingAt': lastPingAt?.toIso8601String(),
    'isAlive': isAlive,
  };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
    id: json['id'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    type: ProxyType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ProxyType.socks5,
    ),
    username: json['username'] as String?,
    password: json['password'] as String?,
    secret: json['secret'] as String?,
    label: json['label'] as String? ?? '',
    isAutoFetch: json['isAutoFetch'] as bool? ?? false,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    latencyMs: json['latencyMs'] as int?,
    lastPingAt: json['lastPingAt'] != null
        ? DateTime.tryParse(json['lastPingAt'] as String)
        : null,
    // Handle both old (bool) and new (bool?) serialization
    isAlive: json['isAlive'] as bool?,
  );

  /// Short description like "SOCKS5 1.2.3.4:1080" for display.
  String get shortDescription => '${type.name.toUpperCase()} $host:$port';
}

/// Overall connection state for the proxy manager.
enum ConnectionStatus {
  disconnected,  // No proxy active
  connecting,    // Proxy is being established
  connected,     // Proxy is active and working
  failed,        // Proxy connection failed
}
