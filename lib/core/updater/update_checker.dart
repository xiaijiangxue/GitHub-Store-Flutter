import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_model.dart' show UpdateCheckInterval;

/// Information about an available app update.
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.releaseUrl,
    this.changelog,
    this.downloadUrl,
    this.publishedAt,
    this.isPrerelease = false,
  });

  /// The new version string (e.g. "2.0.0").
  final String version;

  /// URL to the GitHub release page.
  final String releaseUrl;

  /// Release changelog / release notes markdown.
  final String? changelog;

  /// Direct download URL for the latest release asset.
  final String? downloadUrl;

  /// When the release was published.
  final DateTime? publishedAt;

  /// Whether this is a pre-release version.
  final bool isPrerelease;

  @override
  String toString() => 'UpdateInfo(version: $version, publishedAt: $publishedAt, '
      'prerelease: $isPrerelease)';

  Map<String, dynamic> toJson() => {
        'version': version,
        'release_url': releaseUrl,
        if (changelog != null) 'changelog': changelog,
        if (downloadUrl != null) 'download_url': downloadUrl,
        if (publishedAt != null)
          'published_at': publishedAt!.toIso8601String(),
        'is_prerelease': isPrerelease,
      };
}

/// Result of comparing two version strings.
enum _VersionComparison {
  /// Current version is older than the compared version (update available).
  newer,

  /// Versions are equal.
  equal,

  /// Current version is newer than the compared version.
  older,
}

