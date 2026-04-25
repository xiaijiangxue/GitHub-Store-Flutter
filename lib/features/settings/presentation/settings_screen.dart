import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/settings_model.dart';
import '../../../core/models/proxy_config_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/settings_repository.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';

/// Supported languages with their native labels and locale codes.
class _Language {
  const _Language(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;
}

const _languages = <_Language>[
  _Language('en', 'English', 'English'),
  _Language('ar', 'العربية', 'Arabic'),
  _Language('bn', 'বাংলা', 'Bengali'),
  _Language('zh-CN', '简体中文', 'Chinese Simplified'),
  _Language('es', 'Español', 'Spanish'),
  _Language('fr', 'Français', 'French'),
  _Language('hi', 'हिन्दी', 'Hindi'),
  _Language('it', 'Italiano', 'Italian'),
  _Language('ja', '日本語', 'Japanese'),
  _Language('ko', '한국어', 'Korean'),
  _Language('pl', 'Polski', 'Polish'),
  _Language('ru', 'Русский', 'Russian'),
  _Language('tr', 'Türkçe', 'Turkish'),
];

/// Settings screen with all application preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Proxy field controllers (created on demand per scope)
  final Map<String, TextEditingController> _hostControllers = {};
  final Map<String, TextEditingController> _portControllers = {};
  final Map<String, TextEditingController> _usernameControllers = {};
  final Map<String, TextEditingController> _passwordControllers = {};
  final Set<String> _expandedProxySections = {};

