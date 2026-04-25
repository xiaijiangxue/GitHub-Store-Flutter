import '../../../core/cache/cache_manager.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/network/github_store_api.dart';

/// Repository for home screen data, handling trending, hot releases,
/// popular repos, topic-based browsing, and categories.
///
/// All API calls are cached through [CacheManager] with appropriate TTLs.
class HomeRepository {
  HomeRepository({
    required GitHubStoreApi storeApi,
    required CacheManager cache,
  })  : _storeApi = storeApi,
        _cache = cache;

  final GitHubStoreApi _storeApi;
  final CacheManager _cache;

  // ── Cache Key Helpers ──────────────────────────────────────────────────

  String _trendingKey(String platform) => 'home:trending:$platform';
  String _hotReleasesKey(String platform) => 'home:hot_releases:$platform';
  String _popularKey(String platform) => 'home:popular:$platform';
  String _topicKey(String bucket, String platform) =>
      'home:topic:$bucket:$platform';
  String _categoriesKey() => 'home:categories';

  // ── Trending ───────────────────────────────────────────────────────────

  /// Get trending repositories.
  ///
  /// [platform] - Filter by platform ('all', 'android', 'macos', 'windows', 'linux').
  /// [language] - Optional programming language filter (e.g. 'Dart', 'Python').
  /// Cached for 12 hours.
  Future<List<RepositoryModel>> getTrending({
    String platform = 'all',
    String? language,
  }) async {
    final cacheKey = '${_trendingKey(platform)}:$language';

    // Try cache first (12h TTL)
    final cached = await _cache.getList<RepositoryModel>(
      cacheKey,
      fromJson: RepositoryModel.fromJson,
      ttl: const Duration(hours: 12),
    );
    if (cached != null) return cached;

    // Fetch from API
    final platformFilter = platform == 'all' ? null : platform;
    final repos = await _storeApi.getTrending(
      platform: platformFilter,
      language: language,
    );

    // Cache the result
    await _cache.putList(
      cacheKey,
      items: repos,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 12),
    );

    return repos;
  }

  // ── Hot Releases ───────────────────────────────────────────────────────

  /// Get repositories with recent hot releases.
  ///
  /// [platform] - Filter by platform.
  /// [language] - Optional programming language filter.
  /// Cached for 6 hours.
  Future<List<RepositoryModel>> getHotReleases({
    String platform = 'all',
    String? language,
  }) async {
    final cacheKey = '${_hotReleasesKey(platform)}:$language';

    final cached = await _cache.getList<RepositoryModel>(
      cacheKey,
      fromJson: RepositoryModel.fromJson,
      ttl: const Duration(hours: 6),
    );
    if (cached != null) return cached;

    final platformFilter = platform == 'all' ? null : platform;
    final repos = await _storeApi.getHotReleases(
      platform: platformFilter,
      language: language,
    );

    await _cache.putList(
      cacheKey,
      items: repos,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 6),
    );

    return repos;
  }

  // ── Most Popular ───────────────────────────────────────────────────────

  /// Get most popular repositories by stars.
  ///
  /// [platform] - Filter by platform.
  /// [language] - Optional programming language filter.
  /// Cached for 6 hours.
  Future<List<RepositoryModel>> getMostPopular({
    String platform = 'all',
    String? language,
  }) async {
    final cacheKey = '${_popularKey(platform)}:$language';

    final cached = await _cache.getList<RepositoryModel>(
      cacheKey,
      fromJson: RepositoryModel.fromJson,
      ttl: const Duration(hours: 6),
    );
    if (cached != null) return cached;

    final platformFilter = platform == 'all' ? null : platform;
    final repos = await _storeApi.getMostPopular(
      platform: platformFilter,
      language: language,
    );

    await _cache.putList(
      cacheKey,
      items: repos,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 6),
    );

    return repos;
  }

  // ── Topic/Bucket Repos ─────────────────────────────────────────────────

  /// Get repositories for a specific topic bucket.
  ///
  /// [bucket] - The topic bucket identifier (e.g. "developer-tools", "utilities").
  /// [platform] - Filter by platform.
  /// Cached for 6 hours.
  Future<List<RepositoryModel>> getTopicRepos(
    String bucket, {
    String platform = 'all',
  }) async {
    final cacheKey = _topicKey(bucket, platform);

    final cached = await _cache.getList<RepositoryModel>(
      cacheKey,
      fromJson: RepositoryModel.fromJson,
      ttl: const Duration(hours: 6),
    );
    if (cached != null) return cached;

    final platformFilter = platform == 'all' ? null : platform;
    final repos =
        await _storeApi.getTopicRepos(bucket, platform: platformFilter);

    await _cache.putList(
      cacheKey,
      items: repos,
      toJson: (r) => r.toJson(),
      ttl: const Duration(hours: 6),
    );

    return repos;
  }

  // ── Categories ─────────────────────────────────────────────────────────

  /// Get all available categories for browsing.
  ///
  /// Cached for 24 hours.
  Future<List<CategoryModel>> getCategories() async {
    final cacheKey = _categoriesKey();

    final cached = await _cache.getList<CategoryModel>(
      cacheKey,
      fromJson: CategoryModel.fromJson,
      ttl: const Duration(hours: 24),
    );
    if (cached != null) return cached;

    final rawCategories = await _storeApi.getCategories();
    final categories = rawCategories
        .map((json) => CategoryModel.fromJson(json))
        .toList();

    await _cache.putList(
      cacheKey,
      items: categories,
      toJson: (c) => c.toJson(),
      ttl: const Duration(hours: 24),
    );

    return categories;
  }

  // ── Cache Management ───────────────────────────────────────────────────

  /// Invalidate all home-related cache entries.
  Future<void> invalidateAllCache() async {
    await _cache.invalidateByPrefix('home:trending:');
    await _cache.invalidateByPrefix('home:hot_releases:');
    await _cache.invalidateByPrefix('home:popular:');
    await _cache.invalidateByPrefix('home:topic:');
    await _cache.invalidate('home:categories');
  }
}