/// Service that checks the GitHub Store releases API for new versions.
///
/// Compares the current app version with the latest release tag on GitHub.
/// Supports configurable check intervals and respects the user's preference
/// for pre-release versions.
///
/// Usage:
/// ```dart
/// final updateChecker = UpdateChecker();
/// final update = await updateChecker.checkForUpdate();
/// if (update != null) {
///   print('Update available: ${update.version}');
/// }
/// ```
class UpdateChecker {
  UpdateChecker({
    Dio? httpClient,
    SharedPreferences? prefs,
    UpdateCheckInterval checkInterval = UpdateCheckInterval.twelveHours,
    bool includePrerelease = false,
  })  : _dio = httpClient ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'GitHubStore-Desktop/1.0',
              },
            )),
        _prefs = prefs,
        _checkInterval = checkInterval,
        _includePrerelease = includePrerelease;

  final Dio _dio;
  final SharedPreferences? _prefs;

  UpdateCheckInterval _checkInterval;
  bool _includePrerelease;

  /// SharedPreferences key for last check timestamp.
  static const String _lastCheckKey = 'update_checker_last_check';

  /// SharedPreferences key for cached update info.
  static const String _cachedUpdateKey = 'update_checker_cached_update';

  /// SharedPreferences key for dismissed version.
  static const String _dismissedVersionKey = 'update_checker_dismissed_version';

  /// GitHub owner/repo for the GitHub Store app releases.
  static const String _repoOwner = 'github-store';
  static const String _repoName = 'github-store-flutter';

  /// Current app version.
  String? _currentVersion;

  /// The last known update info.
  UpdateInfo? _cachedUpdate;

  /// Whether a check is currently in progress.
  bool _isChecking = false;

  // ── Configuration ───────────────────────────────────────────────────────

  /// Set the update check interval.
  void setCheckInterval(UpdateCheckInterval interval) {
    _checkInterval = interval;
  }

  /// Set whether to include pre-release versions.
  void setIncludePrerelease(bool include) {
    _includePrerelease = include;
  }

  /// Get the current app version.
  ///
  /// Extracts from the package or defaults to the build-time constant.
  String getCurrentVersion() {
    _currentVersion ??= const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0',
    );
    // Strip build number (e.g. "1.0.0+1" -> "1.0.0")
    return _currentVersion!.split('+').first;
  }

  /// Whether an update check is currently in progress.
  bool get isChecking => _isChecking;

  /// Get the last cached update info without making a network request.
  UpdateInfo? get cachedUpdate => _cachedUpdate;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Check for a new version of the app.
  ///
  /// Returns [UpdateInfo] if a new version is available, or `null` if the app
  /// is up to date or the check failed.
  ///
  /// Respects the configured check interval and will not make a network
  /// request if the last check was within the interval (unless [force] is true).
  ///
  /// [force] - Skip the interval check and always make a network request.
  /// [includePrerelease] - Override the configured prerelease setting.
  Future<UpdateInfo?> checkForUpdate({
    bool force = false,
    bool? includePrerelease,
  }) async {
    if (_isChecking) return null;

    // Check if we should skip this check based on interval
    if (!force && _shouldSkipCheck()) {
      debugPrint('[UpdateChecker] Skipping check (within interval). '
          'Cached update: ${_cachedUpdate?.version ?? "none"}');
      return _cachedUpdate;
    }

    _isChecking = true;
    final prerelease = includePrerelease ?? _includePrerelease;

    try {
      final latestRelease = await _fetchLatestRelease(prerelease);
      if (latestRelease == null) {
        debugPrint('[UpdateChecker] No latest release found');
        return null;
      }

      final latestVersion = _extractVersionFromTag(latestRelease['tag_name']);
      if (latestVersion == null) {
        debugPrint('[UpdateChecker] Could not parse version from tag: '
            '${latestRelease['tag_name']}');
        return null;
      }

      final currentVersion = getCurrentVersion();
      final comparison = _compareVersions(currentVersion, latestVersion);

      // Update last check timestamp
      await _prefs?.setString(
          _lastCheckKey, DateTime.now().toUtc().toIso8601String());

      switch (comparison) {
        case _VersionComparison.newer:
          final update = _parseUpdateInfo(latestRelease, latestVersion);
          _cachedUpdate = update;
          await _cacheUpdateInfo(update);
          debugPrint('[UpdateChecker] Update available: $latestVersion '
              '(current: $currentVersion)');
          return update;

        case _VersionComparison.equal:
          _cachedUpdate = null;
          await _prefs?.remove(_cachedUpdateKey);
          debugPrint('[UpdateChecker] App is up to date: $currentVersion');
          return null;

        case _VersionComparison.older:
          _cachedUpdate = null;
          await _prefs?.remove(_cachedUpdateKey);
          debugPrint('[UpdateChecker] App version ($currentVersion) is newer '
              'than latest release ($latestVersion)');
          return null;
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Check failed: $e');
      // Return cached update if available
      return _cachedUpdate;
    } finally {
      _isChecking = false;
    }
  }

  /// Dismiss the current update notification.
  ///
  /// The user won't be notified about this specific version again until
  /// a newer version is released.
  Future<void> dismissUpdate() async {
    if (_cachedUpdate != null) {
      await _prefs?.setString(_dismissedVersionKey, _cachedUpdate!.version);
      _cachedUpdate = null;
    }
  }

  /// Reset the dismissed version, allowing the notification to show again.
  Future<void> resetDismissedVersion() async {
    await _prefs?.remove(_dismissedVersionKey);
  }

  /// Clear any cached update info.
  Future<void> clearCache() async {
    _cachedUpdate = null;
    await _prefs?.remove(_cachedUpdateKey);
    await _prefs?.remove(_lastCheckKey);
    await _prefs?.remove(_dismissedVersionKey);
  }

  // ── Private Methods ─────────────────────────────────────────────────────

  /// Check if enough time has passed since the last check.
  bool _shouldSkipCheck() {
    if (_prefs == null) return false;

    final lastCheckStr = _prefs!.getString(_lastCheckKey);
    if (lastCheckStr == null) return false;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return false;

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(lastCheck);
    return elapsed < _checkInterval.duration;
  }

  /// Fetch the latest release from the GitHub API.
  Future<Map<String, dynamic>?> _fetchLatestRelease(bool includePrerelease) async {
    try {
      // Try the latest release endpoint first
      if (!includePrerelease) {
        final response = await _dio.get<Map<String, dynamic>>(
          '/repos/$_repoOwner/$_repoName/releases/latest',
        );

        final release = response.data;
        if (release != null) {
          final isPre = release['prerelease'] as bool? ?? false;
          if (!isPre) return release;
        }
      }

      // Fall back to listing releases and picking the first matching one
      final response = await _dio.get<List<dynamic>>(
        '/repos/$_repoOwner/$_repoName/releases',
        queryParameters: {
          'per_page': 10,
        },
      );

      final releases = response.data;
      if (releases == null || releases.isEmpty) return null;

      for (final release in releases) {
        if (release is! Map<String, dynamic>) continue;
        final isPre = release['prerelease'] as bool? ?? false;
        if (includePrerelease || !isPre) {
          return release;
        }
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[UpdateChecker] Repository or releases not found');
      } else {
        debugPrint('[UpdateChecker] API error: ${e.message}');
      }
      return null;
    }
  }

  /// Parse release data into an [UpdateInfo] object.
  UpdateInfo _parseUpdateInfo(
      Map<String, dynamic> release, String version) {
    // Extract the first downloadable asset URL for the current platform
    String? downloadUrl;
    final assets = release['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';

        // Match platform-specific asset names
        if (Platform.isWindows && (name.endsWith('.msi') || name.endsWith('.exe'))) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        } else if (Platform.isMacOS && (name.endsWith('.dmg') || name.endsWith('.pkg'))) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        } else if (Platform.isLinux &&
            (name.endsWith('.deb') ||
                name.endsWith('.rpm') ||
                name.endsWith('.AppImage') ||
                name.endsWith('.snap'))) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      // If no platform-specific match, use the first asset
      downloadUrl ??= (assets.firstOrNull as Map<String, dynamic>?)?['browser_download_url'] as String?;
    }

    DateTime? publishedAt;
    final publishedStr = release['published_at'] as String?;
    if (publishedStr != null) {
      publishedAt = DateTime.tryParse(publishedStr);
    }

    return UpdateInfo(
      version: version,
      releaseUrl: release['html_url'] as String? ??
          'https://github.com/$_repoOwner/$_repoName/releases',
      changelog: release['body'] as String?,
      downloadUrl: downloadUrl,
      publishedAt: publishedAt,
      isPrerelease: release['prerelease'] as bool? ?? false,
    );
  }

  /// Extract a clean version string from a git tag.
  ///
  /// Handles: "v1.2.3", "1.2.3", "release-1.2.3", etc.
  String? _extractVersionFromTag(String? tag) {
    if (tag == null || tag.isEmpty) return null;

    String cleaned = tag.trim();
    // Remove leading 'v' or 'V'
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    // Remove "release-" prefix
    if (cleaned.startsWith('release-')) {
      cleaned = cleaned.substring('release-'.length);
    }

    // Validate it looks like a version (x.y.z or x.y)
    final regex = RegExp(r'^(\d+\.){1,3}\d+(-[\w.]+)?$');
    if (regex.hasMatch(cleaned)) {
      // Strip pre-release suffix for comparison
      return cleaned.split('-').first;
    }

    return null;
  }

  /// Compare two semantic version strings.
  ///
  /// Returns [_VersionComparison.newer] if [current] is older than [other],
  /// [_VersionComparison.equal] if they are the same, or
  /// [_VersionComparison.older] if [current] is newer.
  _VersionComparison _compareVersions(String current, String other) {
    final currentParts = _parseVersionParts(current);
    final otherParts = _parseVersionParts(other);

    for (var i = 0; i < 3; i++) {
      final c = currentParts.length > i ? currentParts[i] : 0;
      final o = otherParts.length > i ? otherParts[i] : 0;

      if (c < o) return _VersionComparison.newer;
      if (c > o) return _VersionComparison.older;
    }

    return _VersionComparison.equal;
  }

  /// Parse a version string into a list of integer parts.
  List<int> _parseVersionParts(String version) {
    return version
        .split('.')
        .take(3)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  /// Cache update info to SharedPreferences.
  Future<void> _cacheUpdateInfo(UpdateInfo update) async {
    if (_prefs == null) return;
    try {
      // Simple JSON cache
      final json = update.toJson();
      // Don't cache the full changelog (can be large)
      json.remove('changelog');
      await _prefs!.setString(_cachedUpdateKey, update.changelog ?? '');
      await _prefs!.setString(
        '${_cachedUpdateKey}_info',
        '${update.version}|${update.releaseUrl}|${update.downloadUrl ?? ""}|'
        '${update.publishedAt?.toIso8601String() ?? ""}|${update.isPrerelease}',
      );
    } catch (e) {
      debugPrint('[UpdateChecker] Failed to cache update info: $e');
    }
  }

  /// Load cached update info from SharedPreferences.
  Future<void> _loadCachedUpdate() async {
    if (_prefs == null) return;
    try {
      final infoStr = _prefs!.getString('${_cachedUpdateKey}_info');
      final changelog = _prefs!.getString(_cachedUpdateKey);

      if (infoStr == null || infoStr.isEmpty) return;

      final parts = infoStr.split('|');
      if (parts.length < 5) return;

      _cachedUpdate = UpdateInfo(
        version: parts[0],
        releaseUrl: parts[1],
        changelog: changelog,
        downloadUrl: parts[2].isEmpty ? null : parts[2],
        publishedAt: parts[3].isEmpty ? null : DateTime.tryParse(parts[3]),
        isPrerelease: parts[4] == 'true',
      );
    } catch (e) {
      debugPrint('[UpdateChecker] Failed to load cached update: $e');
    }
  }
}
