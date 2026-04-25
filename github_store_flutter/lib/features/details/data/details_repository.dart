import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/cache/cache_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/release_asset_model.dart';
import '../../../core/models/release_model.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/network/github_api.dart';
import '../../../core/network/github_store_api.dart';

/// Repository for the details screen, handling repository metadata, releases,
/// README content, starring, favoriting, recently-viewed tracking, and downloads.
///
/// All read-only API data is cached through [CacheManager] with appropriate TTLs.
/// Local mutations (favorites, recently-viewed) persist to [AppDatabase].
class DetailsRepository {
  DetailsRepository({
    required GitHubStoreApi storeApi,
    required GitHubApi gitHubApi,
    required CacheManager cache,
    required AppDatabase database,
  })  : _storeApi = storeApi,
        _gitHubApi = gitHubApi,
        _cache = cache,
        _database = database;

  final GitHubStoreApi _storeApi;
  final GitHubApi _gitHubApi;
  final CacheManager _cache;
  final AppDatabase _database;

  // ── Cache Key Helpers ──────────────────────────────────────────────────

  String _repoKey(String owner, String name) => 'details:repo:$owner/$name';
  String _releasesKey(String owner, String name) =>
      'details:releases:$owner/$name';
  String _readmeKey(String owner, String name) =>
      'details:readme:$owner/$name';

  // ── Repository Details ─────────────────────────────────────────────────

  /// Get detailed information about a repository.
  ///
  /// Cached for 6 hours.
  Future<RepositoryModel> getRepository(String owner, String name) async {
    final cacheKey = _repoKey(owner, name);

    final cached = await _cache.get<RepositoryModel>(
      cacheKey,
      fromJson: RepositoryModel.fromJson,
      ttl: const Duration(hours: 6),
    );
    if (cached != null) return cached;

    final repo = await _storeApi.getRepository(owner, name);

    await _cache.put(
      cacheKey,
      data: repo,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 6),
    );

    // Also upsert into local DB
    await _database.upsertRepository(
      RepositoriesCompanion(
        id: Value(repo.id),
        fullName: Value(repo.fullName),
        owner: Value(repo.ownerLogin),
        name: Value(repo.name),
        description: Value(repo.description),
        htmlUrl:
            Value(repo.htmlUrl ?? 'https://github.com/${repo.fullName}'),
        avatarUrl: Value(repo.ownerAvatarUrl),
        language: Value(repo.language),
        languageColor: Value(repo.languageColor),
        stargazersCount: Value(repo.stars),
        forksCount: Value(repo.forks),
        openIssuesCount: Value(repo.openIssues),
        watchersCount: Value(repo.watchers),
        subscribersCount: Value(repo.subscribers),
        size: Value(repo.size),
        defaultBranch: Value(repo.defaultBranch),
        isFork: Value(repo.isFork),
        isArchived: Value(repo.isArchived),
        license: Value(repo.license?.spdxId),
        licenseName: Value(repo.license?.name),
        topics:
            Value('[${repo.topics.map((t) => '"$t"').join(',')}]'),
        homepage: Value(repo.homepage),
        createdAt: Value(repo.createdAt),
        pushedAt: Value(repo.pushedAt),
        updatedAt: Value(repo.updatedAt),
        cachedAt: Value(DateTime.now()),
      ),
    );

