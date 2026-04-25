import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/installed_app_model.dart';
import '../../../core/models/release_model.dart';
import '../../../core/network/github_store_api.dart';

/// Repository for managing installed applications in the local database.
///
/// Tracks which apps are installed on the user's system, their versions,
/// and can check GitHub releases for available updates.
class AppsRepository {
  AppsRepository({
    required AppDatabase database,
    required GitHubStoreApi storeApi,
  })  : _database = database,
        _storeApi = storeApi;

  final AppDatabase _database;
  final GitHubStoreApi _storeApi;

  // ── Query Methods ───────────────────────────────────────────────────────

  /// Get all installed applications from the database.
  ///
  /// Returns active installations (where `uninstalledAt` is null) ordered
  /// by most recently installed first.
  Future<List<InstalledAppModel>> getInstalledApps() async {
    final rows = await (select(_database.installations)
          ..where((t) => t.uninstalledAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.installedAt)]))
        .get();

    return rows.map(_rowToModel).toList();
  }

  /// Stream all installed applications from the database.
  ///
  /// Useful for reactive UI updates when installations change.
  Stream<List<InstalledAppModel>> watchInstalledApps() {
    return (select(_database.installations)
          ..where((t) => t.uninstalledAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.installedAt)]))
        .watch()
        .map((rows) => rows.map(_rowToModel).toList());
  }

  /// Get the total count of installed applications.
  Future<int> getAppCount() async {
    final count = await (select(_database.installations)
          ..where((t) => t.uninstalledAt.isNull()))
        .get();
    return count.length;
  }

  /// Get the count of applications that have available updates.
  ///
  /// This checks all installed apps against their latest GitHub releases.
  Future<int> getUpdateCount() async {
    final apps = await getInstalledApps();
    final updatable = await checkForUpdates(apps);
    return updatable.where((a) => a.isUpdateAvailable).length;
  }

  /// Check if a specific app (by owner/name) is already tracked.
  Future<bool> isAppTracked(String owner, String name) async {
    final fullName = '$owner/$name';
    final existing = await (select(_database.installations)
          ..where((t) =>
              t.repoFullName.equals(fullName) & t.uninstalledAt.isNull()))
        .getSingleOrNull();
    return existing != null;
  }

  // ── Mutation Methods ────────────────────────────────────────────────────

  /// Add a new installed application to the database.
  Future<void> addInstalledApp(InstalledAppModel app) async {
    final fullName = '${app.owner}/${app.name}';
    await into(_database.installations).insert(
      InstallationsCompanion(
        repoFullName: Value(fullName),
        installedVersion: Value(app.installedVersion ?? ''),
        assetName: Value(app.installedAssetName ?? ''),
        installerPath: Value(app.installedAssetUrl ?? ''),
        installMethod: Value(app.installMethod ?? 'manual'),
        status: const Value('completed'),
        installedAt: Value(app.installedAt ?? app.installTime ?? DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Remove an installed application from the database.
  ///
  /// Marks the installation as uninstalled rather than permanently deleting it.
  Future<void> removeInstalledApp(String owner, String name) async {
    final fullName = '$owner/$name';
    final existing = await (select(_database.installations)
          ..where((t) =>
              t.repoFullName.equals(fullName) & t.uninstalledAt.isNull()))
        .getSingleOrNull();

    if (existing != null) {
      await (update(_database.installations)
            ..where((t) => t.id.equals(existing.id)))
          .write(InstallationsCompanion(
        status: const Value('uninstalled'),
        uninstalledAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// Update the version and/or asset URL of an installed application.
  Future<void> updateInstalledApp(
    String owner,
    String name, {
    String? version,
    String? assetUrl,
    String? assetName,
    String? installMethod,
  }) async {
    final fullName = '$owner/$name';
    final existing = await (select(_database.installations)
          ..where((t) =>
              t.repoFullName.equals(fullName) & t.uninstalledAt.isNull()))
        .getSingleOrNull();

    if (existing != null) {
      final companion = InstallationsCompanion(
        updatedAt: Value(DateTime.now()),
      );
      if (version != null) {
        companion.installedVersion = Value(version);
      }
      if (assetUrl != null) {
        companion.installerPath = Value(assetUrl);
      }
      if (assetName != null) {
        companion.assetName = Value(assetName);
      }
      if (installMethod != null) {
        companion.installMethod = Value(installMethod);
      }
      await (update(_database.installations)
            ..where((t) => t.id.equals(existing.id)))
          .write(companion);
    }
  }

  // ── Update Checking ─────────────────────────────────────────────────────

  /// Check all installed applications for available updates.
  ///
  /// For each installed app, fetches the latest release from GitHub and
  /// compares the tag with the installed version. Returns a list of apps
  /// with their latest version info updated.
  Future<List<InstalledAppModel>> checkForUpdates([
    List<InstalledAppModel>? apps,
  ]) async {
    final installedApps = apps ?? await getInstalledApps();
    final updatedApps = <InstalledAppModel>[];

    for (final app in installedApps) {
      try {
        final releases = await _storeApi.getReleases(app.owner, app.name);
        if (releases.isEmpty) {
          updatedApps.add(app.copyWith(latestVersion: app.installedVersion));
          continue;
        }

        // Prefer non-prerelease, non-draft releases
        final latest = releases.firstWhere(
          (r) => !r.isPrerelease && !r.isDraft,
          orElse: () => releases.first,
        );

        final updatedApp = app.copyWith(
          latestVersion: latest.tagName,
          lastUpdateCheck: DateTime.now(),
        );
        updatedApps.add(updatedApp);
      } catch (e) {
        debugPrint('[AppsRepository] Failed to check updates for '
            '${app.effectiveFullName}: $e');
        updatedApps.add(app);
      }
    }

    return updatedApps;
  }

  // ── Export / Import ─────────────────────────────────────────────────────

  /// Export all installed applications as a JSON string (format version 4).
  Future<String> exportApps() async {
    final apps = await getInstalledApps();
    final data = {
      'version': 4,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app_count': apps.length,
      'apps': apps.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import installed applications from a JSON string.
  ///
  /// Returns the number of apps successfully imported.
  /// Supports import format version 4.
  /// Duplicates (same owner/name) are skipped automatically.
  Future<int> importApps(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = data['version'] as int? ?? 0;

      if (version < 4) {
        throw const FormatException(
          'Unsupported import format version. '
          'Only version 4 is supported.',
        );
      }

      final appsJson = data['apps'] as List<dynamic>? ?? [];
      int imported = 0;

      for (final appJson in appsJson) {
        try {
          final app = InstalledAppModel.fromJson(
            appJson as Map<String, dynamic>,
          );

          // Skip if already tracked
          final alreadyTracked = await isAppTracked(app.owner, app.name);
          if (alreadyTracked) {
            debugPrint(
              '[AppsRepository] Skipping duplicate: ${app.effectiveFullName}',
            );
            continue;
          }

          await addInstalledApp(app);
          imported++;
        } catch (e) {
          debugPrint('[AppsRepository] Failed to import app: $e');
        }
      }

      return imported;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse import data: $e');
    }
  }
}
