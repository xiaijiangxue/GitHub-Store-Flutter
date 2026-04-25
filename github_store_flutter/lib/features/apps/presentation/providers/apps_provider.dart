import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/installed_app_model.dart';
import '../../../core/network/github_store_api.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/apps_repository.dart';

// Re-export shared providers
export '../../home/presentation/providers/home_provider.dart'
    show databaseProvider, cacheManagerProvider, githubStoreApiProvider;

// ── Infrastructure Providers ──────────────────────────────────────────────

/// Provider for the apps repository.
final appsRepositoryProvider = Provider<AppsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final storeApi = ref.watch(githubStoreApiProvider);
  return AppsRepository(database: db, storeApi: storeApi);
});

// ── Sort & Filter Enums ───────────────────────────────────────────────────

/// Sort mode for the installed apps list.
enum AppsSortMode {
  /// Apps with updates available are shown first.
  updatesFirst('Updates First'),

  /// Alphabetical by app name.
  name('Name'),

  /// Most recently checked for updates first.
  recentlyUpdated('Recently Updated');

  const AppsSortMode(this.label);
  final String label;
}

// ── State Providers ───────────────────────────────────────────────────────

/// Current sort mode for the apps list.
final sortModeProvider = StateProvider<AppsSortMode>((ref) {
  return AppsSortMode.updatesFirst;
});

/// Search query for filtering apps.
final searchQueryProvider = StateProvider<String>((ref) {
  return '';
});

/// Count of apps that have available updates.
final updateCountProvider = StateProvider<int>((ref) {
  return 0;
});

/// Whether an update check is currently in progress.
final isCheckingUpdatesProvider = StateProvider<bool>((ref) {
  return false;
});

/// Whether an export/import operation is in progress.
final isOperationProvider = StateProvider<bool>((ref) {
  return false;
});

// ── Async Data Provider ───────────────────────────────────────────────────

/// Provider for the list of installed apps.
final installedAppsProvider =
    AsyncNotifierProvider<InstalledAppsNotifier, List<InstalledAppModel>>(
  InstalledAppsNotifier.new,
);

class InstalledAppsNotifier
    extends AsyncNotifier<List<InstalledAppModel>> {
  @override
  Future<List<InstalledAppModel>> build() async {
    final repo = ref.read(appsRepositoryProvider);
    return repo.getInstalledApps();
  }

  /// Refresh the apps list from the database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(appsRepositoryProvider);
      return repo.getInstalledApps();
    });
  }

  /// Update a single app to its latest version.
  Future<void> updateApp(InstalledAppModel app) async {
    final repo = ref.read(appsRepositoryProvider);
    await repo.updateInstalledApp(
      app.owner,
      app.name,
      version: app.latestVersion,
      assetUrl: app.installedAssetUrl,
    );
    await refresh();
  }

  /// Update all apps that have available updates.
  Future<void> updateAll() async {
    final apps = state.valueOrNull ?? [];
    final repo = ref.read(appsRepositoryProvider);
    final updatable = apps.where((a) => a.isUpdateAvailable).toList();

    for (final app in updatable) {
      await repo.updateInstalledApp(
        app.owner,
        app.name,
        version: app.latestVersion,
        assetUrl: app.installedAssetUrl,
      );
    }

    await refresh();
  }

  /// Uninstall (remove) an app from tracking.
  Future<void> uninstall(InstalledAppModel app) async {
    final repo = ref.read(appsRepositoryProvider);
    await repo.removeInstalledApp(app.owner, app.name);
    await refresh();
  }

  /// Check all apps for updates.
  Future<void> checkUpdates() async {
    ref.read(isCheckingUpdatesProvider.notifier).state = true;
    try {
      final repo = ref.read(appsRepositoryProvider);
      final apps = state.valueOrNull ?? [];
      final updated = await repo.checkForUpdates(apps);
      state = AsyncData(updated);

      final updateCount = updated.where((a) => a.isUpdateAvailable).length;
      ref.read(updateCountProvider.notifier).state = updateCount;
    } catch (e, st) {
      debugPrint('[InstalledAppsNotifier] Check updates failed: $e');
      state = AsyncError(e, st);
    } finally {
      ref.read(isCheckingUpdatesProvider.notifier).state = false;
    }
  }

  /// Export apps to clipboard as JSON.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> exportApps() async {
    ref.read(isOperationProvider.notifier).state = true;
    try {
      final repo = ref.read(appsRepositoryProvider);
      final json = await repo.exportApps();
      await Clipboard.setData(ClipboardData(text: json));
      return true;
    } catch (e) {
      debugPrint('[InstalledAppsNotifier] Export failed: $e');
      return false;
    } finally {
      ref.read(isOperationProvider.notifier).state = false;
    }
  }

  /// Import apps from a JSON string.
  ///
  /// Returns the number of apps imported, or `-1` on failure.
  Future<int> importApps(String json) async {
    ref.read(isOperationProvider.notifier).state = true;
    try {
      final repo = ref.read(appsRepositoryProvider);
      final count = await repo.importApps(json);
      await refresh();
      return count;
    } catch (e) {
      debugPrint('[InstalledAppsNotifier] Import failed: $e');
      return -1;
    } finally {
      ref.read(isOperationProvider.notifier).state = false;
    }
  }
}
