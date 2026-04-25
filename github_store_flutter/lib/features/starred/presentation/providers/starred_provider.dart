import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/repository_model.dart';
import '../../../../core/network/github_api.dart';
import '../../../details/presentation/providers/details_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../data/starred_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────

/// Provider for the [StarredRepository].
final starredRepositoryProvider = Provider<StarredRepository>((ref) {
  final gitHubApi = ref.watch(gitHubApiProvider);
  return StarredRepository(gitHubApi: gitHubApi);
});

// ── Auth State Provider ────────────────────────────────────────────────────

/// Whether the user is authenticated (has a GitHub token).
///
/// Reads from the existing auth infrastructure.
final starredAuthProvider = Provider<bool>((ref) {
  final repo = ref.watch(starredRepositoryProvider);
  return repo.isAuthenticated;
});

// ── State Providers ────────────────────────────────────────────────────────

/// Whether starred repos are currently loading.
final starredLoadingProvider = StateProvider<bool>((ref) => false);

/// Whether there are more starred repos to load.
final starredHasMoreProvider = StateProvider<bool>((ref) => true);

/// Current page for pagination.
final starredCurrentPageProvider = StateProvider<int>((ref) => 1);

/// Whether we are loading more pages.
final starredLoadingMoreProvider = StateProvider<bool>((ref) => false);

/// Error message for starred repos loading.
final starredErrorProvider = StateProvider<String?>((ref) => null);

// ── Starred Repos List Provider ────────────────────────────────────────────

/// Manages the list of starred repositories with pagination support.
final starredReposProvider =
    AsyncNotifierProvider<StarredReposNotifier, List<RepositoryModel>>(
  StarredReposNotifier.new,
);

class StarredReposNotifier extends AsyncNotifier<List<RepositoryModel>> {
  @override
  Future<List<RepositoryModel>> build() async {
    final repo = ref.watch(starredRepositoryProvider);

    // Check authentication first
    if (!repo.isAuthenticated) {
      return [];
    }

    ref.read(starredLoadingProvider.notifier).state = true;
    ref.read(starredErrorProvider.notifier).state = null;
    ref.read(starredCurrentPageProvider.notifier).state = 1;

    try {
      final repos = await repo.getStarredRepos(page: 1, perPage: 30);
      ref.read(starredHasMoreProvider.notifier).state =
          repos.length >= 30;
      return repos;
    } catch (e) {
      ref.read(starredErrorProvider.notifier).state = e.toString();
      rethrow;
    } finally {
      ref.read(starredLoadingProvider.notifier).state = false;
    }
  }

  /// Load the next page of starred repos.
  Future<void> loadMore() async {
    if (ref.read(starredLoadingMoreProvider)) return;
    if (!ref.read(starredHasMoreProvider)) return;

    ref.read(starredLoadingMoreProvider.notifier).state = true;

    try {
      final nextPage = ref.read(starredCurrentPageProvider) + 1;
      final repo = ref.read(starredRepositoryProvider);
      final moreRepos = await repo.getStarredRepos(
        page: nextPage,
        perPage: 30,
      );

      final current = state.valueOrNull ?? [];
      state = AsyncData([...current, ...moreRepos]);

      ref.read(starredCurrentPageProvider.notifier).state = nextPage;
      ref.read(starredHasMoreProvider.notifier).state =
          moreRepos.length >= 30;
    } catch (e) {
      ref.read(starredErrorProvider.notifier).state =
          'Failed to load more: $e';
    } finally {
      ref.read(starredLoadingMoreProvider.notifier).state = false;
    }
  }

  /// Refresh starred repos from the first page.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Unstar a repository and remove it from the list.
  Future<void> unstar(String owner, String name) async {
    final repo = ref.read(starredRepositoryProvider);
    await repo.unstarRepo(owner, name);

    // Remove from the local list
    final current = state.valueOrNull ?? [];
    final updated =
        current.where((r) => r.fullName != '$owner/$name').toList();
    state = AsyncData(updated);
  }
}
