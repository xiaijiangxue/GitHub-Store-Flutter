import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/proxy_config_model.dart';
import '../../../core/models/settings_model.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/settings_repository.dart';

// Re-export shared infrastructure providers
export '../../home/presentation/providers/home_provider.dart'
    show databaseProvider;

// ── Infrastructure ──────────────────────────────────────────────────────────

/// Provider for the [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepository(database: db);
});

// ── Settings State ──────────────────────────────────────────────────────────

/// Notifier that loads and persists [SettingsModel].
class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier(this._repo) : super(SettingsModel.defaults()) {
    _loadSettings();
  }

  final SettingsRepository _repo;

  /// Load persisted settings on initialisation.
  Future<void> _loadSettings() async {
    try {
      final settings = await _repo.getSettings();
      state = settings;
    } catch (e) {
      debugPrint('[SettingsNotifier] Failed to load settings: $e');
    }
  }

  /// Reload settings from the database (useful after external changes).
  Future<void> reload() async {
    final settings = await _repo.getSettings();
    state = settings;
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _repo.updateThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setColorScheme(ColorSchemeName scheme) async {
    await _repo.updateColorScheme(scheme);
    state = state.copyWith(colorSchemeName: scheme);
  }

  Future<void> setAmoled(bool enabled) async {
    await _repo.updateAmoLed(enabled);
    state = state.copyWith(amoledEnabled: enabled);
  }

  // ── Language ──────────────────────────────────────────────────────────────

  Future<void> setLanguage(String code) async {
    await _repo.updateLanguage(code);
    state = state.copyWith(languageCode: code);
  }

  // ── Clipboard / Seen ──────────────────────────────────────────────────────

  Future<void> setClipboardDetection(bool enabled) async {
    await _repo.updateClipboardDetection(enabled);
    state = state.copyWith(clipboardDetectionEnabled: enabled);
  }

  Future<void> setHideSeen(bool enabled) async {
    await _repo.updateHideSeen(enabled);
    state = state.copyWith(hideSeenEnabled: enabled);
  }

  // ── Translation ───────────────────────────────────────────────────────────

  Future<void> setTranslationProvider(TranslationProvider provider) async {
    await _repo.updateTranslationProvider(provider);
    state = state.copyWith(translationProvider: provider);
  }

  Future<void> setYoudaoCredentials(String appKey, String appSecret) async {
    await _repo.updateYoudaoCredentials(appKey, appSecret);
    state = state.copyWith(
      youdaoAppKey: appKey.isEmpty ? null : appKey,
      youdaoAppSecret: appSecret.isEmpty ? null : appSecret,
    );
  }

  // ── Updates ───────────────────────────────────────────────────────────────

  Future<void> setUpdateCheckInterval(UpdateCheckInterval interval) async {
    await _repo.updateUpdateCheckInterval(interval);
    state = state.copyWith(updateCheckInterval: interval);
  }

  Future<void> setIncludePrerelease(bool enabled) async {
    await _repo.updateIncludePrerelease(enabled);
    state = state.copyWith(includePrerelease: enabled);
  }

  // ── Proxy ────────────────────────────────────────────────────────────────

  Future<void> setProxyConfig(
    ProxyScope scope,
    ProxyConfigModel config,
  ) async {
    await _repo.updateProxyConfig(scope, config);
    final existingConfigs = List<ProxyConfigModel>.from(state.proxyConfigs);
    final idx = existingConfigs.indexWhere((c) => c.scope == scope);
    if (idx >= 0) {
      existingConfigs[idx] = config;
    } else {
      existingConfigs.add(config);
    }
    state = state.copyWith(proxyConfigs: existingConfigs);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<void> setAnalytics(bool enabled) async {
    await _repo.updateAnalytics(enabled);
    state = state.copyWith(analyticsEnabled: enabled);
  }

  // ── Compact Mode ──────────────────────────────────────────────────────────

  Future<void> setCompactMode(bool enabled) async {
    await _repo.updateCompactMode(enabled);
    state = state.copyWith(compactMode: enabled);
  }

  // ── Animations ────────────────────────────────────────────────────────────

  Future<void> setAnimations(bool enabled) async {
    await _repo.updateAnimations(enabled);
    state = state.copyWith(animationsEnabled: enabled);
  }

  // ── Grid View ─────────────────────────────────────────────────────────────

  Future<void> setGridViewMode(bool enabled) async {
    await _repo.updateGridViewMode(enabled);
    state = state.copyWith(gridViewMode: enabled);
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _repo.clearAllSettings();
    state = SettingsModel.defaults();
  }
}

/// Provider that exposes the current [SettingsModel] and mutation methods.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

// ── Derived / Convenience Providers ─────────────────────────────────────────

/// The current [ThemeMode] derived from settings.
///
/// This bridges between the [SettingsModel] enum and Flutter's [ThemeMode].
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return switch (settings.themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
});

/// Whether AMOLED mode should be active (dark + amoled setting enabled).
final isAmoledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.themeMode == AppThemeMode.dark && settings.amoledEnabled;
});

/// The index of the selected color scheme for use with [AppTheme].
final colorSchemeIndexProvider = Provider<int>((ref) {
  final settings = ref.watch(settingsProvider);
  return ColorSchemeName.values.indexOf(settings.colorSchemeName);
});

/// Map of [ProxyScope] → [ProxyConfigModel] from the current settings.
final proxyConfigsProvider = Provider<Map<ProxyScope, ProxyConfigModel>>((ref) {
  final settings = ref.watch(settingsProvider);
  final map = <ProxyScope, ProxyConfigModel>{};
  for (final config in settings.proxyConfigs) {
    map[config.scope] = config;
  }
  return map;
});

/// Get proxy config for a specific scope.
final proxyForScopeProvider =
    Provider.family<ProxyConfigModel?, ProxyScope>((ref, scope) {
  final configs = ref.watch(proxyConfigsProvider);
  final config = configs[scope];
  if (config != null && config.type != ProxyType.none) {
    return config;
  }
  return null;
});

/// Computed provider: whether the current language uses RTL.
final isRtlProvider = Provider<bool>((ref) {
  final lang = ref.watch(settingsProvider).languageCode;
  const rtlLangs = ['ar', 'he', 'fa', 'ur'];
  return rtlLangs.any((l) => lang.startsWith(l));
});