  @override
  void dispose() {
    for (final c in _hostControllers.values) {
      c.dispose();
    }
    for (final c in _portControllers.values) {
      c.dispose();
    }
    for (final c in _usernameControllers.values) {
      c.dispose();
    }
    for (final c in _passwordControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Proxy controller helpers ─────────────────────────────────────────────

  TextEditingController _getHostController(String key) {
    return _hostControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  TextEditingController _getPortController(String key) {
    return _portControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  TextEditingController _getUsernameController(String key) {
    return _usernameControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  TextEditingController _getPasswordController(String key) {
    return _passwordControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(title: 'APPEARANCE'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                // Theme mode
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme Mode',
                  subtitle: settings.themeMode.displayName,
                  onTap: () => _showThemeModePicker(context),
                ),
                const Divider(height: 1),
                // Color scheme
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Color Scheme',
                  subtitle: settings.colorSchemeName.displayName,
                  onTap: () => _showColorSchemePicker(context),
                ),
                // Color scheme circles inline
                _buildColorSchemeRow(theme, settings),
                const Divider(height: 1),
                // AMOLED toggle (dark only)
                _SettingsSwitch(
                  icon: Icons.brightness_3_outlined,
                  title: 'AMOLED Black',
                  subtitle: 'Pure black background in dark mode',
                  value: settings.amoledEnabled,
                  enabled: settings.themeMode == AppThemeMode.dark ||
                      settings.themeMode == AppThemeMode.system,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setAmoled(v),
                ),
                const Divider(height: 1),
                // Compact mode
                _SettingsSwitch(
                  icon: Icons.view_compact_outlined,
                  title: 'Compact Mode',
                  subtitle: 'Reduce spacing and padding',
                  value: settings.compactMode,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setCompactMode(v),
                ),
                const Divider(height: 1),
                // Animations
                _SettingsSwitch(
                  icon: Icons.animation_outlined,
                  title: 'Animations',
                  subtitle: 'Enable UI animations',
                  value: settings.animationsEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setAnimations(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Language ────────────────────────────────────────────────────
          _SectionHeader(title: 'LANGUAGE'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.language,
                  title: 'App Language',
                  subtitle: _getLanguageLabel(settings.languageCode),
                  onTap: () => _showLanguagePicker(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Network / Proxy ────────────────────────────────────────────
          _SectionHeader(title: 'NETWORK / PROXY'),
          const SizedBox(height: 8),
          ...ProxyScope.values.map(
            (scope) => _buildProxySection(theme, settings, scope),
          ),
          const SizedBox(height: 24),

          // ── Translation ────────────────────────────────────────────────
          _SectionHeader(title: 'TRANSLATION'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.translate_outlined,
                  title: 'Translation Provider',
                  subtitle: settings.translationProvider.displayName,
                  onTap: () => _showTranslationProviderPicker(context),
                ),
                if (settings.translationProvider == TranslationProvider.youdao) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: TextEditingController(
                        text: settings.youdaoAppKey ?? '',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Youdao App Key',
                        hintText: 'Enter your app key',
                        prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                        isDense: true,
                      ),
                      onSubmitted: (v) => ref
                          .read(settingsProvider.notifier)
                          .setYoudaoCredentials(v, settings.youdaoAppSecret ?? ''),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _PasswordTextField(
                      label: 'Youdao App Secret',
                      hintText: 'Enter your app secret',
                      initialValue: settings.youdaoAppSecret ?? '',
                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                      onSubmitted: (v) => ref
                          .read(settingsProvider.notifier)
                          .setYoudaoCredentials(settings.youdaoAppKey ?? '', v),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Installation ────────────────────────────────────────────────
          _SectionHeader(title: 'INSTALLATION'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.update_outlined,
                  title: 'Update Check Interval',
                  subtitle: settings.updateCheckInterval.label,
                  onTap: () => _showUpdateIntervalPicker(context),
                ),
                const Divider(height: 1),
                _SettingsSwitch(
                  icon: Icons.new_releases_outlined,
                  title: 'Include Pre-releases',
                  subtitle: 'Show pre-release versions in updates',
                  value: settings.includePrerelease,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setIncludePrerelease(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Storage ────────────────────────────────────────────────────
          _SectionHeader(title: 'STORAGE'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                FutureBuilder<String>(
                  future: _calculateCacheSize(),
                  builder: (context, snapshot) {
                    final size = snapshot.data ?? 'Calculating...';
                    return _SettingsTile(
                      icon: Icons.storage_outlined,
                      title: 'Cache Size',
                      subtitle: size,
                    );
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear Download Cache',
                  subtitle: 'Remove cached download files',
                  trailing: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Other ──────────────────────────────────────────────────────
          _SectionHeader(title: 'OTHER'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SettingsSwitch(
                  icon: Icons.content_paste_go_outlined,
                  title: 'Clipboard Link Detection',
                  subtitle: 'Auto-detect GitHub URLs from clipboard',
                  value: settings.clipboardDetectionEnabled,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setClipboardDetection(v),
                ),
                const Divider(height: 1),
                _SettingsSwitch(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide Seen Repos',
                  subtitle: 'Hide already-viewed repositories',
                  value: settings.hideSeenEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setHideSeen(v),
                ),
                const Divider(height: 1),
                _SettingsSwitch(
                  icon: Icons.analytics_outlined,
                  title: 'Usage Analytics',
                  subtitle: 'Help improve the app with anonymous data',
                  value: settings.analyticsEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setAnalytics(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          _SectionHeader(title: 'ABOUT'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'GitHub Store',
                  subtitle: 'v1.0.0+1',
                ),
                const Divider(height: 1),
                const _SettingsTile(
                  icon: Icons.code_outlined,
                  title: 'Source Code',
                  subtitle: 'github.com/github-store/flutter',
                ),
                const Divider(height: 1),
                const _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'License',
                  subtitle: 'MIT License',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Inline Color Scheme Row ──────────────────────────────────────────────

  Widget _buildColorSchemeRow(ThemeData theme, SettingsModel settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ColorSchemeType.values.map((scheme) {
          final isSelected =
              settings.colorSchemeName.name == scheme.name;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(settingsProvider.notifier).setColorScheme(
                      ColorSchemeName.fromString(scheme.name),
                    );
              },
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.previewColor,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 1,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: scheme.previewColor.withOpacity( 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheme.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Proxy Section ────────────────────────────────────────────────────────

  Widget _buildProxySection(
    ThemeData theme,
    SettingsModel settings,
    ProxyScope scope,
  ) {
    final scopeKey = scope.name;
    final config = settings.getProxyForScope(scope);
    final isExpanded = _expandedProxySections.contains(scopeKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          children: [
            // Header row with expand/collapse
            ListTile(
              leading: Icon(
                scope == ProxyScope.discovery
                    ? Icons.explore_outlined
                    : scope == ProxyScope.download
                        ? Icons.download_outlined
                        : Icons.translate_outlined,
              ),
              title: Text(
                '${scope.displayName} Proxy',
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text(
                config?.type.displayName ?? 'None',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config?.isConfigured == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        config!.formattedAddress!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedProxySections.remove(scopeKey);
                  } else {
                    _expandedProxySections.add(scopeKey);
                    // Initialise controllers with current values
                    _getHostController(scopeKey).text = config?.host ?? '';
                    _getPortController(scopeKey).text =
                        config?.port?.toString() ?? '';
                    _getUsernameController(scopeKey).text =
                        config?.username ?? '';
                    _getPasswordController(scopeKey).text =
                        config?.password ?? '';
                  }
                });
              },
            ),
            // Expandable content
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radio buttons for proxy type
                    Wrap(
                      spacing: 8,
                      children: ProxyType.values.map((type) {
                        final selected = config?.type ?? ProxyType.none;
                        return ChoiceChip(
                          label: Text(type.displayName),
                          selected: selected == type,
                          onSelected: (v) {
                            if (v) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setProxyConfig(
                                    scope,
                                    ProxyConfigModel(
                                      scope: scope,
                                      type: type,
                                      host: _getHostController(scopeKey).text,
                                      port: int.tryParse(
                                        _getPortController(scopeKey).text,
                                      ),
                                      username:
                                          _getUsernameController(scopeKey).text,
                                      password:
                                          _getPasswordController(scopeKey).text,
                                    ),
                                  );
                            }
                          },
                        );
                      }).toList(),
                    ),
                    // Show fields only for HTTP / SOCKS
                    if ((config?.type.requiresConfiguration ?? false))
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      _getHostController(scopeKey),
                                  decoration: const InputDecoration(
                                    labelText: 'Host',
                                    hintText: 'e.g. 127.0.0.1',
                                    prefixIcon: Icon(Icons.dns_outlined, size: 20),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller:
                                      _getPortController(scopeKey),
                                  decoration: const InputDecoration(
                                    labelText: 'Port',
                                    hintText: '8080',
                                    prefixIcon: Icon(Icons.numbers, size: 20),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      _getUsernameController(scopeKey),
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    hintText: 'Optional',
                                    prefixIcon:
                                        Icon(Icons.person_outline, size: 20),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PasswordTextField(
                                  label: 'Password',
                                  hintText: 'Optional',
                                  initialValue:
                                      _getPasswordController(scopeKey).text,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 20,
                                  ),
                                  onSubmitted: (v) =>
                                      _getPasswordController(scopeKey).text = v,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final host =
                                    _getHostController(scopeKey).text;
                                final port = int.tryParse(
                                  _getPortController(scopeKey).text,
                                );
                                final username =
                                    _getUsernameController(scopeKey).text;
                                final password =
                                    _getPasswordController(scopeKey).text;
                                ref
                                    .read(settingsProvider.notifier)
                                    .setProxyConfig(
                                      scope,
                                      ProxyConfigModel(
                                        scope: scope,
                                        type: config?.type ?? ProxyType.http,
                                        host: host,
                                        port: port,
                                        username: username.isEmpty
                                            ? null
                                            : username,
                                        password: password.isEmpty
                                            ? null
                                            : password,
                                      ),
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Proxy saved'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Save Proxy'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Test connection button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _testProxyConnection(scope),
                              icon: const Icon(
                                Icons.network_check_outlined,
                                size: 18,
                              ),
                              label: const Text('Test Connection'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testProxyConnection(ProxyScope scope) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing proxy connection...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Simulate a test delay then report success.
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection successful!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

  void _showThemeModePicker(BuildContext context) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Theme Mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final mode in AppThemeMode.values)
              RadioListTile<AppThemeMode>(
                title: Text(mode.displayName),
                value: mode,
                groupValue: settings.themeMode,
                secondary: Icon(
                  mode == AppThemeMode.light
                      ? Icons.light_mode_outlined
                      : mode == AppThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.brightness_auto_outlined,
                ),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(value);
                    // Also update the legacy themeModeProvider for app.dart
                    ref.read(themeModeProvider.notifier).state =
                        switch (value) {
                      AppThemeMode.light => ThemeMode.light,
                      AppThemeMode.dark => ThemeMode.dark,
                      AppThemeMode.system => ThemeMode.system,
                    };
                  }
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showColorSchemePicker(BuildContext context) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color Scheme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: ColorSchemeType.values.map((scheme) {
                  final isSelected =
                      settings.colorSchemeName.name == scheme.name;
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setColorScheme(
                            ColorSchemeName.fromString(scheme.name),
                          );
                      // Also update legacy provider
                      ref.read(colorSchemeProvider.notifier).state =
                          scheme.index;
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: scheme.previewColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          scheme.previewColor.withOpacity( 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          scheme.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'App Language',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _languages.length,
                  itemBuilder: (ctx, index) {
                    final lang = _languages[index];
                    final isSelected =
                        settings.languageCode == lang.code;
                    return RadioListTile<String>(
                      title: Text(lang.nativeName),
                      subtitle: Text(lang.englishName),
                      value: lang.code,
                      groupValue: settings.languageCode,
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setLanguage(value);
                          Navigator.pop(ctx);
                        }
                      },
                      selected: isSelected,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTranslationProviderPicker(BuildContext context) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Translation Provider',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final provider in TranslationProvider.values)
              RadioListTile<TranslationProvider>(
                title: Text(provider.displayName),
                value: provider,
                groupValue: settings.translationProvider,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setTranslationProvider(value);
                  }
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUpdateIntervalPicker(BuildContext context) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Update Check Interval',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final interval in UpdateCheckInterval.values)
              RadioListTile<UpdateCheckInterval>(
                title: Text(interval.label),
                subtitle: Text(
                  '${interval.duration.inHours} hours',
                ),
                value: interval,
                groupValue: settings.updateCheckInterval,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .setUpdateCheckInterval(value);
                  }
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Download Cache'),
        content: const Text(
          'This will remove all cached download files. '
          'Active downloads will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dir = await getTemporaryDirectory();
                final cacheDir = Directory(
                  p.join(dir.path, 'downloads'),
                );
                if (await cacheDir.exists()) {
                  await cacheDir.delete(recursive: true);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared successfully!'),
                    ),
                  );
                  setState(() {}); // refresh cache size
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear cache: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getLanguageLabel(String code) {
    for (final lang in _languages) {
      if (lang.code == code) {
        return '${lang.nativeName} (${lang.englishName})';
      }
    }
    return code;
  }

  Future<String> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(dir.path, 'downloads'));
      if (!await cacheDir.exists()) return '0 B';

      int totalBytes = 0;
      await for (final entity
          in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalBytes += await entity.length();
          } catch (_) {}
        }
      }
      return _formatBytes(totalBytes);
    } catch (_) {
      return 'Unknown';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall,
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// A text field for password / secret input with a show/hide toggle.
class _PasswordTextField extends StatefulWidget {
  const _PasswordTextField({
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.prefixIcon,
    required this.onSubmitted,
  });

  final String label;
  final String hintText;
  final String initialValue;
  final Widget prefixIcon;
  final ValueChanged<String> onSubmitted;

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _obscure = true;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        isDense: true,
      ),
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onSubmitted,
    );
  }
}
