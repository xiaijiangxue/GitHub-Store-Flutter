import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/cache/cache_manager.dart';
import 'core/telemetry/telemetry_service.dart';
import 'core/crash/cash_reporter.dart';
import 'core/translation/translation_service.dart';
import 'core/updater/update_checker.dart';
import 'features/settings/presentation/providers/theme_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

/// Global navigator key for the app, used by GoRouter and deep link handling.
final globalNavigatorKey = GlobalKey<NavigatorState>();

/// The root application widget for GitHub Store.
///
/// Initializes and wires together all core services:
/// - [CacheManager] for two-tier caching
/// - [AuthService] for GitHub OAuth device flow
/// - [TelemetryService] for anonymous usage analytics
/// - [CrashReporter] for error capture and logging
/// - [UpdateChecker] for version checking
/// - [TranslationService] for README/release notes translation
///
/// Sets up localization, theming, routing, keyboard shortcuts, and
/// clipboard monitoring.
class GitHubStoreApp extends ConsumerStatefulWidget {
  const GitHubStoreApp({
    required this.authService,
    required this.telemetryService,
    required this.crashReporter,
    required this.updateChecker,
    required this.translationService,
    required this.cacheManager,
    super.key,
  });

  final AuthService authService;
  final TelemetryService telemetryService;
  final CrashReporter crashReporter;
  final UpdateChecker updateChecker;
  final TranslationService translationService;
  final CacheManager cacheManager;

  @override
  ConsumerState<GitHubStoreApp> createState() => _GitHubStoreAppState();
}

