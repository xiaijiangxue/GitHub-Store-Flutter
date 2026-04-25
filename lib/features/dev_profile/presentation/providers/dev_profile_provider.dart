import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/repository_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/github_store_api.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../data/dev_profile_repository.dart';

// Re-export shared providers
export '../../../home/presentation/providers/home_provider.dart'
    show databaseProvider, cacheManagerProvider, githubStoreApiProvider,
        apiClientProvider;

// ── Filter & Sort Enums ───────────────────────────────────────────────────

/// Filter options for the repository list.
enum RepoFilter {
  all('All'),
  withReleases('With Releases'),
  installed('Installed'),
  favorites('Favorites');

  const RepoFilter(this.label);
  final String label;
}

/// Sort options for the repository list.
enum RepoSort {
  recentlyUpdated('Recently Updated'),
  mostStars('Most Stars'),
  name('Name');

  const RepoSort(this.label);
  final String label;
}

// ── Infrastructure Providers ──────────────────────────────────────────────

/// Provider for the developer profile repository.
final devProfileRepositoryProvider = Provider<DevProfileRepository>((ref) {
  final storeApi = ref.watch(githubStoreApiProvider);
  final cache = ref.watch(cacheManagerProvider);
  final apiClient = ref.watch(apiClientProvider);
  return DevProfileRepository(
    storeApi: storeApi,
    cache: cache,
    apiClient: apiClient,
  );
});

// ── State Providers ───────────────────────────────────────────────────────

/// Repository filter.
final repoFilterProvider = StateProvider<RepoFilter>((ref) {
  return RepoFilter.all;
});

/// Repository sort.
final repoSortProvider = StateProvider<RepoSort>((ref) {
  return RepoSort.recentlyUpdated;
});

/// Repository search query.
final repoSearchProvider = StateProvider<String>((ref) {
  return '';
});

// ── User Profile Provider ─────────────────────────────────────────────────

/// Provider for a user's profile data, parameterized by username.
final userProfileProvider = FutureProvider.family<UserModel, String>(
  (ref, username) async {
    final repo = ref.watch(devProfileRepositoryProvider);
    return repo.getUserProfile(username);
  },
);

// ── User Repos Provider (manual family approach) ─────────────────────────

/// Internal state holder for user repos pagination.
class _UserReposState {
  _UserReposState({
    this.repos = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoading = false,
  });

  final List<RepositoryModel> repos;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;

  _UserReposState copyWith({
    List<RepositoryModel>? repos,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
  }) {
    return _UserReposState(
      repos: repos ?? this.repos,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing user repos with pagination.
class UserReposNotifier extends StateNotifier<_UserReposState> {
  UserReposNotifier(this._repo) : super(_UserReposState());

  final DevProfileRepository _repo;

  /// Convenience getters delegating to the internal state.
  List<RepositoryModel> get repos => state.repos;
  bool get hasMore => state.hasMore;
  bool get isLoading => state.isLoading;

  /// Load the initial set of repositories for a username.
  Future<void> loadRepos(String username) async {
    state = state.copyWith(isLoading: true);

    try {
      final repos = await _repo.getUserRepos(username, page: 1);
      state = _UserReposState(
        repos: repos,
        currentPage: 1,
        hasMore: repos.length >= 30,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[UserReposNotifier] Failed to load repos: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load more repositories (next page).
  Future<void> loadMore(String username) async {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final moreRepos = await _repo.getUserRepos(username, page: nextPage);

      state = state.copyWith(
        repos: [...state.repos, ...moreRepos],
        currentPage: nextPage,
        hasMore: moreRepos.length >= 30,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[UserReposNotifier] Failed to load more repos: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Refresh all repos from scratch.
  Future<void> refresh(String username) async {
    state = _UserReposState();
    await loadRepos(username);
  }
}

/// Provider for the user repos notifier.
final userReposNotifierProvider = Provider<UserReposNotifier>((ref) {
  final repo = ref.watch(devProfileRepositoryProvider);
  return UserReposNotifier(repo);
});

/// Provider that exposes the list of repos for the current profile.
final userReposProvider = Provider<List<RepositoryModel>>((ref) {
  return ref.watch(userReposNotifierProvider).state.repos;
});

/// Whether more repos are available.
final userReposHasMoreProvider = Provider<bool>((ref) {
  return ref.watch(userReposNotifierProvider).state.hasMore;
});

/// Whether repos are currently being loaded.
final userReposIsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userReposNotifierProvider).state.isLoading;
});

// ── Filtered Repos Provider ───────────────────────────────────────────────

/// Computed provider that filters and sorts repos based on current filters.
final filteredReposProvider = Provider<List<RepositoryModel>>((ref) {
  final repos = ref.watch(userReposProvider);
  final filter = ref.watch(repoFilterProvider);
  final sort = ref.watch(repoSortProvider);
  final search = ref.watch(repoSearchProvider);

  // Filter
  var filtered = repos.where((repo) {
    switch (filter) {
      case RepoFilter.all:
        return true;
      case RepoFilter.withReleases:
        return repo.hasLatestRelease;
      case RepoFilter.installed:
        return false;
      case RepoFilter.favorites:
        return repo.isFavorited;
    }
  }).toList();

  // Search
  if (search.isNotEmpty) {
    final lower = search.toLowerCase();
    filtered = filtered.where((repo) {
      return repo.name.toLowerCase().contains(lower) ||
          (repo.description?.toLowerCase().contains(lower) ?? false) ||
          (repo.language?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  // Sort
  switch (sort) {
    case RepoSort.recentlyUpdated:
      filtered.sort((a, b) => (b.pushedAt ?? b.updatedAt ?? DateTime(2000))
          .compareTo(a.pushedAt ?? a.updatedAt ?? DateTime(2000)));
    case RepoSort.mostStars:
      filtered.sort((a, b) => b.stars.compareTo(a.stars));
    case RepoSort.name:
      filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  return filtered;
});
