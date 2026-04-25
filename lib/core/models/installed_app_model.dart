import 'dart:convert';

import 'release_asset_model.dart';

/// Represents a tracked installed application on the user's system.
class InstalledAppModel {
  InstalledAppModel({
    required this.id,
    required this.owner,
    required this.name,
    this.fullName,
    this.installedVersion,
    this.installedAssetUrl,
    this.latestVersion,
    this.installTime,
    this.lastUpdateCheck,
    this.platform = ReleaseAssetPlatform.unknown,
    this.customRegex,
    this.fallbackToOlder = false,
    this.variantFingerprint,
    this.globPatterns = const [],
    this.installedAssetName,
    this.installedAt,
    this.uninstalledAt,
    this.installMethod,
  });

  /// Local database ID (auto-increment).
  final int id;

  /// Repository owner login.
  final String owner;

  /// Repository name.
  final String name;

  /// Full repository name in format "owner/name".
  final String? fullName;

  /// Currently installed version/tag.
  final String? installedVersion;

  /// URL of the asset that was installed.
  final String? installedAssetUrl;

  /// Name of the asset that was installed.
  final String? installedAssetName;

  /// Latest available version/tag from GitHub releases.
  final String? latestVersion;

  /// Whether an update is available (latestVersion != installedVersion).
  bool get isUpdateAvailable =>
      latestVersion != null &&
      installedVersion != null &&
      latestVersion != installedVersion;

  /// When the app was installed.
  final DateTime? installTime;

  /// When the app was last checked for updates.
  final DateTime? lastUpdateCheck;

  /// Detected platform of the installed app.
  final ReleaseAssetPlatform platform;

  /// Custom regex pattern for matching release assets.
  final String? customRegex;

  /// Whether to fall back to an older release if the latest doesn't match.
  final bool fallbackToOlder;

  /// Variant fingerprint for distinguishing between app variants.
  final String? variantFingerprint;

  /// Glob patterns for finding installed files on disk.
  final List<String> globPatterns;

  /// Installation method used (msi, exe, dmg, pkg, deb, rpm, appimage, etc.).
  final String? installMethod;

  /// When the app was installed (alias for installTime for DB compat).
  final DateTime? installedAt;

  /// When the app was uninstalled (null if still installed).
  final DateTime? uninstalledAt;

  /// Whether the app is currently installed (not uninstalled).
  bool get isInstalled => uninstalledAt == null;

  /// Full name with fallback.
  String get effectiveFullName => fullName ?? '$owner/$name';

  /// Platform display name.
  String get platformDisplayName => platform.displayName;

  InstalledAppModel copyWith({
    int? id,
    String? owner,
    String? name,
    String? fullName,
    String? installedVersion,
    String? installedAssetUrl,
    String? installedAssetName,
    String? latestVersion,
    bool? isUpdateAvailable,
    DateTime? installTime,
    DateTime? lastUpdateCheck,
    ReleaseAssetPlatform? platform,
    String? customRegex,
    bool? fallbackToOlder,
    String? variantFingerprint,
    List<String>? globPatterns,
    String? installMethod,
    DateTime? installedAt,
    DateTime? uninstalledAt,
  }) {
    return InstalledAppModel(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      installedVersion: installedVersion ?? this.installedVersion,
      installedAssetUrl: installedAssetUrl ?? this.installedAssetUrl,
      installedAssetName: installedAssetName ?? this.installedAssetName,
      latestVersion: latestVersion ?? this.latestVersion,
      installTime: installTime ?? this.installTime,
      lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
      platform: platform ?? this.platform,
      customRegex: customRegex ?? this.customRegex,
      fallbackToOlder: fallbackToOlder ?? this.fallbackToOlder,
      variantFingerprint: variantFingerprint ?? this.variantFingerprint,
      globPatterns: globPatterns ?? this.globPatterns,
      installMethod: installMethod ?? this.installMethod,
      installedAt: installedAt ?? this.installedAt,
      uninstalledAt: uninstalledAt ?? this.uninstalledAt,
    );
  }

  factory InstalledAppModel.fromJson(Map<String, dynamic> json) {
    return InstalledAppModel(
      id: json['id'] as int,
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String?,
      installedVersion: json['installed_version'] as String?,
      installedAssetUrl: json['installed_asset_url'] as String?,
      installedAssetName: json['installed_asset_name'] as String?,
      latestVersion: json['latest_version'] as String?,
      installTime: json['install_time'] != null
          ? DateTime.tryParse(json['install_time'] as String)
          : null,
      lastUpdateCheck: json['last_update_check'] != null
          ? DateTime.tryParse(json['last_update_check'] as String)
          : null,
      platform: ReleaseAssetPlatform.values.firstWhere(
        (e) => e.name == (json['platform'] as String? ?? 'unknown'),
        orElse: () => ReleaseAssetPlatform.unknown,
      ),
      customRegex: json['custom_regex'] as String?,
      fallbackToOlder: json['fallback_to_older'] as bool? ?? false,
      variantFingerprint: json['variant_fingerprint'] as String?,
      globPatterns: (json['glob_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      installMethod: json['install_method'] as String?,
      installedAt: json['installed_at'] != null
          ? DateTime.tryParse(json['installed_at'] as String)
          : null,
      uninstalledAt: json['uninstalled_at'] != null
          ? DateTime.tryParse(json['uninstalled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'name': name,
      if (fullName != null) 'full_name': fullName,
      if (installedVersion != null) 'installed_version': installedVersion,
      if (installedAssetUrl != null) 'installed_asset_url': installedAssetUrl,
      if (installedAssetName != null)
        'installed_asset_name': installedAssetName,
      if (latestVersion != null) 'latest_version': latestVersion,
      if (installTime != null)
        'install_time': installTime!.toUtc().toIso8601String(),
      if (lastUpdateCheck != null)
        'last_update_check': lastUpdateCheck!.toUtc().toIso8601String(),
      'platform': platform.name,
      if (customRegex != null) 'custom_regex': customRegex,
      'fallback_to_older': fallbackToOlder,
      if (variantFingerprint != null)
        'variant_fingerprint': variantFingerprint,
      'glob_patterns': globPatterns,
      if (installMethod != null) 'install_method': installMethod,
      if (installedAt != null)
        'installed_at': installedAt!.toUtc().toIso8601String(),
      if (uninstalledAt != null)
        'uninstalled_at': uninstalledAt!.toUtc().toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory InstalledAppModel.fromJsonString(String source) =>
      InstalledAppModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledAppModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          owner == other.owner &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, owner, name);

  @override
  String toString() =>
      'InstalledAppModel(fullName: $effectiveFullName, '
      'version: $installedVersion, platform: $platformDisplayName)';
}