class _GitHubStoreAppState extends ConsumerState<GitHubStoreApp>
    with WidgetsBindingObserver {
  // ── Service Providers ───────────────────────────────────────────────────

  late final Provider<AuthService> _authServiceProvider;
  late final Provider<TelemetryService> _telemetryServiceProvider;
  late final Provider<CrashReporter> _crashReporterProvider;
  late final Provider<UpdateChecker> _updateCheckerProvider;
  late final Provider<TranslationService> _translationServiceProvider;
  late final Provider<CacheManager> _cacheManagerProvider;

  // ── State ───────────────────────────────────────────────────────────────

  StreamSubscription? _settingsSubscription;
  Timer? _updateCheckTimer;
  String _lastClipboardText = '';
  Timer? _clipboardDebounce;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register Riverpod providers for all services
    _registerServiceProviders();

    // Track app opened event
    widget.telemetryService.trackEvent(TelemetryEventType.appOpened);

    // Listen for settings changes to reactively update services
    _settingsSubscription = _listenToSettings();

    // Start periodic update checker
    _startUpdateChecker();

    // Setup keyboard shortcuts
    _setupKeyboardShortcuts();

    // Setup clipboard monitoring (debounced initialization)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _setupClipboardMonitoring();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.cancel();
    _updateCheckTimer?.cancel();
    _clipboardDebounce?.cancel();
    widget.telemetryService.dispose();
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Locale changed from system settings
    super.didChangeLocales(locales);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground, check for updates
        widget.updateChecker.checkForUpdate();
        break;
      case AppLifecycleState.paused:
        // App went to background, flush telemetry events
        widget.telemetryService.flush();
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
      case AppLifecycleState.detached:
        // App is being detached
        widget.telemetryService.dispose();
        break;
    }
  }

  // ── Service Provider Registration ───────────────────────────────────────

  void _registerServiceProviders() {
    _authServiceProvider = Provider<AuthService>((ref) => widget.authService);
    _telemetryServiceProvider =
        Provider<TelemetryService>((ref) => widget.telemetryService);
    _crashReporterProvider =
        Provider<CrashReporter>((ref) => widget.crashReporter);
    _updateCheckerProvider =
        Provider<UpdateChecker>((ref) => widget.updateChecker);
    _translationServiceProvider =
        Provider<TranslationService>((ref) => widget.translationService);
    _cacheManagerProvider =
        Provider<CacheManager>((ref) => widget.cacheManager);
  }

  // ── Settings Listener ───────────────────────────────────────────────────

  StreamSubscription _listenToSettings() {
    // Watch for settings changes and update services accordingly.
    // Since we can't directly listen to a StateNotifier, we poll via a periodic
    // check that compares the current state with the last known state.
    SettingsModel? lastSettings;

    return Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (!mounted) return;

      final settings = ref.read(settingsProvider);

      // Skip if settings haven't changed
      if (settings == lastSettings) return;
      lastSettings = settings;

      // Sync analytics setting
      if (settings.analyticsEnabled != widget.telemetryService.isEnabled) {
        if (settings.analyticsEnabled) {
          widget.telemetryService.enable();
        } else {
          widget.telemetryService.disable();
        }
      }

      // Sync translation provider
      widget.translationService.setDefaultProvider(settings.translationProvider);
      if (settings.youdaoAppKey != null && settings.youdaoAppSecret != null) {
        widget.translationService
            .setYoudaoCredentials(settings.youdaoAppKey, settings.youdaoAppSecret);
      }

      // Sync update checker settings
      widget.updateChecker.setCheckInterval(settings.updateCheckInterval);
      widget.updateChecker.setIncludePrerelease(settings.includePrerelease);
    });
  }

  // ── Update Checker ──────────────────────────────────────────────────────

  void _startUpdateChecker() {
    // Initial check after a short delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.updateChecker.checkForUpdate();
      }
    });
  }

  // ── Keyboard Shortcuts ─────────────────────────────────────────────────

  void _setupKeyboardShortcuts() {
    // Ctrl+F or Cmd+F -> Focus search
    // Ctrl+, or Cmd+, -> Open settings
    // Ctrl+Shift+I or Cmd+Shift+I -> Toggle compact mode
    // These are handled via a KeyboardListener in the builder
  }

  // ── Clipboard Monitoring ────────────────────────────────────────────────

  void _setupClipboardMonitoring() {
    final settings = ref.read(settingsProvider);
    if (!settings.clipboardDetectionEnabled) return;

    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    final settings = ref.read(settingsProvider);
    if (!settings.clipboardDetectionEnabled || !mounted) return;

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text ?? '';

      if (text.isNotEmpty && text != _lastClipboardText) {
        _lastClipboardText = text;

        // Check if the clipboard contains a GitHub URL
        if (_isGitHubUrl(text)) {
          _showClipboardDialog(text);
          return;
        }
      }
    } catch (e) {
      debugPrint('[Clipboard] Error checking clipboard: $e');
    }

    // Check again after 3 seconds
    if (mounted) {
      Future.delayed(const Duration(seconds: 3), _checkClipboard);
    }
  }

  bool _isGitHubUrl(String text) {
    final url = text.trim();
    return url.startsWith('https://github.com/') ||
        url.startsWith('http://github.com/') ||
        url.startsWith('github.com/');
  }

  void _showClipboardDialog(String url) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    // Extract owner/repo from URL
    final ownerRepo = _extractOwnerRepo(url);
    if (ownerRepo == null) return;

    final owner = ownerRepo.$1;
    final repo = ownerRepo.$2;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('GitHub Link Detected'),
        content: Text('Would you like to open $owner/$repo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              GoRouter.of(context).go('/details/$owner/$repo');
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  (String, String)? _extractOwnerRepo(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final parts = uri.pathSegments;
    if (parts.length >= 2) {
      return (parts[0], parts[1]);
    }
    return null;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(effectiveThemeModeProvider);
    final colorSchemeIndex = ref.watch(colorSchemeIndexProvider);
    final isAmoled = ref.watch(isAmoledProvider);

    // Build the theme based on settings
    ThemeData theme;
    if (isAmoled) {
      theme = AppTheme.amoledTheme(colorSchemeIndex);
    } else if (themeMode == ThemeMode.dark) {
      theme = AppTheme.darkTheme(colorSchemeIndex);
    } else {
      theme = AppTheme.lightTheme(colorSchemeIndex);
    }

    // Determine locale from settings
    final locale = _resolveLocale(settings.languageCode);

    return MaterialApp.router(
      key: const ValueKey('GitHubStore'),
      title: 'GitHub Store',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey,

      // Theme - reactive to settings changes
      theme: AppTheme.lightTheme(colorSchemeIndex),
      darkTheme: isAmoled
          ? AppTheme.amoledTheme(colorSchemeIndex)
          : AppTheme.darkTheme(colorSchemeIndex),
      themeMode: themeMode,

      // Localization
      locale: locale,
      supportedLocales: _supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: _localeResolutionCallback,

      // Router
      routerConfig: AppRouter.router,

      // Builder for additional configurations
      builder: (context, child) {
        return _AppKeyboardHandler(
          child: MediaQuery.withNoTextScaling(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  // ── Locale Helpers ──────────────────────────────────────────────────────

  static const List<Locale> _supportedLocales = [
    Locale('en', 'US'),
    Locale('zh', 'CN'),
    Locale('ja', 'JP'),
    Locale('ko', 'KR'),
    Locale('de', 'DE'),
    Locale('fr', 'FR'),
    Locale('es', 'ES'),
    Locale('pt', 'BR'),
    Locale('ru', 'RU'),
  ];

  Locale? _resolveLocale(String languageCode) {
    // Map short codes to full locale codes
    final codeMap = <String, String>{
      'en': 'en_US',
      'zh': 'zh_CN',
      'zh-CN': 'zh_CN',
      'ja': 'ja_JP',
      'ko': 'ko_KR',
      'de': 'de_DE',
      'fr': 'fr_FR',
      'es': 'es_ES',
      'pt': 'pt_BR',
      'pt-BR': 'pt_BR',
      'ru': 'ru_RU',
    };

    final fullCode = codeMap[languageCode] ?? languageCode;
    final parts = fullCode.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }

  Locale? _localeResolutionCallback(
      Locale? locale, Iterable<Locale> supportedLocales) {
    if (locale == null) return const Locale('en', 'US');

    // Exact match
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode &&
          supported.countryCode == locale.countryCode) {
        return supported;
      }
    }

    // Language-only match
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }

    return const Locale('en', 'US');
  }
}

/// Widget that handles global keyboard shortcuts via a FocusNode.
class _AppKeyboardHandler extends StatelessWidget {
  const _AppKeyboardHandler({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isMeta = HardwareKeyboard.instance.isMetaPressed;

        // Ctrl/Cmd + F -> Navigate to search
        if ((isCtrl || isMeta) && event.logicalKey == LogicalKeyboardKey.keyF) {
          GoRouter.of(context).go('/search');
          return KeyEventResult.handled;
        }

        // Ctrl/Cmd + , -> Navigate to settings
        if ((isCtrl || isMeta) &&
            event.logicalKey == LogicalKeyboardKey.comma) {
          GoRouter.of(context).go('/settings');
          return KeyEventResult.handled;
        }

        // Ctrl/Cmd + W -> Go back
        if ((isCtrl || isMeta) &&
            event.logicalKey == LogicalKeyboardKey.keyW) {
          if (GoRouter.of(context).canPop()) {
            GoRouter.of(context).pop();
          }
          return KeyEventResult.handled;
        }

        // Escape -> Pop if possible
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
