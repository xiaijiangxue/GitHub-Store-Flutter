import 'dart:convert';

import 'proxy_config_model.dart';

/// App theme mode options.
enum AppThemeMode {
  light,
  dark,
  system;

  static AppThemeMode fromString(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }

  String get displayName => switch (this) {
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
        AppThemeMode.system => 'System',
      };
}

/// Named color scheme options.
enum ColorSchemeName {
  github,
  ocean,
  forest,
  sunset,
  lavender,
  rose;

  static ColorSchemeName fromString(String value) {
    return ColorSchemeName.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ColorSchemeName.github,
    );
  }

  String get displayName => switch (this) {
        ColorSchemeName.github => 'GitHub',
        ColorSchemeName.ocean => 'Ocean',
        ColorSchemeName.forest => 'Forest',
        ColorSchemeName.sunset => 'Sunset',
        ColorSchemeName.lavender => 'Lavender',
        ColorSchemeName.rose => 'Rose',
      };
}

/// Translation provider options.
enum TranslationProvider {
  google,
  youdao;

  static TranslationProvider fromString(String value) {
    return TranslationProvider.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => TranslationProvider.google,
    );
  }

  String get displayName => switch (this) {
        TranslationProvider.google => 'Google Translate',
        TranslationProvider.youdao => 'Youdao',
      };
}

/// Update check interval options.
enum UpdateCheckInterval {
  threeHours(Duration(hours: 3), '3h'),
  sixHours(Duration(hours: 6), '6h'),
  twelveHours(Duration(hours: 12), '12h'),
  twentyFourHours(Duration(hours: 24), '24h');

  const UpdateCheckInterval(this.duration, this.label);
  final Duration duration;
  final String label;

  static UpdateCheckInterval fromString(String value) {
    return UpdateCheckInterval.values.firstWhere(
      (e) => e.name == value ||
          e.label == value ||
          e.duration.inHours.toString() + 'h' == value,
      orElse: () => UpdateCheckInterval.twelveHours,
    );
  }
}

/// Comprehensive app settings model.
class SettingsModel {
  SettingsModel({
    this.themeMode = AppThemeMode.system,
    this.colorSchemeName = ColorSchemeName.github,
    this.amoledEnabled = false,
    this.languageCode = 'en',
    this.clipboardDetectionEnabled = false,
    this.hideSeenEnabled = false,
    this.translationProvider = TranslationProvider.google,
    this.youdaoAppKey,
    this.youdaoAppSecret,
    this.updateCheckInterval = UpdateCheckInterval.twelveHours,
    this.includePrerelease = false,
    this.proxyConfigs = const [],
    this.downloadLocation,
    this.verifyDownloads = true,
    this.autoInstallAfterDownload = false,
    this.compactMode = false,
    this.animationsEnabled = true,
    this.analyticsEnabled = true,
    this.gridViewMode = true,
  });

  /// App theme mode.
  final AppThemeMode themeMode;

  /// Selected color scheme.
  final ColorSchemeName colorSchemeName;

  /// Whether AMOLED black theme is enabled in dark mode.
  final bool amoledEnabled;

  /// App language code (e.g. "en", "zh-CN", "ja").
  final String languageCode;

  /// Whether automatic clipboard link detection is enabled.
  final bool clipboardDetectionEnabled;

  /// Whether already-seen repos are hidden from feeds.
  final bool hideSeenEnabled;

  /// Translation API provider.
  final TranslationProvider translationProvider;

  /// Youdao API app key (required if translationProvider == youdao).
  final String? youdaoAppKey;

  /// Youdao API app secret.
  final String? youdaoAppSecret;

  /// How often to check for app updates.
  final UpdateCheckInterval updateCheckInterval;

  /// Whether to include pre-release versions when checking for updates.
  final bool includePrerelease;

  /// Proxy configurations for different scopes.
  final List<ProxyConfigModel> proxyConfigs;

  /// Custom download location (null = default).
  final String? downloadLocation;

  /// Whether to verify SHA-256 hashes on downloads.
  final bool verifyDownloads;

  /// Whether to auto-install after download completes.
  final bool autoInstallAfterDownload;

  /// Whether compact list mode is enabled.
  final bool compactMode;

  /// Whether animations are enabled.
  final bool animationsEnabled;

  /// Whether usage analytics is enabled.
  final bool analyticsEnabled;

  /// Whether the apps screen shows grid or list view.
  final bool gridViewMode;

  /// Get proxy config for a specific scope, or null if none configured.
  ProxyConfigModel? getProxyForScope(ProxyScope scope) {
    for (final config in proxyConfigs) {
      if (config.scope == scope && config.type != ProxyType.none) {
        return config;
      }
    }
    return null;
  }

