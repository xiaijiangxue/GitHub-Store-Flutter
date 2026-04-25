import 'dart:convert';

import 'owner_model.dart';
import 'release_asset_model.dart';
import 'release_model.dart';

/// Detected platform enum used by RepositoryModel.
enum RepositoryPlatform {
  android,
  macos,
  windows,
  linux,
  crossPlatform,
  unknown;

  static RepositoryPlatform detect(List<String> topics, String language) {
    final topicStr = topics.join(' ').toLowerCase();

    if (topicStr.contains('android') ||
        language.toLowerCase() == 'kotlin' && topicStr.contains('mobile')) {
      return RepositoryPlatform.android;
    }
    if (topicStr.contains('macos') || topicStr.contains('darwin')) {
      return RepositoryPlatform.macos;
    }
    if (topicStr.contains('windows') || topicStr.contains('win32')) {
      return RepositoryPlatform.windows;
    }
    if (topicStr.contains('linux')) {
      return RepositoryPlatform.linux;
    }
    // Check for cross-platform indicators
    final crossPlatformKeywords = [
      'cross-platform',
      'multi-platform',
      'desktop',
      'flutter',
      'electron',
      'tauri',
      'react-native',
    ];
    if (crossPlatformKeywords.any((k) => topicStr.contains(k))) {
      return RepositoryPlatform.crossPlatform;
    }
    return RepositoryPlatform.unknown;
  }

  String get displayName => switch (this) {
        RepositoryPlatform.android => 'Android',
        RepositoryPlatform.macos => 'macOS',
        RepositoryPlatform.windows => 'Windows',
        RepositoryPlatform.linux => 'Linux',
        RepositoryPlatform.crossPlatform => 'Cross-Platform',
        RepositoryPlatform.unknown => 'Unknown',
      };

  String get iconAsset => switch (this) {
        RepositoryPlatform.android => 'assets/icons/platform_android.svg',
        RepositoryPlatform.macos => 'assets/icons/platform_macos.svg',
        RepositoryPlatform.windows => 'assets/icons/platform_windows.svg',
        RepositoryPlatform.linux => 'assets/icons/platform_linux.svg',
        RepositoryPlatform.crossPlatform => 'assets/icons/platform_cross.svg',
        RepositoryPlatform.unknown => 'assets/icons/platform_unknown.svg',
      };
}

/// Compact latest-release info embedded in a repository listing.
class LatestReleaseInfo {
  const LatestReleaseInfo({
    this.tag,
    this.name,
    this.publishedAt,
    this.assets = const [],
  });

  final String? tag;
  final String? name;
  final DateTime? publishedAt;
  final List<ReleaseAssetModel> assets;

