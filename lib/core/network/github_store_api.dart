import '../models/repository_model.dart';
import '../models/release_model.dart';
import '../models/search_result_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// API client for the GitHub Store backend service.
///
/// This service wraps calls to the GitHub Store's custom API endpoints
/// that provide curated content like trending repos, hot releases, and
/// category-based browsing.
class GitHubStoreApi {
  GitHubStoreApi(this._client);

  final ApiClient _client;

  static const String _storeBaseUrl =
      'https://store-api.githubstore.app/v1';

  // ── Home Feed Endpoints ─────────────────────────────────────────────────

  /// Get trending repositories, optionally filtered by platform.
  ///
  /// [platform] - Optional platform filter (android, macos, windows, linux).
  Future<List<RepositoryModel>> getTrending({String? platform}) async {
    final queryParams = <String, dynamic>{};
    if (platform != null && platform.isNotEmpty) {
      queryParams['platform'] = platform;
    }

    final response = await _client.get<List<dynamic>>(
      '/trending',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get repositories with recent hot releases, optionally filtered by platform.
  ///
  /// [platform] - Optional platform filter.
  Future<List<RepositoryModel>> getHotReleases({String? platform}) async {
    final queryParams = <String, dynamic>{};
    if (platform != null && platform.isNotEmpty) {
      queryParams['platform'] = platform;
    }

    final response = await _client.get<List<dynamic>>(
      '/hot-releases',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get most popular repositories, optionally filtered by platform.
  ///
  /// [platform] - Optional platform filter.
  Future<List<RepositoryModel>> getMostPopular({String? platform}) async {
    final queryParams = <String, dynamic>{};
    if (platform != null && platform.isNotEmpty) {
      queryParams['platform'] = platform;
    }

    final response = await _client.get<List<dynamic>>(
      '/popular',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Topic/Bucket Endpoints ──────────────────────────────────────────────

  /// Get repositories for a specific topic/bucket, optionally filtered by platform.
  ///
  /// [bucket] - The topic bucket identifier (e.g. "developer-tools", "utilities").
  /// [platform] - Optional platform filter.
  Future<List<RepositoryModel>> getTopicRepos(
    String bucket, {
    String? platform,
  }) async {
    final queryParams = <String, dynamic>{
      'bucket': bucket,
    };
    if (platform != null && platform.isNotEmpty) {
      queryParams['platform'] = platform;
    }

    final response = await _client.get<List<dynamic>>(
      '/topic-repos',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Search Endpoints ────────────────────────────────────────────────────

  /// Search for repositories with various filters.
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
    final queryParams = <String, dynamic>{
      'q': query,
      'sort': sort,
      'order': order,
      'page': page,
      'per_page': 30,
    };
    if (platform != null && platform.isNotEmpty) {
      queryParams['platform'] = platform;
    }
    if (language != null && language.isNotEmpty) {
      queryParams['language'] = language;
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/search',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) {
      return SearchResultModel.empty();
    }

    return SearchResultModel.fromStoreJson(
      data,
      page: page,
      perPage: 30,
    );
  }

  /// Explore search - a broader search intended for discovery.
  ///
  /// [query] - The search query string.
  /// [page] - Page number (1-indexed).
  Future<SearchResultModel> searchExplore({
    required String query,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'q': query,
      'page': page,
      'per_page': 30,
    };

    final response = await _client.get<Map<String, dynamic>>(
      '/explore',
      queryParameters: queryParams,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) {
      return SearchResultModel.empty();
    }

    return SearchResultModel.fromStoreJson(
      data,
      page: page,
      perPage: 30,
    );
  }

  // ── Repository Detail Endpoints ─────────────────────────────────────────

  /// Get detailed information about a specific repository.
  ///
  /// [owner] - Repository owner login.
  /// [name] - Repository name.
  Future<RepositoryModel> getRepository(
    String owner,
    String name,
  ) async {
    final path = '/repos/$owner/$name';

    final response = await _client.get<Map<String, dynamic>>(
      path,
      customBaseUrl: _storeBaseUrl,
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
  ///
  /// [owner] - Repository owner login.
  /// [name] - Repository name.
  Future<List<ReleaseModel>> getReleases(
    String owner,
    String name,
  ) async {
    final path = '/repos/$owner/$name/releases';

    final response = await _client.get<List<dynamic>>(
      path,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => ReleaseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get the README content for a specific repository.
  ///
  /// [owner] - Repository owner login.
  /// [name] - Repository name.
  ///
  /// Returns the raw markdown content of the README file.
  Future<String> getReadme(String owner, String name) async {
    final path = '/repos/$owner/$name/readme';

    final response = await _client.get<Map<String, dynamic>>(
      path,
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;

    // The store API may return the content directly or base64 encoded.
    if (data == null) {
      throw ApiException(
        message: 'README not found for $owner/$name',
        statusCode: 404,
      );
    }

    // Check if content is returned directly as a string
    if (data.containsKey('content')) {
      final content = data['content'];
      if (content is String) {
        // Check if it's base64 encoded
        if (data['encoding'] == 'base64') {
          return _decodeBase64(content);
        }
        return content;
      }
    }

    // Check for a markdown field directly
    if (data.containsKey('markdown')) {
      return data['markdown'] as String;
    }

    throw ApiException(
      message: 'Could not parse README for $owner/$name',
      statusCode: 500,
    );
  }

  // ── User Profile Endpoints ──────────────────────────────────────────────

  /// Get the public profile of a GitHub user.
  ///
  /// [username] - GitHub username.
  Future<UserModel> getUserProfile(String username) async {
    final path = '/users/$username';

    final response = await _client.get<Map<String, dynamic>>(
      path,
      customBaseUrl: _storeBaseUrl,
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

  // ── Categories Endpoint ─────────────────────────────────────────────────

  /// Get all available categories for browsing.
  ///
  /// This returns a list of category objects with their topics and metadata.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client.get<List<dynamic>>(
      '/categories',
      customBaseUrl: _storeBaseUrl,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ── Helper Methods ──────────────────────────────────────────────────────

  /// Decode a base64-encoded string, handling whitespace and padding.
  String _decodeBase64(String input) {
    // GitHub API base64 output has line breaks every 76 characters
    final cleaned = input.replaceAll('\n', '').replaceAll('\r', '');
    // Pad if necessary
    String padded = cleaned;
    switch (cleaned.length % 4) {
      case 1:
        padded += '===';
        break;
      case 2:
        padded += '==';
        break;
      case 3:
        padded += '=';
        break;
    }
    return String.fromCharCodes(
      // ignore: deprecated_member_use
      _base64Decode(padded),
    );
  }

  /// Simple base64 decoder using Dart's built-in support.
  static List<int> _base64Decode(String source) {
    // Using a simple approach since we're avoiding unnecessary imports
    const base64Chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = <int>[];

    // Remove padding
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

      final padding = 4 - chunk.length;

      if (chunk.length >= 2) {
        result.add((n >> 16) & 0xFF);
      }
      if (chunk.length >= 3) {
        result.add((n >> 8) & 0xFF);
      }
      if (chunk.length >= 4) {
        result.add(n & 0xFF);
      }
    }

    return result;
  }
}