    return repo;
  }

  // ── Releases ───────────────────────────────────────────────────────────

  /// Get all releases for a repository.
  ///
  /// Cached for 6 hours.
  Future<List<ReleaseModel>> getReleases(String owner, String name) async {
    final cacheKey = _releasesKey(owner, name);

    final cached = await _cache.getList<ReleaseModel>(
      cacheKey,
      fromJson: ReleaseModel.fromJson,
      ttl: const Duration(hours: 6),
    );
    if (cached != null) return cached;

    final releases = await _storeApi.getReleases(owner, name);

    await _cache.putList(
      cacheKey,
      items: releases,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 6),
    );

    return releases;
  }

  // ── README ─────────────────────────────────────────────────────────────

  /// Get the README markdown content for a repository.
  ///
  /// Cached for 12 hours.
  Future<String> getReadme(String owner, String name) async {
    final cacheKey = _readmeKey(owner, name);

    final cached = await _cache.getRaw(
      cacheKey,
      ttl: const Duration(hours: 12),
    );
    if (cached != null) return cached;

    // Try to fetch README from the store API
    String readmeContent;
    try {
      readmeContent = await _storeApi.getReadme(owner, name);
    } catch (_) {
      readmeContent = '';
    }

    await _cache.putRaw(
      cacheKey,
      readmeContent,
      ttl: const Duration(hours: 12),
    );

    return readmeContent;
  }

  // ── Star Management ────────────────────────────────────────────────────

  /// Check whether the authenticated user has starred a repository.
  ///
  /// Requires authentication.
  Future<bool> checkStarred(String owner, String name) async {
    return _gitHubApi.checkStarred(owner, name);
  }

  /// Star a repository.
  ///
  /// Requires authentication.
  Future<void> starRepo(String owner, String name) async {
    await _gitHubApi.starRepo(owner, name);
  }

  /// Unstar a repository.
  ///
  /// Requires authentication.
  Future<void> unstarRepo(String owner, String name) async {
    await _gitHubApi.unstarRepo(owner, name);
  }

  // ── Favorites (Local) ─────────────────────────────────────────────────

  /// Toggle the favorite status for a repository (local DB only).
  Future<void> toggleFavorite(String owner, String name) async {
    final fullName = '$owner/$name';
    final existing = await _database.getRepositoryByFullName(fullName);

    if (existing != null) {
      final newStatus = !existing.isFavorite;
      await _database.toggleFavorite(existing.id, newStatus);
    } else {
      // Fetch repo first, then set favorite
      final repo = await getRepository(owner, name);
      await _database.toggleFavorite(repo.id, true);
    }
  }

  /// Check if a repository is favorited (local DB).
  Future<bool> isFavorited(String owner, String name) async {
    final fullName = '$owner/$name';
    final existing = await _database.getRepositoryByFullName(fullName);
    return existing?.isFavorite ?? false;
  }

  // ── Recently Viewed ───────────────────────────────────────────────────

  /// Add a repository to the recently viewed list.
  Future<void> addRecentlyViewed(String owner, String name) async {
    final fullName = '$owner/$name';

    // Try to get the repo ID from local DB
    final existing = await _database.getRepositoryByFullName(fullName);
    final repoId = existing?.id;

    await _database.addRecentlyViewed(fullName, repoId);
  }

  // ── Downloads ─────────────────────────────────────────────────────────

  /// Download a release asset.
  ///
  /// Returns the local file path of the downloaded file.
  Future<String> downloadRelease(
    ReleaseAssetModel asset,
    String owner,
    String name,
    String version,
  ) async {
    if (asset.downloadUrl == null || asset.downloadUrl!.isEmpty) {
      throw Exception('No download URL available for ${asset.name}');
    }

    final tempDir = await getTemporaryDirectory();
    final downloadDir =
        Directory(p.join(tempDir.path, 'github_store_downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final fileName = asset.name;
    final filePath = p.join(downloadDir.path, fileName);

    // Avoid re-downloading if the file already exists
    if (await File(filePath).exists()) {
      return filePath;
    }

    final dio = Dio();
    await dio.download(
      asset.downloadUrl!,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          debugPrint(
              'Downloading ${asset.name}: ${(progress * 100).toStringAsFixed(1)}%');
        }
      },
    );

    return filePath;
  }

  // ── Cache Management ───────────────────────────────────────────────────

  /// Invalidate all cache entries for a specific repository.
  Future<void> invalidateRepoCache(String owner, String name) async {
    await _cache.invalidate(_repoKey(owner, name));
    await _cache.invalidate(_releasesKey(owner, name));
    await _cache.invalidate(_readmeKey(owner, name));
  }
}
