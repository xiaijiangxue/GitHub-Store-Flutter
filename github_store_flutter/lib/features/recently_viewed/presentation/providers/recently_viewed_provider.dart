import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/presentation/providers/home_provider.dart';
import '../../data/recently_viewed_repository.dart';

// Re-export RecentlyViewedItem for convenience in the screen.
export '../../data/recently_viewed_repository.dart' show RecentlyViewedItem;

// ── Repository Provider ────────────────────────────────────────────────────

/// Provider for the [RecentlyViewedRepository].
final recentlyViewedRepositoryProvider = Provider<RecentlyViewedRepository>(
  (ref) {
    final db = ref.watch(databaseProvider);
    return RecentlyViewedRepository(database: db);
  },
);

// ── Recently Viewed Provider ───────────────────────────────────────────────

/// Provider that loads and manages the recently viewed list.
final recentlyViewedProvider = AsyncNotifierProvider<RecentlyViewedNotifier,
    List<RecentlyViewedItem>>(
  RecentlyViewedNotifier.new,
);

class RecentlyViewedNotifier
    extends AsyncNotifier<List<RecentlyViewedItem>> {
  static const int _defaultLimit = 50;

  @override
  Future<List<RecentlyViewedItem>> build() async {
    final repo = ref.watch(recentlyViewedRepositoryProvider);
    return repo.getAllRecentlyViewed(limit: _defaultLimit);
  }

  /// Refresh the recently viewed list.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Remove a single recently viewed entry.
  Future<void> remove(String owner, String name) async {
    final repo = ref.read(recentlyViewedRepositoryProvider);
    await repo.removeRecentlyViewed(owner, name);
    ref.invalidateSelf();
  }

  /// Clear all viewing history.
  Future<void> clearAll() async {
    final repo = ref.read(recentlyViewedRepositoryProvider);
    await repo.clearAll();
    ref.invalidateSelf();
  }
}
