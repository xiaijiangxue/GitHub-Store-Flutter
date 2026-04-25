import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../home/presentation/providers/home_provider.dart';

// Re-export shared providers
export '../../../home/presentation/providers/home_provider.dart'
    show databaseProvider;

// ── Profile Stats Model ────────────────────────────────────────────────────

/// Computed statistics for the user profile.
class ProfileStats {
  const ProfileStats({
    this.downloadedCount = 0,
    this.installedCount = 0,
    this.viewedCount = 0,
    this.favoritesCount = 0,
  });

  final int downloadedCount;
  final int installedCount;
  final int viewedCount;
  final int favoritesCount;
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Provider that reads counts from the database and exposes them as
/// a [ProfileStats] model.
final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final db = ref.watch(databaseProvider);

  final results = await Future.wait([
    // Downloaded count: distinct completed downloads
    (() async {
      final downloads =
          await (db.select(db.downloads)
                ..where((t) => t.status.equals('completed')))
              .get();
      return downloads
          .map((d) => d.repoFullName)
          .toSet()
          .length;
    })(),

    // Installed count: completed installations (not uninstalled)
    (() async {
      final installations =
          await (db.select(db.installations)
                ..where((t) => t.status.equals('completed')))
              .get();
      return installations
          .map((i) => i.repoFullName)
          .toSet()
          .length;
    })(),

    // Viewed count: total recently viewed entries
    (() async {
      final viewed = await db.select(db.recentlyViewed).get();
      return viewed.length;
    })(),

    // Favorites count: repos marked as favorite
    (() async {
      final repos = await (db.select(db.repositories)
            ..where((t) => t.isFavorite.equals(true)))
          .get();
      return repos.length;
    })(),
  ]);

  return ProfileStats(
    downloadedCount: results[0] as int,
    installedCount: results[1] as int,
    viewedCount: results[2] as int,
    favoritesCount: results[3] as int,
  );
});
