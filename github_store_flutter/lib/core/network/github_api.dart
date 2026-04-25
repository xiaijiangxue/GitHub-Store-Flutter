import 'package:dio/dio.dart';

import '../models/repository_model.dart';
import '../models/user_model.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

/// API client for the GitHub REST API (authenticated endpoints).
///
/// This service handles GitHub API calls that require authentication,
/// such as starring repos, checking star status, and fetching user data.
class GitHubApi {
  GitHubApi(this._client);

  final ApiClient _client;

  // ── Star Management ─────────────────────────────────────────────────────

  /// Check whether the authenticated user has starred a repository.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  ///
  /// Returns `true` if the repo is starred, `false` otherwise.
  Future<bool> checkStarred(String owner, String repo) async {
    final path = '/user/starred/$owner/$repo';

    try {
      final response = await _client.get<dynamic>(
        path,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// Star a repository on behalf of the authenticated user.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  ///
  /// Throws [ApiException] if the request fails (e.g. not authenticated).
  Future<void> starRepo(String owner, String repo) async {
    final path = '/user/starred/$owner/$repo';

    final response = await _client.put<dynamic>(
      path,
      options: Options(
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Content-Length': '0',
        },
      ),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        message: 'Failed to star $owner/$repo',
        statusCode: response.statusCode,
      );
    }
  }

  /// Unstar a repository on behalf of the authenticated user.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  ///
  /// Throws [ApiException] if the request fails.
  Future<void> unstarRepo(String owner, String repo) async {
    final path = '/user/starred/$owner/$repo';

    final response = await _client.delete<dynamic>(
      path,
      options: Options(
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException(
        message: 'Failed to unstar $owner/$repo',
        statusCode: response.statusCode,
      );
    }
  }

  /// Star or unstar a repository based on the desired state.
  ///
  /// Convenience method that calls [starRepo] or [unstarRepo].
  Future<void> setStarred(String owner, String repo, bool starred) async {
    if (starred) {
      await starRepo(owner, repo);
    } else {
      await unstarRepo(owner, repo);
    }
  }

  // ── Starred Repositories ────────────────────────────────────────────────

  /// Get repositories starred by the authenticated user.
  ///
  /// [page] - Page number (1-indexed).
  /// [perPage] - Number of results per page (max 100).
  /// [sort] - Sort field: 'created' or 'updated'.
  Future<List<RepositoryModel>> getStarredRepos({
    int page = 1,
    int perPage = 30,
    String sort = 'created',
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'sort': sort,
    };

    final response = await _client.get<List<dynamic>>(
      ApiConstants.userStarredUrl,
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get all starred repositories across all pages.
  ///
  /// Uses pagination to fetch every starred repo for the authenticated user.
  /// Be cautious with large numbers of starred repos.
  Future<List<RepositoryModel>> getAllStarredRepos({
    String sort = 'created',
  }) async {
    return _client.fetchAllPages<RepositoryModel>(
      ApiConstants.userStarredUrl,
      queryParameters: {'sort': sort},
      perPage: 100,
      fromJson: (json) => RepositoryModel.fromJson(json),
    );
  }

  // ── Authenticated User ──────────────────────────────────────────────────

  /// Get the authenticated user's profile.
  ///
  /// Returns full [UserModel] with private fields (totalPrivateRepos, etc.)
  /// if authenticated.
  Future<UserModel> getCurrentUser() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiConstants.userUrl,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(
        message: 'Failed to fetch current user profile',
        statusCode: 401,
      );
    }

    return UserModel.fromJson(data);
  }

  /// Get repositories owned by the authenticated user.
  ///
  /// [page] - Page number (1-indexed).
  /// [perPage] - Results per page (max 100).
  /// [sort] - Sort field: 'created', 'updated', 'pushed', 'full_name'.
  /// [type] - Filter by type: 'all', 'owner', 'member'.
  Future<List<RepositoryModel>> getUserRepos({
    int page = 1,
    int perPage = 30,
    String sort = 'updated',
    String type = 'owner',
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'sort': sort,
      'type': type,
    };

    final response = await _client.get<List<dynamic>>(
      ApiConstants.userReposUrl,
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data == null) return [];

    return data
        .map((e) => RepositoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Repository Details (Authenticated) ──────────────────────────────────

  /// Get detailed repository information with enriched authenticated fields.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  Future<RepositoryModel> getRepository(String owner, String repo) async {
    final path = ApiConstants.repositoryUrlPath(owner, repo);

    final response = await _client.get<Map<String, dynamic>>(path);

    final data = response.data;
    if (data == null) {
      throw ApiException(
        message: 'Repository $owner/$repo not found',
        statusCode: 404,
      );
    }

    return RepositoryModel.fromJson(data);
  }

  // ── Watch/Subscribe Management ──────────────────────────────────────────

  /// Check if the authenticated user is watching a repository.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  Future<bool> isWatching(String owner, String repo) async {
    final path = '/repos/$owner/$repo/subscription';

    try {
      final response = await _client.get<dynamic>(path);
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// Subscribe to notifications for a repository.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  /// [subscribed] - Whether to receive notifications.
  /// [ignored] - Whether to ignore all notifications.
  Future<void> watchRepo(
    String owner,
    String repo, {
    bool subscribed = true,
    bool ignored = false,
  }) async {
    final path = '/repos/$owner/$repo/subscription';

    await _client.put<dynamic>(
      path,
      data: {
        'subscribed': subscribed,
        'ignored': ignored,
      },
    );
  }

  /// Unsubscribe from notifications for a repository.
  ///
  /// [owner] - Repository owner login.
  /// [repo] - Repository name.
  Future<void> unwatchRepo(String owner, String repo) async {
    final path = '/repos/$owner/$repo/subscription';

    await _client.delete<dynamic>(path);
  }

  // ── Auth Token Management ───────────────────────────────────────────────

  /// Set the authentication token for subsequent requests.
  void setAuthToken(String token) {
    _client.setAuthToken(token);
  }

  /// Clear the authentication token.
  void clearAuthToken() {
    _client.clearAuthToken();
  }

  /// Check if an auth token is currently set.
  bool get isAuthenticated => _client.isAuthenticated;

  /// Get remaining API requests in the current rate limit window.
  int get remainingRequests => _client.remainingRequests;
}