  SettingsModel copyWith({
    AppThemeMode? themeMode,
    ColorSchemeName? colorSchemeName,
    bool? amoledEnabled,
    String? languageCode,
    bool? clipboardDetectionEnabled,
    bool? hideSeenEnabled,
    TranslationProvider? translationProvider,
    String? youdaoAppKey,
    String? youdaoAppSecret,
    UpdateCheckInterval? updateCheckInterval,
    bool? includePrerelease,
    List<ProxyConfigModel>? proxyConfigs,
    String? downloadLocation,
    bool? verifyDownloads,
    bool? autoInstallAfterDownload,
    bool? compactMode,
    bool? animationsEnabled,
    bool? analyticsEnabled,
    bool? gridViewMode,
  }) {
    return SettingsModel(
      themeMode: themeMode ?? this.themeMode,
      colorSchemeName: colorSchemeName ?? this.colorSchemeName,
      amoledEnabled: amoledEnabled ?? this.amoledEnabled,
      languageCode: languageCode ?? this.languageCode,
      clipboardDetectionEnabled:
          clipboardDetectionEnabled ?? this.clipboardDetectionEnabled,
      hideSeenEnabled: hideSeenEnabled ?? this.hideSeenEnabled,
      translationProvider:
          translationProvider ?? this.translationProvider,
      youdaoAppKey: youdaoAppKey ?? this.youdaoAppKey,
      youdaoAppSecret: youdaoAppSecret ?? this.youdaoAppSecret,
      updateCheckInterval:
          updateCheckInterval ?? this.updateCheckInterval,
      includePrerelease: includePrerelease ?? this.includePrerelease,
      proxyConfigs: proxyConfigs ?? this.proxyConfigs,
      downloadLocation: downloadLocation ?? this.downloadLocation,
      verifyDownloads: verifyDownloads ?? this.verifyDownloads,
      autoInstallAfterDownload:
          autoInstallAfterDownload ?? this.autoInstallAfterDownload,
      compactMode: compactMode ?? this.compactMode,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      gridViewMode: gridViewMode ?? this.gridViewMode,
    );
  }

  /// Create default settings.
  factory SettingsModel.defaults() {
    return SettingsModel();
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      themeMode:
          AppThemeMode.fromString(json['theme_mode'] as String? ?? 'system'),
      colorSchemeName: ColorSchemeName.fromString(
          json['color_scheme_name'] as String? ?? 'github'),
      amoledEnabled: json['amoled_enabled'] as bool? ?? false,
      languageCode: json['language_code'] as String? ?? 'en',
      clipboardDetectionEnabled:
          json['clipboard_detection_enabled'] as bool? ?? false,
      hideSeenEnabled: json['hide_seen_enabled'] as bool? ?? false,
      translationProvider: TranslationProvider.fromString(
          json['translation_provider'] as String? ?? 'google'),
      youdaoAppKey: json['youdao_app_key'] as String?,
      youdaoAppSecret: json['youdao_app_secret'] as String?,
      updateCheckInterval: UpdateCheckInterval.fromString(
          json['update_check_interval'] as String? ?? '12h'),
      includePrerelease: json['include_prerelease'] as bool? ?? false,
      proxyConfigs: (json['proxy_configs'] as List<dynamic>?)
              ?.map((e) =>
                  ProxyConfigModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      downloadLocation: json['download_location'] as String?,
      verifyDownloads: json['verify_downloads'] as bool? ?? true,
      autoInstallAfterDownload:
          json['auto_install_after_download'] as bool? ?? false,
      compactMode: json['compact_mode'] as bool? ?? false,
      animationsEnabled: json['animations_enabled'] as bool? ?? true,
      analyticsEnabled: json['analytics_enabled'] as bool? ?? true,
      gridViewMode: json['grid_view_mode'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme_mode': themeMode.name,
      'color_scheme_name': colorSchemeName.name,
      'amoled_enabled': amoledEnabled,
      'language_code': languageCode,
      'clipboard_detection_enabled': clipboardDetectionEnabled,
      'hide_seen_enabled': hideSeenEnabled,
      'translation_provider': translationProvider.name,
      if (youdaoAppKey != null) 'youdao_app_key': youdaoAppKey,
      if (youdaoAppSecret != null) 'youdao_app_secret': youdaoAppSecret,
      'update_check_interval': updateCheckInterval.label,
      'include_prerelease': includePrerelease,
      'proxy_configs': proxyConfigs.map((c) => c.toJson()).toList(),
      if (downloadLocation != null) 'download_location': downloadLocation,
      'verify_downloads': verifyDownloads,
      'auto_install_after_download': autoInstallAfterDownload,
      'compact_mode': compactMode,
      'animations_enabled': animationsEnabled,
      'analytics_enabled': analyticsEnabled,
      'grid_view_mode': gridViewMode,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory SettingsModel.fromJsonString(String source) =>
      SettingsModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModel &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          colorSchemeName == other.colorSchemeName &&
          amoledEnabled == other.amoledEnabled &&
          languageCode == other.languageCode &&
          includePrerelease == other.includePrerelease;

  @override
  int get hashCode => Object.hash(
        themeMode,
        colorSchemeName,
        amoledEnabled,
        languageCode,
        includePrerelease,
      );

  @override
  String toString() =>
      'SettingsModel(theme: ${themeMode.displayName}, '
      'colorScheme: ${colorSchemeName.displayName}, '
      'language: $languageCode)';
}
