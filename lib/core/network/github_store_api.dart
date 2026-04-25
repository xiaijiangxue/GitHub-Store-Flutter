import 'dart:convert';

import '../models/category_model.dart';
import '../models/repository_model.dart';
import '../models/release_model.dart';
import '../models/search_result_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// API client that provides curated GitHub content (trending, hot releases,
/// popular repos, categories) powered entirely by the **official GitHub REST API**.
///
/// GitHub removed its dedicated Trending endpoint long ago, so we approximate
/// trending / hot / popular via [search/repositories](https://docs.github.com/en/rest/search/search#search-repositories)
/// with date-range and sort qualifiers.
class GitHubStoreApi {
  GitHubStoreApi(this._client);

  final ApiClient _client;

  // ── Default categories (no backend needed) ──────────────────────────────

  static const List<Map<String, dynamic>> _defaultCategories = [
    {
      'id': 'developer-tools',
      'name': 'Developer Tools',
      'icon': 'code',
      'color': '#FF6B6B',
      'topic_keywords': ['developer-tools', 'devtools'],
    },
    {
      'id': 'ai-ml',
      'name': 'AI & ML',
      'icon': 'psychology',
      'color': '#7C4DFF',
      'topic_keywords': ['ai', 'machine-learning', 'deep-learning'],
    },
    {
      'id': 'web-frameworks',
      'name': 'Web Frameworks',
      'icon': 'web',
      'color': '#2196F3',
      'topic_keywords': ['web-framework', 'frontend'],
    },
    {
      'id': 'mobile',
      'name': 'Mobile',
      'icon': 'phone_android',
      'color': '#4CAF50',
      'topic_keywords': ['mobile', 'android', 'ios'],
    },
    {
      'id': 'devops',
      'name': 'DevOps',
      'icon': 'settings',
      'color': '#FF9800',
      'topic_keywords': ['devops', 'docker', 'kubernetes', 'ci-cd'],
    },
    {
      'id': 'utilities',
      'name': 'Utilities',
      'icon': 'build',
      'color': '#607D8B',
      'topic_keywords': ['utility', 'cli', 'tool'],
    },
  ];

  // ── Date Helpers ────────────────────────────────────────────────────────

  /// Returns a date string like `2026-04-19` for [days] days ago.
  String _daysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Build a GitHub search query string from optional filters.
  String _buildQuery({
    required String base,
    String? language,
    String? platform,
  }) {
    final parts = <String>[base];
    if (language != null && language.isNotEmpty) {
      parts.add('language:$language');
    }
    if (platform != null && platform.isNotEmpty && platform != 'all') {
      parts.add('topic:$platform');
    }
    return parts.join(' ');
  }

  /// Extract the `items` list from a GitHub search response.
  List<RepositoryModel> _extractSearchItems(Map<String, dynamic>? data) {
    if (data == null) return [];
    return ((data['items'] as List<dynamic>?) ?? [])
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Home Feed Endpoints (GitHub Search API) ─────────────────────────────

  /// Get trending repositories — repos **created** in the last 7 days,
  /// sorted by stars (descending).
  ///
  /// [platform] - Optional topic filter (android, macos, windows, linux).
  /// [language] - Optional programming language filter (e.g. "Dart", "Python").
  Future<List<RepositoryModel>> getTrending({
    String? platform,
    String? language,
  }) async {
    final query = _buildQuery(
      base: 'created:>${_daysAgo(7)}',
      language: language,
      platform: platform,
    );

    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _extractSearchItems(response.data);
  }

  /// Get repositories with recent activity — repos **pushed to** in the last
  /// 7 days with at least 10 stars, sorted by star count.
  ///
  /// [platform] - Optional topic filter.
  /// [language] - Optional programming language filter.
  Future<List<RepositoryModel>> getHotReleases({
    String? platform,
    String? language,
  }) async {
    final query = _buildQuery(
      base: 'pushed:>${_daysAgo(7)} stars:>10',
      language: language,
      platform: platform,
    );

    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _extractSearchItems(response.data);
  }

  /// Get all-time most popular repositories — repos with 50 000+ stars,
  /// sorted by star count.
  ///
  /// [platform] - Optional topic filter.
  /// [language] - Optional programming language filter.
  Future<List<RepositoryModel>> getMostPopular({
    String? platform,
    String? language,
  }) async {
    final query = _buildQuery(
      base: 'stars:>50000',
      language: language,
      platform: platform,
    );

    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _extractSearchItems(response.data);
  }

  // ── Topic / Bucket Endpoints ────────────────────────────────────────────

  /// Get repositories for a specific topic/bucket, sorted by stars.
  ///
  /// [bucket] - The topic keyword (e.g. "developer-tools", "docker").
  /// [platform] - Optional platform filter.
  Future<List<RepositoryModel>> getTopicRepos(
    String bucket, {
    String? platform,
  }) async {
    final parts = <String>['topic:$bucket'];
    if (platform != null && platform.isNotEmpty && platform != 'all') {
      parts.add('topic:$platform');
    }
    final query = parts.join(' ');

    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _extractSearchItems(response.data);
  }

  // ── Search Endpoints ────────────────────────────────────────────────────

  /// Search for repositories using GitHub's search API.
  ///
  /// [query] - The search query string.
  /// [platform] - Optional platform topic filter.
  /// [language] - Optional programming language filter.
  /// [sort] - Sort field (stars, forks, updated, etc.).
  /// [order] - Sort order (asc, desc).
  /// [page] - Page number (1-indexed).
  Future<SearchResultModel> search({
    required String query,
    String? platform,
    String? language,
    String sort = 'stars',
    String order = 'desc',
    int page = 1,
  }) async {
    final parts = <String>[query];
    if (platform != null && platform.isNotEmpty && platform != 'all') {
      parts.add('topic:$platform');
    }
    if (language != null && language.isNotEmpty) {
      parts.add('language:$language');
    }
    final searchQuery = parts.join(' ');

    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': searchQuery,
        'sort': sort,
        'order': order,
        'page': page,
        'per_page': 30,
      },
    );

