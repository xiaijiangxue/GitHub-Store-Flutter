import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/repository_model.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/favorites_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────

/// Provider for the [FavoritesRepository].
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FavoritesRepository(database: db);
});

// ── Sort Options ───────────────────────────────────────────────────────────

/// Available sort modes for the favorites list.
enum FavoritesSortMode {
  name,
  stars,
  recentlyAdded;

  String get displayName => switch (this) {
        FavoritesSortMode.name => 'Name',
        FavoritesSortMode.stars => 'Stars',
        FavoritesSortMode.recentlyAdded => 'Recently Added',
      };
}

// ── State Providers ────────────────────────────────────────────────────────

/// Current sort mode for favorites.
final favoritesSortModeProvider = StateProvider<FavoritesSortMode>((ref) {
  return FavoritesSortMode.recentlyAdded;
});

/// Current search query for filtering favorites.
final favoritesSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

// ── Favorites List Provider ────────────────────────────────────────────────

/// Provider that loads and manages the favorites list.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<RepositoryModel>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<List<RepositoryModel>> {
  @override
  Future<List<RepositoryModel>> build() async {
    final repo = ref.watch(favoritesRepositoryProvider);

    // Re-fetch when sort mode or search query changes
    ref.watch(favoritesSortModeProvider);
    ref.watch(favoritesSearchQueryProvider);

    let rawFavorites = await repo.getAllFavorites();

    // Apply search filter
    final query = ref.read(favoritesSearchQueryProvider).toLowerCase();
    if (query.isNotEmpty) {
      rawFavorites = rawFavorites
          .where((r) =>
              r.fullName.toLowerCase().contains(query) ||
              (r.description?.toLowerCase().contains(query) ?? false) ||
              (r.language?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Apply sort
    final sortMode = ref.read(favoritesSortModeProvider);
    switch (sortMode) {
      case FavoritesSortMode.name:
        rawFavorites.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case FavoritesSortMode.stars:
        rawFavorites.sort((a, b) => b.stars.compareTo(a.stars));
        break;
      case FavoritesSortMode.recentlyAdded:
        rawFavorites.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
        break;
    }

    return rawFavorites;
  }

  /// Add a repository to favorites.
  Future<void> addFavorite({
    required String owner,
    required String name,
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.toggleFavorite(
      owner,
      name,
      description: description,
      avatarUrl: avatarUrl,
      stars: stars,
      language: language,
    );
    ref.invalidateSelf();
  }

  /// Remove a repository from favorites.
  Future<void> removeFavorite(String owner, String name) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.removeFavorite(owner, name);
    ref.invalidateSelf();
  }

  /// Toggle the favorite status.
  Future<void> toggleFavorite({
    required String owner,
    required String name,
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.toggleFavorite(
      owner,
      name,
      description: description,
      avatarUrl: avatarUrl,
      stars: stars,
      language: language,
    );
    ref.invalidateSelf();
  }

  /// Clear all favorites.
  Future<void> clearAll() async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.clearAll();
    ref.invalidateSelf();
  }

  /// Force refresh the favorites list.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// ── Individual Favorite Check Provider ─────────────────────────────────────

/// Key for the [isFavoriteProvider] family.
class FavoriteKey {
  const FavoriteKey(this.owner, this.name);

  final String owner;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteKey &&
          owner == other.owner &&
          name == other.name;

  @override
  int get hashCode => Object.hash(owner, name);
}

/// Checks whether a specific repository is in the user's favorites.
final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, FavoriteKey>((ref, key) async {
  final repo = ref.watch(favoritesRepositoryProvider);
  return repo.isFavorited(key.owner, key.name);
});
