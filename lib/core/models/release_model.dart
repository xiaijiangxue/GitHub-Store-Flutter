import 'dart:convert';

import 'owner_model.dart';
import 'release_asset_model.dart';

/// Represents a GitHub release with its metadata and downloadable assets.
class ReleaseModel {
  ReleaseModel({
    required this.id,
    required this.tagName,
    this.name,
    this.body,
    this.isPrerelease = false,
    this.isDraft = false,
    this.publishedAt,
    this.createdAt,
    this.assets = const [],
    this.author,
    this.htmlUrl,
    this.url,
    this.draft = false,
    this.discussionUrl,
    this.milestone,
  });

  final int id;

  /// Git tag name for this release (e.g. "v1.2.0").
  final String tagName;

  /// Human-readable release name.
  final String? name;

  /// Release notes body in markdown.
  final String? body;

  final bool isPrerelease;
  final bool isDraft;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  /// List of downloadable assets for this release.
  final List<ReleaseAssetModel> assets;

  /// The author (owner) who published this release.
  final OwnerModel? author;

  final String? htmlUrl;
  final String? url;
  final bool draft;
  final String? discussionUrl;
  final String? milestone;

  /// Display name: falls back to tagName if name is null.
  String get displayName => name?.isNotEmpty == true ? name! : tagName;

  /// Whether this release has any assets.
  bool get hasAssets => assets.isNotEmpty;

  /// Total download count across all assets.
  int get totalDownloads =>
      assets.fold(0, (sum, asset) => sum + asset.downloadCount);

  /// Get assets filtered by the given platform.
  List<ReleaseAssetModel> assetsForPlatform(ReleaseAssetPlatform platform) {
    return assets.where((a) => a.platform == platform).toList();
  }

  /// Get the total size of all assets in bytes.
  int get totalSize => assets.fold(0, (sum, asset) => sum + asset.size);

  /// Formatted total size string.
  String get formattedTotalSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  ReleaseModel copyWith({
    int? id,
    String? tagName,
    String? name,
    String? body,
    bool? isPrerelease,
    bool? isDraft,
    DateTime? publishedAt,
    DateTime? createdAt,
    List<ReleaseAssetModel>? assets,
    OwnerModel? author,
    String? htmlUrl,
    String? url,
    bool? draft,
    String? discussionUrl,
    String? milestone,
  }) {
    return ReleaseModel(
      id: id ?? this.id,
      tagName: tagName ?? this.tagName,
      name: name ?? this.name,
      body: body ?? this.body,
      isPrerelease: isPrerelease ?? this.isPrerelease,
      isDraft: isDraft ?? this.isDraft,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      assets: assets ?? this.assets,
      author: author ?? this.author,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      url: url ?? this.url,
      draft: draft ?? this.draft,
      discussionUrl: discussionUrl ?? this.discussionUrl,
      milestone: milestone ?? this.milestone,
    );
  }

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    return ReleaseModel(
      id: json['id'] as int,
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String?,
      body: json['body'] as String?,
      isPrerelease: json['prerelease'] as bool? ?? false,
      isDraft: json['draft'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((e) =>
                  ReleaseAssetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      author: json['author'] != null
          ? OwnerModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      htmlUrl: json['html_url'] as String?,
      url: json['url'] as String?,
      draft: json['draft'] as bool? ?? false,
      discussionUrl: json['discussion_url'] as String?,
      milestone: json['milestone'] != null
          ? (json['milestone'] as Map<String, dynamic>)['title'] as String?
          : null,
    );
  }

  /// Parse a minimal release info from the latestRelease field in the repository.
  ///
  /// This field typically contains only tag, name, and publishedAt.
  factory ReleaseModel.fromLatestReleaseJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ReleaseModel(
        id: 0,
        tagName: '',
        name: null,
        body: null,
        assets: const [],
      );
    }
    return ReleaseModel(
      id: json['id'] as int? ?? 0,
      tagName: json['tag_name'] as String? ?? json['tag'] as String? ?? '',
      name: json['name'] as String?,
      body: json['body'] as String?,
      isPrerelease: json['prerelease'] as bool? ?? false,
      isDraft: json['draft'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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
      'id': id,
      'tag_name': tagName,
      if (name != null) 'name': name,
      if (body != null) 'body': body,
      'prerelease': isPrerelease,
      'draft': isDraft,
      if (publishedAt != null)
        'published_at': publishedAt!.toUtc().toIso8601String(),
      if (createdAt != null)
        'created_at': createdAt!.toUtc().toIso8601String(),
      'assets': assets.map((a) => a.toJson()).toList(),
      if (author != null) 'author': author!.toJson(),
      if (htmlUrl != null) 'html_url': htmlUrl,
      if (url != null) 'url': url,
      if (discussionUrl != null) 'discussion_url': discussionUrl,
      if (milestone != null) 'milestone': {'title': milestone},
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ReleaseModel.fromJsonString(String source) =>
      ReleaseModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tagName == other.tagName;

  @override
  int get hashCode => Object.hash(id, tagName);

  @override
  String toString() =>
      'ReleaseModel(tagName: $tagName, name: $name, assets: ${assets.length})';
}