    final data = response.data;
    if (data == null) {
      return SearchResultModel.empty();
    }

    return SearchResultModel.fromJson(data, page: page, perPage: 30);
  }

  /// Explore search — a broader search for discovery.
  ///
  /// Same as [search] but with a default sort by `updated`.
  Future<SearchResultModel> searchExplore({
    required String query,
    int page = 1,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/search/repositories',
      queryParameters: {
        'q': query,
        'sort': 'updated',
        'order': 'desc',
        'page': page,
        'per_page': 30,
      },
    );

    final data = response.data;
    if (data == null) {
      return SearchResultModel.empty();
    }

    return SearchResultModel.fromJson(data, page: page, perPage: 30);
  }

  // ── Repository Detail Endpoints ─────────────────────────────────────────

  /// Get detailed information about a specific repository.
  Future<RepositoryModel> getRepository(
    String owner,
    String name,
  ) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$owner/$name',
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(
        message: 'Repository $owner/$name not found',
        statusCode: 404,
      );
    }

    return RepositoryModel.fromJson(data);
  }

  /// Get all releases for a specific repository.
  Future<List<ReleaseModel>> getReleases(
    String owner,
    String name,
  ) async {
    final response = await _client.get<List<dynamic>>(
      '/repos/$owner/$name/releases',
      queryParameters: {'per_page': 30},
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => ReleaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get the README content for a specific repository.
  ///
  /// Returns the raw markdown content (base64-decoded if necessary).
  Future<String> getReadme(String owner, String name) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/repos/$owner/$name/readme',
    );

    final data = response.data;

    if (data == null) {
      throw ApiException(
        message: 'README not found for $owner/$name',
        statusCode: 404,
      );
    }

    if (data.containsKey('content')) {
      final content = data['content'] as String?;
      if (content == null || content.isEmpty) return '';
      // GitHub API returns README as base64 when Accept header is v3+json.
      if (data['encoding'] == 'base64') {
        return _decodeBase64(content);
      }
      return content;
    }

    throw ApiException(
      message: 'Could not parse README for $owner/$name',
      statusCode: 500,
    );
  }

  // ── User Profile Endpoints ──────────────────────────────────────────────

  /// Get the public profile of a GitHub user.
  Future<UserModel> getUserProfile(String username) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/users/$username',
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(
        message: 'User $username not found',
        statusCode: 404,
      );
    }

    return UserModel.fromJson(data);
  }

  // ── Categories (hardcoded) ──────────────────────────────────────────────

  /// Get all available categories for browsing.
  ///
  /// Returns a hardcoded list of categories with topic keywords that map to
  /// GitHub search queries.
  Future<List<Map<String, dynamic>>> getCategories() async {
    return _defaultCategories;
  }

  // ── Helper Methods ──────────────────────────────────────────────────────

  /// Decode a base64-encoded string (GitHub README format).
  String _decodeBase64(String input) {
    // GitHub API base64 output has line breaks every 76 characters
    final cleaned = input.replaceAll('\n', '').replaceAll('\r', '');
    // Dart's built-in base64 decoder
    try {
      return utf8.decode(base64Decode(cleaned));
    } catch (_) {
      return '';
    }
  }
}
