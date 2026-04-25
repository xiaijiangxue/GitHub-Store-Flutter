import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/proxy_config_model.dart';
import '../../../core/models/settings_model.dart';

/// Repository for persisting and retrieving app settings.
///
/// Uses the Drift [AppSettings] table in [AppDatabase] for persistence.
/// All settings are stored as key-value pairs where the value is a JSON string.
class SettingsRepository {
  SettingsRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // ── Keys ──────────────────────────────────────────────────────────────────

  static const _keySettings = 'app_settings_v1';
  static const _keyProxyDiscovery = 'proxy_discovery';
  static const _keyProxyDownload = 'proxy_download';
  static const _keyProxyTranslation = 'proxy_translation';

  // ── Load / Save ───────────────────────────────────────────────────────────

  /// Load the full [SettingsModel] from the database.
  ///
  /// Returns the saved settings or default values if nothing is stored.
  Future<SettingsModel> getSettings() async {
    try {
      final raw = await _db.getSetting(_keySettings);
      if (raw != null) {
        return SettingsModel.fromJsonString(raw);
      }
    } catch (e) {
      debugPrint('[SettingsRepository] Failed to load settings: $e');
    }
    return SettingsModel.defaults();
  }

  /// Persist the full [SettingsModel] to the database.
  Future<void> _saveSettings(SettingsModel settings) async {
    await _db.setSetting(_keySettings, settings.toJsonString());
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  /// Update the app theme mode (light / dark / system).
  Future<void> updateThemeMode(AppThemeMode mode) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(themeMode: mode));
  }

  /// Update the color scheme.
  Future<void> updateColorScheme(ColorSchemeName scheme) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(colorSchemeName: scheme));
  }

  /// Toggle AMOLED black mode (only effective in dark mode).
  Future<void> updateAmoLed(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(amoledEnabled: enabled));
  }

  // ── Language ──────────────────────────────────────────────────────────────

  /// Update the app language code (e.g. "en", "zh-CN").
  Future<void> updateLanguage(String languageCode) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(languageCode: languageCode));
  }

  // ── Clipboard / Seen ──────────────────────────────────────────────────────

  /// Toggle automatic clipboard link detection.
  Future<void> updateClipboardDetection(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(
      settings.copyWith(clipboardDetectionEnabled: enabled),
    );
  }

  /// Toggle hiding already-seen repositories.
  Future<void> updateHideSeen(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(hideSeenEnabled: enabled));
  }

  // ── Translation ───────────────────────────────────────────────────────────

  /// Update the translation provider.
  Future<void> updateTranslationProvider(TranslationProvider provider) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(translationProvider: provider));
  }

  /// Update Youdao API credentials.
  Future<void> updateYoudaoCredentials(
    String appKey,
    String appSecret,
  ) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(
      youdaoAppKey: appKey.isEmpty ? null : appKey,
      youdaoAppSecret: appSecret.isEmpty ? null : appSecret,
    ));
  }

  // ── Updates ───────────────────────────────────────────────────────────────

  /// Update the update check interval.
  Future<void> updateUpdateCheckInterval(
    UpdateCheckInterval interval,
  ) async {
    final settings = await getSettings();
    await _saveSettings(
      settings.copyWith(updateCheckInterval: interval),
    );
  }

  /// Toggle including pre-release versions.
  Future<void> updateIncludePrerelease(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(includePrerelease: enabled));
  }

  // ── Proxy ────────────────────────────────────────────────────────────────

  /// Update the proxy configuration for a given scope.
  Future<void> updateProxyConfig(
    ProxyScope scope,
    ProxyConfigModel config,
  ) async {
    // Store per-scope proxy config individually
    final key = switch (scope) {
      ProxyScope.discovery => _keyProxyDiscovery,
      ProxyScope.download => _keyProxyDownload,
      ProxyScope.translation => _keyProxyTranslation,
    };
    await _db.setSetting(key, config.toJsonString());

    // Also update the full settings model
    final settings = await getSettings();
    final existingConfigs = List<ProxyConfigModel>.from(settings.proxyConfigs);
    final idx = existingConfigs.indexWhere((c) => c.scope == scope);
    if (idx >= 0) {
      existingConfigs[idx] = config;
    } else {
      existingConfigs.add(config);
    }
    await _saveSettings(settings.copyWith(proxyConfigs: existingConfigs));
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  /// Toggle usage analytics / telemetry.
  Future<void> updateAnalytics(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(analyticsEnabled: enabled));
  }

  // ── Compact Mode ──────────────────────────────────────────────────────────

  /// Toggle compact display mode.
  Future<void> updateCompactMode(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(compactMode: enabled));
  }

  // ── Animations ────────────────────────────────────────────────────────────

  /// Toggle UI animations.
  Future<void> updateAnimations(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(animationsEnabled: enabled));
  }

  // ── Grid View ─────────────────────────────────────────────────────────────

  /// Toggle grid / list view mode in apps screen.
  Future<void> updateGridViewMode(bool enabled) async {
    final settings = await getSettings();
    await _saveSettings(settings.copyWith(gridViewMode: enabled));
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  /// Remove all persisted settings, reverting to defaults.
  Future<void> clearAllSettings() async {
    try {
      await _db.setSetting(_keySettings, SettingsModel.defaults().toJsonString());
    } catch (e) {
      debugPrint('[SettingsRepository] Failed to clear settings: $e');
    }
  }
}
