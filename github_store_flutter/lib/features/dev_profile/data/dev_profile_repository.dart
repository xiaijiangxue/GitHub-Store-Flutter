import '../../../core/cache/cache_manager.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/github_store_api.dart';

/// Repository for fetching developer profile data and their repositories.
///
/// Uses the GitHub Store API for profiles (with caching) and the raw
/// GitHub API for paginated repository listings.
class DevProfileRepository {
  DevProfileRepository({
    required GitHubStoreApi storeApi,
    required CacheManager cache,
    required ApiClient apiClient,
  })  : _storeApi = storeApi,
        _cache = cache,
        _apiClient = apiClient;

  final GitHubStoreApi _storeApi;
  final CacheManager _cache;
  final ApiClient _apiClient;

  // ── Cache Keys ──────────────────────────────────────────────────────────

  String _profileKey(String username) => 'dev_profile:$username';
  String _reposKey(String username, int page) =>
      'dev_repos:$username:$page';

  // ── Profile ─────────────────────────────────────────────────────────────

  /// Get a user's profile from the GitHub Store API.
  ///
  /// Results are cached for 6 hours.
  Future<UserModel> getUserProfile(String username) async {
    final cacheKey = _profileKey(username);
    const ttl = Duration(hours: 6);

    final cached = await _cache.get<UserModel>(
      cacheKey,
      fromJson: UserModel.fromJson,
      ttl: ttl,
    );
    if (cached != null) return cached;

    final user = await _storeApi.getUserProfile(username);

    await _cache.put(
      cacheKey,
      data: user,
      toJson: (u) => u.toJson(),
      ttl: ttl,
    );

    return user;
  }

  /// Invalidate cached profile data for a specific user.
  Future<void> invalidateUser(String username) async {
    await _cache.invalidate(_profileKey(username));
  }

  // ── Repositories ────────────────────────────────────────────────────────

  /// Get repositories for a user with pagination.
  ///
  /// [username] - GitHub username.
  /// [page] - Page number (1-indexed).
  /// [perPage] - Results per page (default 30).
  /// [sort] - Sort field: 'updated' (default), 'created', 'pushed', 'full_name'.
  ///
  /// Returns a list of [RepositoryModel] and the total count.
  /// Results are cached for 10 minutes per page.
  Future<List<RepositoryModel>> getUserRepos(
    String username, {
    int page = 1,
    int perPage = 30,
    String sort = 'updated',
  }) async {
    final cacheKey = _reposKey(username, page);
    const ttl = Duration(minutes: 10);

    // Only cache the first page
    if (page == 1) {
      final cached = await _cache.getList<RepositoryModel>(
        cacheKey,
        fromJson: RepositoryModel.fromJson,
        ttl: ttl,
      );
      if (cached != null) return cached;
    }

    final response = await _apiClient.get<List<dynamic>>(
      '/users/$username/repos',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        'sort': sort,
      },
    );

    final data = response.data;
    if (data == null) return [];

    final repos = data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cache first page
    if (page == 1) {
      await _cache.putList(
        cacheKey,
        items: repos,
        toJson: (r) => r.toJson(),
        ttl: ttl,
      );
    }

    return repos;
  }

  /// Format a count for display (e.g. 1200 → "1.2k").
  static String formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }
}
