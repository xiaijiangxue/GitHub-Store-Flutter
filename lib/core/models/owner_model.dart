import 'dart:convert';

/// Represents the owner of a GitHub repository (user or organization).
class OwnerModel {
  const OwnerModel({
    required this.login,
    this.id,
    this.avatarUrl,
    this.url,
    this.type = 'User',
    this.siteAdmin = false,
  });

  final int? id;
  final String login;
  final String? avatarUrl;
  final String? url;
  final String type;
  final bool siteAdmin;

  OwnerModel copyWith({
    int? id,
    String? login,
    String? avatarUrl,
    String? url,
    String? type,
    bool? siteAdmin,
  }) {
    return OwnerModel(
      id: id ?? this.id,
      login: login ?? this.login,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      url: url ?? this.url,
      type: type ?? this.type,
      siteAdmin: siteAdmin ?? this.siteAdmin,
    );
  }

  factory OwnerModel.fromJson(Map<String, dynamic> json) {
    return OwnerModel(
      id: json['id'] as int?,
      login: json['login'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      url: json['html_url'] as String? ?? json['url'] as String?,
      type: json['type'] as String? ?? 'User',
      siteAdmin: json['site_admin'] as bool? ?? false,
    );
  }

  /// Parse from a nested owner JSON, handling both flat and nested formats.
  ///
  /// Some endpoints return `owner.login` while others have nested objects.
  factory OwnerModel.fromRepoJson(Map<String, dynamic> json) {
    if (json['owner'] is Map<String, dynamic>) {
      return OwnerModel.fromJson(json['owner'] as Map<String, dynamic>);
    }
    return OwnerModel.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'login': login,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (url != null) 'url': url,
      'type': type,
      'site_admin': siteAdmin,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory OwnerModel.fromJsonString(String source) =>
      OwnerModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          login == other.login;

  @override
  int get hashCode => Object.hash(id, login);

  @override
  String toString() => 'OwnerModel(login: $login, type: $type)';
}
