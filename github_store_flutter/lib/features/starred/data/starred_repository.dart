import '../../../core/models/repository_model.dart';
import '../../../core/network/github_api.dart';

/// Repository for managing starred repositories via the GitHub API.
///
/// Unlike favorites (which are stored locally), starred repos require GitHub
/// authentication and interact with the GitHub REST API.
class StarredRepository {
  StarredRepository({required GitHubApi gitHubApi}) : _gitHubApi = gitHubApi;

  final GitHubApi _gitHubApi;

  // ── Query Methods ───────────────────────────────────────────────────────

  /// Get a page of starred repositories for the authenticated user.
  ///
  /// [page] — page number (1-indexed).
  /// [perPage] — results per page (max 100).
  Future<List<RepositoryModel>> getStarredRepos({
    int page = 1,
    int perPage = 30,
  }) async {
    final repos = await _gitHubApi.getStarredRepos(
      page: page,
      perPage: perPage,
    );
    return repos;
  }

  /// Check whether the authenticated user has starred a repository.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  ///
  /// Returns `true` if starred, `false` otherwise. Returns `false` if not
  /// authenticated.
  Future<bool> checkStarred(String owner, String name) async {
    try {
      return await _gitHubApi.checkStarred(owner, name);
    } catch (_) {
      return false;
    }
  }

  // ── Mutation Methods ────────────────────────────────────────────────────

  /// Star a repository on behalf of the authenticated user.
  ///
  /// Throws an exception if the request fails (e.g. not authenticated).
  Future<void> starRepo(String owner, String name) async {
    await _gitHubApi.starRepo(owner, name);
  }

  /// Unstar a repository on behalf of the authenticated user.
  ///
  /// Throws an exception if the request fails.
  Future<void> unstarRepo(String owner, String name) async {
    await _gitHubApi.unstarRepo(owner, name);
  }

  /// Get all starred repositories across all pages.
  ///
  /// Paginates through all pages to fetch every starred repo for the
  /// authenticated user. Use with caution for users with many stars.
  Future<List<RepositoryModel>> getAllStarredRepos() async {
    return _gitHubApi.getAllStarredRepos();
  }

  /// Check whether the GitHub API client is currently authenticated.
  bool get isAuthenticated => _gitHubApi.isAuthenticated;
}
