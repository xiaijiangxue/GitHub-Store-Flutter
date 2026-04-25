import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/models/owner_model.dart';
import '../../../core/models/repository_model.dart';

/// Data class combining a recently-viewed entry with its repository data.
class RecentlyViewedItem {
  const RecentlyViewedItem({
    required this.repository,
    required this.viewedAt,
    required this.viewCount,
  });

  final RepositoryModel repository;
  final DateTime viewedAt;
  final int viewCount;
}

/// Repository for managing recently viewed repositories in the local database.
///
/// Recently viewed entries are stored in the [recently_viewed] table, and the
/// corresponding repository metadata lives in the [repositories] table.
class RecentlyViewedRepository {
  RecentlyViewedRepository({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  // ── Query Methods ───────────────────────────────────────────────────────

  /// Get all recently viewed repositories, ordered by most recent first.
  ///
  /// [limit] — maximum number of entries to return (defaults to 50).
  ///
  /// For each recently-viewed entry, we attempt to join with the repositories
  /// table to get full metadata. If the repo isn't cached, a minimal model
  /// is constructed from the entry data.
  Future<List<RecentlyViewedItem>> getAllRecentlyViewed({int limit = 50}) async {
    final entries = await _database.getRecentlyViewedSync(limit: limit);

    final List<RecentlyViewedItem> items = [];

    for (final entry in entries) {
      RepositoryModel repo;

      // Try to get the full repository from the repositories table
      if (entry.repositoryId != null) {
        final cached = await _database.getRepositoryById(entry.repositoryId!);
        if (cached != null) {
          repo = _rowToModel(cached);
        } else {
          repo = _entryToMinimalModel(entry);
        }
      } else {
        // Try to look up by full name
        final cached =
            await _database.getRepositoryByFullName(entry.repoFullName);
        if (cached != null) {
          repo = _rowToModel(cached);
        } else {
          repo = _entryToMinimalModel(entry);
        }
      }

      items.add(RecentlyViewedItem(
        repository: repo,
        viewedAt: entry.viewedAt,
        viewCount: entry.viewCount,
      ));
    }

    return items;
  }

  // ── Mutation Methods ────────────────────────────────────────────────────

  /// Add or update a recently viewed entry.
  ///
  /// If the repo was already viewed, the timestamp and view count are updated.
  /// If it's a new entry, it's inserted. Optionally also upserts minimal
  /// repository metadata into the repositories table.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  /// [description] — optional description.
  /// [avatarUrl] — optional owner avatar URL.
  /// [stars] — star count (defaults to 0).
  /// [language] — primary language.
  Future<void> addRecentlyViewed(
    String owner,
    String name, {
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    final fullName = '$owner/$name';

    // Try to find an existing repo in the DB to get its ID
    var repoId = await _findRepoId(fullName);

    if (repoId == null) {
      // Insert a minimal repo entry if we have metadata
      if (description != null || avatarUrl != null) {
        repoId = await _insertMinimalRepo(
          owner: owner,
          name: name,
          description: description,
          avatarUrl: avatarUrl,
          stars: stars,
          language: language,
        );
      }
    }

    await _database.addRecentlyViewed(fullName, repoId);
  }

  /// Remove a specific recently viewed entry.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  Future<void> removeRecentlyViewed(String owner, String name) async {
    final fullName = '$owner/$name';
    await _database.removeRecentlyViewed(fullName);
  }

  /// Clear all recently viewed history.
  Future<void> clearAll() async {
    await _database.clearRecentlyViewed();
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  /// Find the repository ID from the repositories table by full name.
  Future<int?> _findRepoId(String fullName) async {
    final cached = await _database.getRepositoryByFullName(fullName);
    return cached?.id;
  }

  /// Insert a minimal repository entry and return its ID.
  Future<int> _insertMinimalRepo({
    required String owner,
    required String name,
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    final fullName = '$owner/$name';
    final id = fullName.hashCode.abs();

    await _database.upsertRepository(
      DbRepository(
        id: id,
        fullName: fullName,
        owner: owner,
        name: name,
        description: description,
        htmlUrl: 'https://github.com/$fullName',
        avatarUrl: avatarUrl,
        language: language,
        stargazersCount: stars,
        cachedAt: DateTime.now(),
      ),
    );

    return id;
  }

  /// Create a minimal [RepositoryModel] from a recently-viewed entry.
  RepositoryModel _entryToMinimalModel(DbRecentlyViewedEntry entry) {
    final parts = entry.repoFullName.split('/');
    final owner = parts.length >= 2 ? parts[0] : '';
    final name = parts.length >= 2 ? parts.sublist(1).join('/') : entry.repoFullName;

    return RepositoryModel(
      id: entry.repositoryId ?? entry.repoFullName.hashCode.abs(),
      name: name,
      fullName: entry.repoFullName,
      owner: OwnerModel(login: owner),
    );
  }

  /// Convert a database [DbRepository] row to a domain [RepositoryModel].
  RepositoryModel _rowToModel(DbRepository row) {
    return RepositoryModel(
      id: row.id,
      name: row.name,
      fullName: row.fullName,
      owner: OwnerModel(
        login: row.owner,
        avatarUrl: row.avatarUrl,
      ),
      description: row.description,
      stars: row.stargazersCount,
      forks: row.forksCount,
      watchers: row.watchersCount,
      openIssues: row.openIssuesCount,
      language: row.language,
      languageColor: row.languageColor,
      license: row.license != null
          ? LicenseInfo(key: row.license, name: row.licenseName)
          : null,
      isFork: row.isFork,
      isArchived: row.isArchived,
      isPrivate: row.isPrivate,
      defaultBranch: row.defaultBranch,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pushedAt: row.pushedAt,
      homepage: row.homepage,
      htmlUrl: row.htmlUrl,
      subscribers: row.subscribersCount,
      sortOrder: row.sortOrder,
      isFavorited: row.isFavorite,
      isStarred: row.isStarred,
      topics: _parseTopics(row.topics),
      latestRelease: row.latestRelease != null
          ? LatestReleaseInfo.fromJsonString(row.latestRelease!)
          : null,
    );
  }

  /// Parse the JSON-encoded topics string into a list.
  List<String> _parseTopics(String topicsJson) {
    if (topicsJson.isEmpty) return const [];
    if (topicsJson == '[]') return const [];
    try {
      final decoded = jsonDecode(topicsJson) as List;
      return decoded.cast<String>();
    } catch (_) {
      return const [];
    }
  }
}