  factory LatestReleaseInfo.fromJson(Map<String, dynamic> json) {
    return LatestReleaseInfo(
      tag: json['tag'] as String? ?? json['tag_name'] as String?,
      name: json['name'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((e) =>
                  ReleaseAssetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tag != null) 'tag': tag,
      if (name != null) 'name': name,
      if (publishedAt != null)
        'published_at': publishedAt!.toUtc().toIso8601String(),
      'assets': assets.map((a) => a.toJson()).toList(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory LatestReleaseInfo.fromJsonString(String source) =>
      LatestReleaseInfo.fromJson(jsonDecode(source) as Map<String, dynamic>);

  bool get isNotEmpty => tag != null && tag!.isNotEmpty;
}

/// License information for a repository.
class LicenseInfo {
  const LicenseInfo({
    this.key,
    this.name,
    this.spdxId,
    this.url,
  });

  final String? key;
  final String? name;
  final String? spdxId;
  final String? url;

  /// SPDX identifier or the full name if SPDX is unavailable.
  String get displayName => spdxId ?? name ?? key ?? 'No License';

  factory LicenseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LicenseInfo();
    return LicenseInfo(
      key: json['key'] as String?,
      name: json['name'] as String?,
      spdxId: json['spdx_id'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (spdxId != null) 'spdx_id': spdxId,
      if (url != null) 'url': url,
    };
  }

  @override
  String toString() => 'LicenseInfo($displayName)';
}

/// Comprehensive GitHub repository data model.
class RepositoryModel {
  RepositoryModel({
    required this.id,
    required this.name,
    required this.fullName,
    this.owner,
    this.description,
    this.stars = 0,
    this.forks = 0,
    this.watchers = 0,
    this.openIssues = 0,
    this.language,
    this.topics = const [],
    this.license,
    this.isPrivate = false,
    this.isArchived = false,
    this.isFork = false,
    this.defaultBranch = 'main',
    this.createdAt,
    this.updatedAt,
    this.pushedAt,
    this.homepage,
    this.size = 0,
    this.latestRelease,
    this.platform = RepositoryPlatform.unknown,
    this.isFavorited = false,
    this.isStarred = false,
    this.htmlUrl,
    this.subscribers = 0,
    this.sortOrder = 0.0,
    this.languageColor,
  });

  final int id;
  final String name;
  final String fullName;
  final OwnerModel? owner;
  final String? description;
  final int stars;
  final int forks;
  final int watchers;
  final int openIssues;
  final String? language;
  final List<String> topics;
  final LicenseInfo? license;
  final bool isPrivate;
  final bool isArchived;
  final bool isFork;
  final String defaultBranch;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? pushedAt;
  final String? homepage;
  final int size;
  final LatestReleaseInfo? latestRelease;
  final RepositoryPlatform platform;
  final bool isFavorited;
  final bool isStarred;
  final String? htmlUrl;
  final int subscribers;
  final double sortOrder;
  final String? languageColor;

  /// Formatted star count (e.g. "1.2k").
  String get formattedStars => _formatCount(stars);

  /// Formatted fork count.
  String get formattedForks => _formatCount(forks);

  /// The owner login, or empty string.
  String get ownerLogin => owner?.login ?? '';

  /// The owner avatar URL.
  String? get ownerAvatarUrl => owner?.avatarUrl;

  /// Whether the repo has a valid homepage URL.
  bool get hasHomepage => homepage != null && homepage!.isNotEmpty;

  /// Whether the repo has a latest release.
  bool get hasLatestRelease => latestRelease?.isNotEmpty == true;

  /// Latest release tag name, if available.
  String? get latestReleaseTag => latestRelease?.tag;

  /// Latest release name, falling back to tag.
  String? get latestReleaseName =>
      latestRelease?.name ?? latestRelease?.tag;

  RepositoryModel copyWith({
    int? id,
    String? name,
    String? fullName,
    OwnerModel? owner,
    String? description,
    int? stars,
    int? forks,
    int? watchers,
    int? openIssues,
    String? language,
    List<String>? topics,
    LicenseInfo? license,
    bool? isPrivate,
    bool? isArchived,
    bool? isFork,
    String? defaultBranch,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? pushedAt,
    String? homepage,
    int? size,
    LatestReleaseInfo? latestRelease,
    RepositoryPlatform? platform,
    bool? isFavorited,
    bool? isStarred,
    String? htmlUrl,
    int? subscribers,
    double? sortOrder,
    String? languageColor,
  }) {
    return RepositoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      owner: owner ?? this.owner,
      description: description ?? this.description,
      stars: stars ?? this.stars,
      forks: forks ?? this.forks,
      watchers: watchers ?? this.watchers,
      openIssues: openIssues ?? this.openIssues,
      language: language ?? this.language,
      topics: topics ?? this.topics,
      license: license ?? this.license,
      isPrivate: isPrivate ?? this.isPrivate,
      isArchived: isArchived ?? this.isArchived,
      isFork: isFork ?? this.isFork,
      defaultBranch: defaultBranch ?? this.defaultBranch,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pushedAt: pushedAt ?? this.pushedAt,
      homepage: homepage ?? this.homepage,
      size: size ?? this.size,
      latestRelease: latestRelease ?? this.latestRelease,
      platform: platform ?? this.platform,
      isFavorited: isFavorited ?? this.isFavorited,
      isStarred: isStarred ?? this.isStarred,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      subscribers: subscribers ?? this.subscribers,
      sortOrder: sortOrder ?? this.sortOrder,
      languageColor: languageColor ?? this.languageColor,
    );
  }

  factory RepositoryModel.fromJson(Map<String, dynamic> json) {
    // Parse topics - can be a direct list or null
    List<String> topics;
    if (json['topics'] is List) {
      topics = (json['topics'] as List).cast<String>();
    } else {
      topics = const [];
    }

    // Parse language color from nested object
    String? languageColor;
    if (json['primaryLanguage'] is Map) {
      languageColor =
          (json['primaryLanguage'] as Map)['color'] as String?;
    }

    // Parse latest release
    LatestReleaseInfo? latestRelease;
    if (json['latestRelease'] is Map<String, dynamic>) {
      latestRelease = LatestReleaseInfo.fromJson(
          json['latestRelease'] as Map<String, dynamic>);
    } else if (json['latest_release'] is Map<String, dynamic>) {
      latestRelease = LatestReleaseInfo.fromJson(
          json['latest_release'] as Map<String, dynamic>);
    }

    // Detect platform
    final language = json['language'] as String? ??
        (json['primaryLanguage'] is Map
            ? (json['primaryLanguage'] as Map)['name'] as String?
            : null);
    final detectedPlatform =
        RepositoryPlatform.detect(topics, language ?? '');

    return RepositoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      fullName: json['full_name'] as String? ??
          json['nameWithOwner'] as String? ??
          '',
      owner: json['owner'] != null
          ? OwnerModel.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String?,
      stars: json['stargazers_count'] as int? ??
          json['stargazerCount'] as int? ?? 0,
      forks: json['forks_count'] as int? ?? json['forkCount'] as int? ?? 0,
      watchers: json['watchers_count'] as int? ??
          (json['watchers'] is Map
              ? (json['watchers'] as Map)['totalCount'] as int? ?? 0
              : 0),
      openIssues: json['open_issues_count'] as int? ?? 0,
      language: language,
      topics: topics,
      license: LicenseInfo.fromJson(
          json['license'] as Map<String, dynamic>?),
      isPrivate: json['private'] as bool? ?? false,
      isArchived: json['archived'] as bool? ?? false,
      isFork: json['fork'] as bool? ?? false,
      defaultBranch:
          json['default_branch'] as String? ?? 'main',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      pushedAt: json['pushed_at'] != null
          ? DateTime.tryParse(json['pushed_at'] as String)
          : null,
      homepage: json['homepage'] as String? ??
          json['homepageUrl'] as String?,
      size: json['size'] as int? ?? json['diskUsage'] as int? ?? 0,
      latestRelease: latestRelease,
      platform: detectedPlatform,
      htmlUrl: json['html_url'] as String? ?? json['url'] as String?,
      subscribers: json['subscribers_count'] as int? ?? 0,
      languageColor: json['language_color'] as String? ?? languageColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'full_name': fullName,
      if (owner != null) 'owner': owner!.toJson(),
      if (description != null) 'description': description,
      'stargazers_count': stars,
      'forks_count': forks,
      'watchers_count': watchers,
      'open_issues_count': openIssues,
      if (language != null) 'language': language,
      'topics': topics,
      if (license != null) 'license': license!.toJson(),
      'private': isPrivate,
      'archived': isArchived,
      'fork': isFork,
      'default_branch': defaultBranch,
      if (createdAt != null)
        'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null)
        'updated_at': updatedAt!.toUtc().toIso8601String(),
      if (pushedAt != null)
        'pushed_at': pushedAt!.toUtc().toIso8601String(),
      if (homepage != null) 'homepage': homepage,
      'size': size,
      if (latestRelease != null)
        'latest_release': latestRelease!.toJson(),
      'platform': platform.name,
      'is_favorite': isFavorited,
      'is_starred': isStarred,
      if (htmlUrl != null) 'html_url': htmlUrl,
      'subscribers_count': subscribers,
      if (languageColor != null) 'language_color': languageColor,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory RepositoryModel.fromJsonString(String source) =>
      RepositoryModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName;

  @override
  int get hashCode => Object.hash(id, fullName);

  @override
  String toString() =>
      'RepositoryModel(fullName: $fullName, stars: $stars, language: $language)';
}
