import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/release_asset_model.dart';
import '../../../core/models/release_model.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/github_api.dart';
import '../../../core/network/github_store_api.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/details_repository.dart';

// ── Infrastructure Providers ──────────────────────────────────────────────

/// Provider for the GitHub REST API client (authenticated endpoints).
final gitHubApiProvider = Provider<GitHubApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GitHubApi(apiClient);
});

/// Provider for the details repository.
final detailsRepositoryProvider = Provider<DetailsRepository>((ref) {
  final storeApi = ref.watch(githubStoreApiProvider);
  final gitHubApi = ref.watch(gitHubApiProvider);
  final cache = ref.watch(cacheManagerProvider);
  final db = ref.watch(databaseProvider);
  return DetailsRepository(
    storeApi: storeApi,
    gitHubApi: gitHubApi,
    cache: cache,
    database: db,
  );
});

// ── Family Key Helpers ────────────────────────────────────────────────────

/// Key class for the repository details family provider.
class RepoParam {
  const RepoParam(this.owner, this.name);

  final String owner;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoParam &&
          runtimeType == other.runtimeType &&
          owner == other.owner &&
          name == other.name;

  @override
  int get hashCode => Object.hash(owner, name);
}

// ── Repository Details Provider ───────────────────────────────────────────

/// Provides the full [RepositoryModel] for a given owner/name.
final repositoryProvider =
    AsyncNotifierProvider.family<RepositoryNotifier, RepositoryModel, RepoParam>(
  RepositoryNotifier.new,
);

class RepositoryNotifier
    extends FamilyAsyncNotifier<RepositoryModel, RepoParam> {
  @override
  Future<RepositoryModel> build(RepoParam param) async {
    final repo = ref.watch(detailsRepositoryProvider);
    return repo.getRepository(param.owner, param.name);
  }

  /// Force refresh the repository data.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => future);
  }
}

// ── Releases Provider ─────────────────────────────────────────────────────

/// Provides the list of [ReleaseModel] for a given owner/name.
final releasesProvider =
    AsyncNotifierProvider.family<ReleasesNotifier, List<ReleaseModel>, RepoParam>(
  ReleasesNotifier.new,
);

class ReleasesNotifier
    extends FamilyAsyncNotifier<List<ReleaseModel>, RepoParam> {
  @override
  Future<List<ReleaseModel>> build(RepoParam param) async {
    final repo = ref.watch(detailsRepositoryProvider);
    return repo.getReleases(param.owner, param.name);
  }

  /// Force refresh releases.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => future);
  }
}

// ── README Provider ───────────────────────────────────────────────────────

/// Provides the README markdown content for a given owner/name.
final readmeProvider =
    AsyncNotifierProvider.family<ReadmeNotifier, String, RepoParam>(
  ReadmeNotifier.new,
);

class ReadmeNotifier extends FamilyAsyncNotifier<String, RepoParam> {
  @override
  Future<String> build(RepoParam param) async {
    final repo = ref.watch(detailsRepositoryProvider);
    return repo.getReadme(param.owner, param.name);
  }

  /// Force refresh README.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => future);
  }
}

// ── Selected Release Index ────────────────────────────────────────────────

/// Currently selected release tab index (defaults to 0 = latest).
final selectedReleaseIndexProvider = StateProvider<int>((ref) => 0);

// ── Release Type Filter ───────────────────────────────────────────────────

/// Filter for release types: 'all', 'stable', 'prerelease'.
final releaseFilterProvider = StateProvider<String>((ref) => 'all');

// ── Starred Provider ──────────────────────────────────────────────────────

/// Whether the authenticated user has starred the repo.
final starredProvider =
    StateNotifierProvider.family<StarredNotifier, bool, RepoParam>(
  StarredNotifier.new,
);

class StarredNotifier extends StateNotifier<bool> {
  StarredNotifier(this.ref, this.param) : super(false) {
    _init();
  }

  final Ref ref;
  final RepoParam param;

  Future<void> _init() async {
    try {
      final repo = ref.read(detailsRepositoryProvider);
      final isStarred = await repo.checkStarred(param.owner, param.name);
      if (mounted) state = isStarred;
    } catch (_) {
      // Not authenticated or other error — stay false
    }
  }

  /// Toggle star status.
  Future<void> toggle() async {
    final repo = ref.read(detailsRepositoryProvider);
    try {
      if (state) {
        await repo.unstarRepo(param.owner, param.name);
        if (mounted) state = false;
      } else {
        await repo.starRepo(param.owner, param.name);
        if (mounted) state = true;
      }
    } catch (e) {
      // Silently handle star/unstar errors
    }
  }
}

// ── Favorited Provider ────────────────────────────────────────────────────

/// Whether the repo is in the user's local favorites.
final favoritedProvider =
    StateNotifierProvider.family<FavoritedNotifier, bool, RepoParam>(
  FavoritedNotifier.new,
);

class FavoritedNotifier extends StateNotifier<bool> {
  FavoritedNotifier(this.ref, this.param) : super(false) {
    _init();
  }

  final Ref ref;
  final RepoParam param;

  Future<void> _init() async {
    try {
      final repo = ref.read(detailsRepositoryProvider);
      final isFav = await repo.isFavorited(param.owner, param.name);
      if (mounted) state = isFav;
    } catch (_) {}
  }

  /// Toggle favorite status.
  Future<void> toggle() async {
    final repo = ref.read(detailsRepositoryProvider);
    try {
      await repo.toggleFavorite(param.owner, param.name);
      if (mounted) state = !state;
    } catch (_) {}
  }
}

// ── Download State Provider ───────────────────────────────────────────────

/// Manages download state (which asset is downloading, progress, errors).
class DownloadState {
  const DownloadState({
    this.isDownloading = false,
    this.assetName,
    this.progress = 0.0,
    this.error,
    this.completedPath,
  });

  final bool isDownloading;
  final String? assetName;
  final double progress;
  final String? error;
  final String? completedPath;

  DownloadState copyWith({
    bool? isDownloading,
    String? assetName,
    double? progress,
    String? error,
    String? completedPath,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      assetName: assetName ?? this.assetName,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      completedPath: completedPath ?? this.completedPath,
    );
  }
}

final downloadProvider =
    StateNotifierProvider.autoDispose<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier(this.ref) : super(const DownloadState());

  final Ref ref;

  /// Start downloading a release asset.
  Future<String?> downloadAsset({
    required ReleaseAssetModel asset,
    required String owner,
    required String name,
    required String version,
  }) async {
    state = DownloadState(
      isDownloading: true,
      assetName: asset.name,
      progress: 0.0,
    );

    try {
      final repo = ref.read(detailsRepositoryProvider);
      final filePath = await repo.downloadRelease(asset, owner, name, version);

      if (mounted) {
        state = DownloadState(
          isDownloading: false,
          assetName: asset.name,
          progress: 1.0,
          completedPath: filePath,
        );
      }
      return filePath;
    } catch (e) {
      if (mounted) {
        state = DownloadState(
          isDownloading: false,
          assetName: asset.name,
          error: e.toString(),
        );
      }
      return null;
    }
  }

  /// Reset download state.
  void reset() {
    state = const DownloadState();
  }
}

// ── Recently Viewed Helper ────────────────────────────────────────────────

/// Marks a repo as recently viewed. Call when the details screen opens.
final markRecentlyViewedProvider =
    FutureProvider.family<void, RepoParam>((ref, param) async {
  final repo = ref.watch(detailsRepositoryProvider);
  await repo.addRecentlyViewed(param.owner, param.name);
});
