import '../models/repository_model.dart';
import '../models/release_model.dart';
import '../models/search_result_model.dart';
import '../models/user_model.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

/// API client that replaces the non-existent store-api.githubstore.app
/// with GitHub's real REST API (https://api.github.com).
///
/// All methods use the GitHub Search API or standard REST endpoints
/// to provide the same functionality the store backend was supposed to offer.
class GitHubStoreApi {
  GitHubStoreApi(this._client);

  final ApiClient _client;

  // ── Home Feed Endpoints ─────────────────────────────────────────────────

  /// Get trending repositories using GitHub Search API.
  ///
  /// Searches for repos created in the last 7 days, sorted by stars.
  /// [platform] - Optional platform filter keyword (android, macos, windows, linux).
  Future<List<RepositoryModel>> getTrending({String? platform}) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final dateStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';

    String query = 'created:>$dateStr';
    if (platform != null && platform.isNotEmpty) {
      query += ' $platform in:topic,readme,name,description';
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _parseSearchItems(response.data);
  }

  /// Get repositories with recent hot releases using GitHub Search API.
  ///
  /// Searches for repos pushed to in the last 3 days, sorted by stars.
  Future<List<RepositoryModel>> getHotReleases({String? platform}) async {
    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    final dateStr = '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-${threeDaysAgo.day.toString().padLeft(2, '0')}';

    String query = 'pushed:>$dateStr';
    if (platform != null && platform.isNotEmpty) {
      query += ' $platform in:topic,readme,name,description';
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _parseSearchItems(response.data);
  }

  /// Get most popular repositories using GitHub Search API.
  ///
  /// Searches for repos with 10000+ stars, sorted by stars.
  Future<List<RepositoryModel>> getMostPopular({String? platform}) async {
    String query = 'stars:>10000';
    if (platform != null && platform.isNotEmpty) {
      query += ' $platform in:topic,readme,name,description';
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _parseSearchItems(response.data);
  }

  // ── Topic/Bucket Endpoints ──────────────────────────────────────────────

  /// Get repositories for a specific topic using GitHub Search API.
  ///
  /// [bucket] - The topic to search for.
  /// [platform] - Optional platform filter.
  Future<List<RepositoryModel>> getTopicRepos(
    String bucket, {
    String? platform,
  }) async {
    String query = 'topic:$bucket';
    if (platform != null && platform.isNotEmpty) {
      query += ' $platform in:topic,readme,name,description';
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': 30,
      },
    );

    return _parseSearchItems(response.data);
  }

  // ── Search Endpoints ────────────────────────────────────────────────────

  /// Search for repositories using GitHub Search API.
  ///
  /// [query] - The search query string.
  /// [platform] - Optional platform filter.
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
    // Build the query string for GitHub Search API
    String q = query;
    if (language != null && language.isNotEmpty) {
      q += ' language:$language';
    }
    if (platform != null && platform.isNotEmpty) {
      q += ' $platform in:topic,readme,name,description';
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': q,
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

    return SearchResultModel.fromJson(data, page: page);
  }

  /// Explore search - same as search but with best_match sort.
  Future<SearchResultModel> searchExplore({
    required String query,
    int page = 1,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.searchRepositoriesUrl,
      queryParameters: {
        'q': query,
        'sort': 'best_match',
        'order': 'desc',
        'page': page,
        'per_page': 30,
      },
    );

    final data = response.data;
    if (data == null) {
      return SearchResultModel.empty();
    }

    return SearchResultModel.fromJson(data, page: page);
  }

  // ── Repository Detail Endpoints ─────────────────────────────────────────

  /// Get detailed information about a specific repository.
  Future<RepositoryModel> getRepository(
    String owner,
    String name,
  ) async {
    final path = ApiConstants.repositoryUrlPath(owner, name);

    final response = await _client.get<Map<String, dynamic>>(path);

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
    final path = '/repos/$owner/$name/releases';

    final response = await _client.get<List<dynamic>>(
      path,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => ReleaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get the README content for a specific repository.
  ///
  /// Uses GitHub's raw content API to get the README markdown.
  Future<String> getReadme(String owner, String name) async {
    final path = '/repos/$owner/$name/readme';

    try {
      // Use the standard get which returns JSON, then decode base64 content
      final response = await _client.get<Map<String, dynamic>>(path);

      final data = response.data;
      if (data == null) return '';

      if (data.containsKey('content')) {
        final content = data['content'] as String;
        final encoding = data['encoding'] as String?;
        if (encoding == 'base64' || encoding == null) {
          final cleaned = content.replaceAll('\n', '').replaceAll('\r', '');
          return _decodeBase64(cleaned);
        }
        return content;
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  // ── User Profile Endpoints ──────────────────────────────────────────────

  /// Get the public profile of a GitHub user.
  Future<UserModel> getUserProfile(String username) async {
    final path = ApiConstants.userProfilePath(username);

    final response = await _client.get<Map<String, dynamic>>(path);

    final data = response.data;
    if (data == null) {
      throw ApiException(
        message: 'User $username not found',
        statusCode: 404,
      );
    }

    return UserModel.fromJson(data);
  }

  // ── Categories Endpoint ─────────────────────────────────────────────────

  /// Return built-in categories since GitHub has no categories API.
  ///
  /// Uses hardcoded curated topics for browsing.
  Future<List<Map<String, dynamic>>> getCategories() async {
    return [
      {
        'id': 'dev-tools',
        'name': 'Developer Tools',
        'icon': 'code',
        'description': 'IDEs, editors, and development utilities',
        'topic_keywords': ['developer-tools', 'cli', 'terminal', 'devtools'],
        'color': '#4FC3F7',
        'sort_order': 1,
        'is_featured': true,
      },
      {
        'id': 'web-frameworks',
        'name': 'Web Frameworks',
        'icon': 'web',
        'description': 'Frontend and backend web frameworks',
        'topic_keywords': ['web-framework', 'frontend', 'react', 'vue', 'angular', 'svelte'],
        'color': '#42A5F5',
        'sort_order': 2,
        'is_featured': true,
      },
      {
        'id': 'ai-ml',
        'name': 'AI / Machine Learning',
        'icon': 'psychology',
        'description': 'AI, ML, and data science tools',
        'topic_keywords': ['machine-learning', 'artificial-intelligence', 'deep-learning', 'llm', 'ai'],
        'color': '#AB47BC',
        'sort_order': 3,
        'is_featured': true,
      },
      {
        'id': 'mobile',
        'name': 'Mobile Development',
        'icon': 'phone_android',
        'description': 'Mobile app frameworks and tools',
        'topic_keywords': ['mobile', 'flutter', 'react-native', 'ios', 'android'],
        'color': '#26A69A',
        'sort_order': 4,
        'is_featured': false,
      },
      {
        'id': 'devops',
        'name': 'DevOps & CI/CD',
        'icon': 'settings_suggest',
        'description': 'Deployment, monitoring, and infrastructure tools',
        'topic_keywords': ['devops', 'docker', 'kubernetes', 'ci-cd', 'infrastructure'],
        'color': '#FF7043',
        'sort_order': 5,
        'is_featured': false,
      },
      {
        'id': 'utilities',
        'name': 'Utilities',
        'icon': 'build',
        'description': 'Productivity tools and utilities',
        'topic_keywords': ['utility', 'productivity', 'tool', 'cli-tool'],
        'color': '#78909C',
        'sort_order': 6,
        'is_featured': false,
      },
      {
        'id': 'security',
        'name': 'Security',
        'icon': 'security',
        'description': 'Security tools and libraries',
        'topic_keywords': ['security', 'cryptography', 'privacy', 'encryption'],
        'color': '#EF5350',
        'sort_order': 7,
        'is_featured': false,
      },
      {
        'id': 'databases',
        'name': 'Databases',
        'icon': 'storage',
        'description': 'Database engines and ORM tools',
        'topic_keywords': ['database', 'sql', 'nosql', 'orm', 'postgres'],
        'color': '#FFA726',
        'sort_order': 8,
        'is_featured': false,
      },
    ];
  }

  // ── Helper Methods ──────────────────────────────────────────────────────

  /// Parse search API response items into a list of RepositoryModel.
  List<RepositoryModel> _parseSearchItems(Map<String, dynamic>? data) {
    if (data == null) return [];

    final items = data['items'] as List<dynamic>?;
    if (items == null) return [];

    return items
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Decode a base64-encoded string from GitHub's API.
  String _decodeBase64(String input) {
    // Use dart:convert for proper base64 decoding
    try {
      return _cleanBase64Decode(input);
    } catch (_) {
      return '';
    }
  }

  /// Decode base64 with padding cleanup.
  String _cleanBase64Decode(String source) {
    final clean = source.replaceAll('=', '');
    // Calculate required padding
    final padLen = (4 - clean.length % 4) % 4;
    final padded = clean + '=' * padLen;
    // Use dart:convert
    final bytes = _base64Decode(padded);
    return String.fromCharCodes(bytes);
  }

  /// Manual base64 decoder as fallback (avoids import issues).
  static List<int> _base64Decode(String source) {
    const base64Chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = <int>[];
    final clean = source.replaceAll('=', '');

    for (var i = 0; i < clean.length; i += 4) {
      final chunk = clean.substring(
        i,
        i + 4 > clean.length ? clean.length : i + 4,
      );

      int n = 0;
      for (var j = 0; j < chunk.length; j++) {
        n = (n << 6) | base64Chars.indexOf(chunk[j]);
      }

      if (chunk.length >= 2) result.add((n >> 16) & 0xFF);
      if (chunk.length >= 3) result.add((n >> 8) & 0xFF);
      if (chunk.length >= 4) result.add(n & 0xFF);
    }

    return result;
  }
}
