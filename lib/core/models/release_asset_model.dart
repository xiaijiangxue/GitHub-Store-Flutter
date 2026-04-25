import 'dart:convert';

/// Detected platform from release asset file name.
enum ReleaseAssetPlatform {
  android,
  macos,
  windows,
  linux,
  ios,
  unknown;

  static ReleaseAssetPlatform fromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('android') ||
        lower.contains('.apk') ||
        lower.contains('aarch64-android')) {
      return ReleaseAssetPlatform.android;
    }
    if (lower.contains('macos') ||
        lower.contains('darwin') ||
        lower.contains('.dmg') ||
        lower.contains('.app') ||
        lower.contains('.pkg')) {
      return ReleaseAssetPlatform.macos;
    }
    if (lower.contains('windows') ||
        lower.contains('win32') ||
        lower.contains('.exe') ||
        lower.contains('.msi') ||
        lower.contains('.msix')) {
      return ReleaseAssetPlatform.windows;
    }
    if (lower.contains('linux') ||
        lower.contains('.deb') ||
        lower.contains('.rpm') ||
        lower.contains('.appimage') ||
        lower.contains('.snap') ||
        lower.contains('.flatpak')) {
      return ReleaseAssetPlatform.linux;
    }
    if (lower.contains('ios') ||
        lower.contains('.ipa')) {
      return ReleaseAssetPlatform.ios;
    }
    return ReleaseAssetPlatform.unknown;
  }

  String get displayName => switch (this) {
        ReleaseAssetPlatform.android => 'Android',
        ReleaseAssetPlatform.macos => 'macOS',
        ReleaseAssetPlatform.windows => 'Windows',
        ReleaseAssetPlatform.linux => 'Linux',
        ReleaseAssetPlatform.ios => 'iOS',
        ReleaseAssetPlatform.unknown => 'Unknown',
      };
}

/// Detected CPU architecture from release asset file name.
enum ReleaseAssetArchitecture {
  arm64,
  x86_64,
  universal,
  unknown;

  static ReleaseAssetArchitecture fromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('arm64') ||
        lower.contains('aarch64') ||
        lower.contains('armv8')) {
      return ReleaseAssetArchitecture.arm64;
    }
    if (lower.contains('x86_64') ||
        lower.contains('amd64') ||
        lower.contains('x64') ||
        lower.contains('64bit') ||
        lower.contains('64-bit')) {
      return ReleaseAssetArchitecture.x86_64;
    }
    if (lower.contains('universal') ||
        lower.contains('fat') ||
        lower.contains('all_arch')) {
      return ReleaseAssetArchitecture.universal;
    }
    // Detect via file extension patterns (macOS universal binaries)
    if (lower.endsWith('.dmg') && !lower.contains('arm') && !lower.contains('intel')) {
      return ReleaseAssetArchitecture.universal;
    }
    return ReleaseAssetArchitecture.unknown;
  }

  String get displayName => switch (this) {
        ReleaseAssetArchitecture.arm64 => 'ARM64',
        ReleaseAssetArchitecture.x86_64 => 'x86_64',
        ReleaseAssetArchitecture.universal => 'Universal',
        ReleaseAssetArchitecture.unknown => 'Unknown',
      };
}

/// Represents a single downloadable asset from a GitHub release.
class ReleaseAssetModel {
  ReleaseAssetModel({
    required this.id,
    required this.name,
    this.label,
    this.contentType,
    this.downloadUrl,
    this.size = 0,
    this.platform = ReleaseAssetPlatform.unknown,
    this.architecture = ReleaseAssetArchitecture.unknown,
    this.downloadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? label;
  final String? contentType;
  final String? downloadUrl;

  /// File size in bytes.
  final int size;

  /// Detected platform based on the asset filename.
  final ReleaseAssetPlatform platform;

  /// Detected CPU architecture based on the asset filename.
  final ReleaseAssetArchitecture architecture;

  /// Number of times this asset has been downloaded.
  final int downloadCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReleaseAssetModel copyWith({
    int? id,
    String? name,
    String? label,
    String? contentType,
    String? downloadUrl,
    int? size,
    ReleaseAssetPlatform? platform,
    ReleaseAssetArchitecture? architecture,
    int? downloadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReleaseAssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      label: label ?? this.label,
      contentType: contentType ?? this.contentType,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      size: size ?? this.size,
      platform: platform ?? this.platform,
      architecture: architecture ?? this.architecture,
      downloadCount: downloadCount ?? this.downloadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Human-readable file size string.
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  factory ReleaseAssetModel.fromJson(Map<String, dynamic> json) {
    return ReleaseAssetModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      label: json['label'] as String?,
      contentType: json['content_type'] as String?,
      downloadUrl: json['browser_download_url'] as String?,
      size: json['size'] as int? ?? 0,
      platform: ReleaseAssetPlatform.fromName(json['name'] as String? ?? ''),
      architecture:
          ReleaseAssetArchitecture.fromName(json['name'] as String? ?? ''),
      downloadCount: json['download_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (label != null) 'label': label,
      if (contentType != null) 'content_type': contentType,
      if (downloadUrl != null) 'browser_download_url': downloadUrl,
      'size': size,
      'platform': platform.name,
      'architecture': architecture.name,
      'download_count': downloadCount,
      if (createdAt != null)
        'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null)
        'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ReleaseAssetModel.fromJsonString(String source) =>
      ReleaseAssetModel.fromJson(
          jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseAssetModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() =>
      'ReleaseAssetModel(name: $name, platform: ${platform.displayName}, '
      'arch: ${architecture.displayName}, size: $formattedSize)';
}
