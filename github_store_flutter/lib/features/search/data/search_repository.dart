import 'dart:convert';
import 'dart:async';

import '../../../core/cache/cache_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/models/search_result_model.dart';
import '../../../core/network/github_store_api.dart';

/// Repository for search functionality, handling repository search,
/// explore search, and search history persistence.
class SearchRepository {
  SearchRepository({
    required GitHubStoreApi storeApi,
    required CacheManager cache,
    required AppDatabase database,
  })  : _storeApi = storeApi,
        _cache = cache,
        _database = database;

  final GitHubStoreApi _storeApi;
  final CacheManager _cache;
  final AppDatabase _database;

  // ── Search Cache Keys ─────────────────────────────────────────────────

  String _searchCacheKey(
    String query, {
    String? platform,
    String? language,
    String sort = 'stars',
    String order = 'desc',
    int page = 1,
  }) {
    return 'search:$query:$platform:$language:$sort:$order:$page';
  }

  String _exploreCacheKey(String query, {int page = 1}) {
    return 'search:explore:$query:$page';
  }

  // ── Search Repositories ────────────────────────────────────────────────

  /// Search for repositories with various filters.
  ///
  /// Results are cached for 1 hour. The search query must be non-empty.
  Future<SearchResultModel> search(
    String query, {
    String? platform,
    String? language,
    String sort = 'stars',
    String order = 'desc',
    int page = 1,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResultModel.empty();
    }

    final cacheKey = _searchCacheKey(
      query,
      platform: platform,
      language: language,
      sort: sort,
      order: order,
      page: page,
    );

    // Try cache (1h TTL)
    final cachedJson = await _cache.getRaw(
      cacheKey,
      ttl: const Duration(hours: 1),
    );
    if (cachedJson != null) {
      try {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        if (cached.containsKey('total_count')) {
          return SearchResultModel.fromJson(cached, page: page);
        } else {
          return SearchResultModel.fromStoreJson(cached, page: page);
        }
      } catch (_) {
        // Corrupted cache, continue to fetch
      }
    }

    // Fetch from API
    final result = await _storeApi.search(
      query: query,
      platform: platform,
      language: language,
      sort: sort,
      order: order,
      page: page,
    );

    // Cache the raw JSON
    await _cache.putRaw(
      cacheKey,
      jsonEncode(result.toJson()),
      ttl: const Duration(hours: 1),
    );

    return result;
  }

  // ── Explore Search ─────────────────────────────────────────────────────

  /// Broader explore search for discovery.
  ///
  /// [query] - The search query string.
  /// [page] - Page number (1-indexed).
  Future<SearchResultModel> searchExplore(
    String query, {
    int page = 1,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResultModel.empty();
    }

    final cacheKey = _exploreCacheKey(query, page: page);

    final cachedJson = await _cache.getRaw(
      cacheKey,
      ttl: const Duration(hours: 1),
    );
    if (cachedJson != null) {
      try {
        final cached = jsonDecode(cachedJson) as Map<String, dynamic>;
        return SearchResultModel.fromStoreJson(cached, page: page);
      } catch (_) {}
    }

    final result = await _storeApi.searchExplore(query: query, page: page);

    await _cache.putRaw(
      cacheKey,
      jsonEncode(result.toJson()),
      ttl: const Duration(hours: 1),
    );

    return result;
  }

  // ── Search History ─────────────────────────────────────────────────────

  /// Get recent search history entries.
  ///
  /// Returns the most recent 20 search queries, ordered by most recent first.
  Future<List<String>> getSearchHistory() async {
    final entries = await _database.watchSearchHistory(limit: 20).first;
    return entries.map((e) => e.query).toList();
  }

  /// Add a query to search history.
  ///
  /// Duplicates are handled by the database insert.
  Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    await _database.addSearchHistory(query.trim(), 'repositories');
  }

  /// Clear all search history.
  Future<void> clearSearchHistory() async {
    await _database.clearSearchHistory();
  }
}
