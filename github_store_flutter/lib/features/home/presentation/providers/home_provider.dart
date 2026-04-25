import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/github_store_api.dart';
import '../../home/data/home_repository.dart';

// ── Infrastructure Providers ──────────────────────────────────────────────

/// Provider for the local database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Provider for the cache manager.
final cacheManagerProvider = Provider<CacheManager>((ref) {
  final db = ref.watch(databaseProvider);
  return CacheManager(database: db);
});

/// Provider for the GitHub Store API client.
final githubStoreApiProvider = Provider<GitHubStoreApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GitHubStoreApi(apiClient);
});

// Use the code-generated apiClientProvider from api_client.g.dart
// Since we can't reference the generated provider directly without running
// build_runner, we create a fallback that instantiates ApiClient directly.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Provider for the home repository.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final storeApi = ref.watch(githubStoreApiProvider);
  final cache = ref.watch(cacheManagerProvider);
  return HomeRepository(storeApi: storeApi, cache: cache);
});

// ── State Providers ───────────────────────────────────────────────────────

/// Selected platform filter for the home screen.
final homePlatformFilterProvider = StateProvider<String>((ref) {
  return 'all';
});

/// Whether to hide already-seen repositories.
final homeHideSeenProvider = StateProvider<bool>((ref) {
  return false;
});

// ── Async Data Providers ──────────────────────────────────────────────────

/// Trending repositories provider.
final homeTrendingProvider =
    AsyncNotifierProvider<HomeTrendingNotifier, List<RepositoryModel>>(
  HomeTrendingNotifier.new,
);

class HomeTrendingNotifier extends AsyncNotifier<List<RepositoryModel>> {
  @override
  Future<List<RepositoryModel>> build() async {
    final platform = ref.watch(homePlatformFilterProvider);
    final repo = ref.read(homeRepositoryProvider);

    ref.listen(homePlatformFilterProvider, (_, __) {
      _debouncedLoad();
    });

    final repos = await repo.getTrending(platform: platform);

    if (ref.read(homeHideSeenProvider)) {
      return _filterSeen(repos);
    }
    return repos;
  }

  Timer? _debounceTimer;

  void _debouncedLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidateSelf();
    });
  }

  List<RepositoryModel> _filterSeen(List<RepositoryModel> repos) {
    final db = ref.read(databaseProvider);
    // For simplicity, we just return all repos.
    // A full implementation would check recently_viewed table.
    return repos;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Hot releases provider.
final homeHotReleasesProvider =
    AsyncNotifierProvider<HomeHotReleasesNotifier, List<RepositoryModel>>(
  HomeHotReleasesNotifier.new,
);

class HomeHotReleasesNotifier extends AsyncNotifier<List<RepositoryModel>> {
  @override
  Future<List<RepositoryModel>> build() async {
    final platform = ref.watch(homePlatformFilterProvider);
    final repo = ref.read(homeRepositoryProvider);

    ref.listen(homePlatformFilterProvider, (_, __) {
      _debouncedLoad();
    });

    final repos = await repo.getHotReleases(platform: platform);

    if (ref.read(homeHideSeenProvider)) {
      return _filterSeen(repos);
    }
    return repos;
  }

  Timer? _debounceTimer;

  void _debouncedLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidateSelf();
    });
  }

  List<RepositoryModel> _filterSeen(List<RepositoryModel> repos) {
    return repos;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Most popular repositories provider.
final homePopularProvider =
    AsyncNotifierProvider<HomePopularNotifier, List<RepositoryModel>>(
  HomePopularNotifier.new,
);

class HomePopularNotifier extends AsyncNotifier<List<RepositoryModel>> {
  @override
  Future<List<RepositoryModel>> build() async {
    final platform = ref.watch(homePlatformFilterProvider);
    final repo = ref.read(homeRepositoryProvider);

    ref.listen(homePlatformFilterProvider, (_, __) {
      _debouncedLoad();
    });

    final repos = await repo.getMostPopular(platform: platform);

    if (ref.read(homeHideSeenProvider)) {
      return _filterSeen(repos);
    }
    return repos;
  }

  Timer? _debounceTimer;

  void _debouncedLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidateSelf();
    });
  }

  List<RepositoryModel> _filterSeen(List<RepositoryModel> repos) {
    return repos;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Categories provider.
final homeCategoriesProvider =
    FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.getCategories();
});

// ── Refresh Function ──────────────────────────────────────────────────────

/// Refresh all home data by invalidating cache and reloading providers.
final homeRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final repo = ref.read(homeRepositoryProvider);
    await repo.invalidateAllCache();

    // Invalidate all providers to trigger reload
    ref.invalidate(homeTrendingProvider);
    ref.invalidate(homeHotReleasesProvider);
    ref.invalidate(homePopularProvider);
    ref.invalidate(homeCategoriesProvider);
  };
});
