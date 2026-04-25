import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import 'settings_provider.dart';

/// Provider for the current theme mode (light, dark, system).
///
/// This provider is kept for backward compatibility with [GitHubStoreApp]
/// and other widgets that reference it directly. When settings are loaded
/// from the database, this provider is updated accordingly.
///
/// **Note:** New code should prefer using [settingsProvider] or
/// [effectiveThemeModeProvider] from [settings_provider.dart] instead.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Attempt to read the persisted settings synchronously.
  // On first build the settings may not be loaded yet, so we
  // fall back to system. The settings notifier will push the real
  // value once it finishes loading from the database.
  return ThemeMode.system;
});

/// Provider for the selected color scheme index.
///
/// Maps to [ColorSchemeType] values in [AppTheme]. Kept for backward
/// compatibility with [GitHubStoreApp].
///
/// **Note:** New code should prefer [colorSchemeIndexProvider] from
/// [settings_provider.dart].
final colorSchemeProvider = StateProvider<int>((ref) {
  return 0; // GitHub (default)
});

/// Provider for whether compact mode is enabled.
final compactModeProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for whether animations are enabled.
final animationsEnabledProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for the preferred download location.
final downloadLocationProvider = StateProvider<String>((ref) {
  return '';
});

/// Provider for whether download hash verification is enabled.
final verifyDownloadsProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for whether auto-install after download is enabled.
final autoInstallProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for whether private browsing mode is enabled.
final privateBrowsingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for whether usage analytics is enabled.
final analyticsEnabledProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for the current grid view mode in apps screen.
final gridViewModeProvider = StateProvider<bool>((ref) {
  return true;
});

/// Provider for the GitHub auth token.
final authTokenProvider = StateProvider<String?>((ref) {
  return null;
});

/// Derived provider: is the user authenticated?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authTokenProvider) != null;
});
