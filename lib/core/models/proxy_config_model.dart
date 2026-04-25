import 'dart:convert';

/// Scope for which a proxy configuration applies.
enum ProxyScope {
  /// Proxy used for API discovery and fetching repository data.
  discovery,

  /// Proxy used for downloading release assets.
  download,

  /// Proxy used for translation API calls.
  translation;

  static ProxyScope fromString(String value) {
    return ProxyScope.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ProxyScope.discovery,
    );
  }

  String get displayName => switch (this) {
        ProxyScope.discovery => 'Discovery',
        ProxyScope.download => 'Download',
        ProxyScope.translation => 'Translation',
      };
}

/// Type of proxy configuration.
enum ProxyType {
  /// No proxy is used.
  none,

  /// Use system proxy settings.
  system,

  /// HTTP/HTTPS proxy.
  http,

  /// SOCKS5 proxy.
  socks;

  static ProxyType fromString(String value) {
    return ProxyType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ProxyType.none,
    );
  }

  bool get requiresConfiguration =>
      this == ProxyType.http || this == ProxyType.socks;

  String get displayName => switch (this) {
        ProxyType.none => 'None',
        ProxyType.system => 'System',
        ProxyType.http => 'HTTP/HTTPS',
        ProxyType.socks => 'SOCKS5',
      };
}

/// Proxy configuration model.
class ProxyConfigModel {
  ProxyConfigModel({
    required this.scope,
    required this.type,
    this.host,
    this.port,
    this.username,
    this.password,
  });

  /// Scope for which this proxy applies.
  final ProxyScope scope;

  /// Type of proxy.
  final ProxyType type;

  /// Proxy server hostname or IP address.
  final String? host;

  /// Proxy server port number.
  final int? port;

  /// Username for proxy authentication (optional).
  final String? username;

  /// Password for proxy authentication (optional).
  final String? password;

  /// Whether this proxy config has a host and port set.
  bool get isConfigured =>
      host != null &&
      host!.isNotEmpty &&
      port != null &&
      port! > 0;

  /// Formatted proxy address string.
  String? get formattedAddress {
    if (!isConfigured) return null;
    return '$host:$port';
  }

  /// Full proxy URL for HTTP type.
  String? get proxyUrl {
    if (!isConfigured) return null;
    final userInfo =
        (username != null && username!.isNotEmpty) ? '$username@' : '';
    if (type == ProxyType.http) {
      return 'http://$userInfo$host:$port';
    } else if (type == ProxyType.socks) {
      return 'socks5://$userInfo$host:$port';
    }
    return null;
  }

  ProxyConfigModel copyWith({
    ProxyScope? scope,
    ProxyType? type,
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return ProxyConfigModel(
      scope: scope ?? this.scope,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  /// Create a default proxy config (no proxy, discovery scope).
  factory ProxyConfigModel.defaultForScope(ProxyScope scope) {
    return ProxyConfigModel(
      scope: scope,
      type: ProxyType.none,
    );
  }

  factory ProxyConfigModel.fromJson(Map<String, dynamic> json) {
    return ProxyConfigModel(
      scope: ProxyScope.fromString(json['scope'] as String? ?? 'discovery'),
      type: ProxyType.fromString(json['type'] as String? ?? 'none'),
      host: json['host'] as String?,
      port: json['port'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scope': scope.name,
      'type': type.name,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ProxyConfigModel.fromJsonString(String source) =>
      ProxyConfigModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProxyConfigModel &&
          runtimeType == other.runtimeType &&
          scope == other.scope &&
          type == other.type &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(scope, type, host, port);

  @override
  String toString() =>
      'ProxyConfigModel(scope: ${scope.displayName}, type: ${type.displayName}, '
      'address: ${formattedAddress ?? "none"})';
}
