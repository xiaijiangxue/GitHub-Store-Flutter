import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';

import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/cache/cache_manager.dart';
import 'core/crash/cash_reporter.dart';
import 'core/database/app_database.dart';
import 'core/telemetry/telemetry_service.dart';
import 'core/translation/translation_service.dart';
import 'core/updater/update_checker.dart';
import 'features/deeplink/presentation/deeplink_handler.dart';
import 'features/home/presentation/providers/home_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

/// Entry point for the GitHub Store desktop application.
///
/// Performs the following initialization steps:
/// 1. Initializes Flutter bindings.
/// 2. Initializes [SharedPreferences] for persistent settings.
/// 3. Sets up [WindowManager] for desktop window management.
/// 4. Creates and initializes all core services.
/// 5. Sets up system tray with context menu.
/// 6. Installs [CrashReporter] and wraps the app in an error zone.
/// 7. Runs the app with [ProviderScope] containing all service providers.
Future<void> main() async {
  // Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for persistent settings
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize the crash reporter as early as possible
  final crashReporter = CrashReporter(
    appVersion: const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0+1',
    ),
  );
  await crashReporter.initialize();

  // Initialize the database
  final database = AppDatabase();

  // Initialize the cache manager with database backing
  final cacheManager = CacheManager(database: database);

  // Initialize the auth service
  final authService = AuthService();
  final hasToken = await authService.initialize();

  // Initialize telemetry service
  final telemetryService = TelemetryService(
    prefs: sharedPreferences,
  );
  await telemetryService.initialize();

  // Check persisted analytics setting
  final analyticsEnabled = sharedPreferences.getBool('telemetry_enabled') ?? true;
  if (!analyticsEnabled) {
    await telemetryService.disable();
  }

  // Initialize translation service
  final settingsRepo = SettingsRepository(database: database);
  final settings = await settingsRepo.getSettings();

  final translationService = TranslationService(
    youdaoAppKey: settings.youdaoAppKey,
    youdaoAppSecret: settings.youdaoAppSecret,
    defaultProvider: settings.translationProvider,
  );

  // Initialize update checker
  final updateChecker = UpdateChecker(
    prefs: sharedPreferences,
    checkInterval: settings.updateCheckInterval,
    includePrerelease: settings.includePrerelease,
  );

  // Setup window manager for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _initWindowManager();
  }

  // Run the app inside an error-guarded zone
  return CrashReporter.runZoned(
    () async {
      // Initialize system tray after the app is running
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // System tray is initialized after the first frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initSystemTray(updateChecker);
        });
      }

      // Handle single-instance deep links
      _handleInitialDeepLink();

      runApp(
        ProviderScope(
          overrides: [
            // Override the database provider with the initialized instance
            databaseProvider.overrideWithValue(database),
            // Override the cache manager provider
            cacheManagerProvider.overrideWithValue(cacheManager),
          ],
          child: GitHubStoreApp(
            authService: authService,
            telemetryService: telemetryService,
            crashReporter: crashReporter,
            updateChecker: updateChecker,
            translationService: translationService,
            cacheManager: cacheManager,
          ),
        ),
      );
    },
    (error, stack) {
      // Handle uncaught async errors via the crash reporter
      debugPrint('[Main] Uncaught error in zone: $error');
      crashReporter.handleZoneError(error, stack);
    },
  );
}

// ── Window Manager Initialization ─────────────────────────────────────────

/// Initialize [WindowManager] with window size, minimum size, and title.
///
/// On macOS, hides the native title bar for a more modern look.
/// On Windows, uses the default title bar.
/// On Linux, uses the default title bar with proper GTK theming.
Future<void> _initWindowManager() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'GitHub Store',
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyShown(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();

    // Prevent window from being resized too small
    windowManager.setPreventClose(true);
  });

  // Handle window close event (hide to tray instead of closing)
  windowManager.addListener(_AppWindowListener());
}

/// Window event listener that handles close events by minimizing to tray.
class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Instead of closing, hide to system tray
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.hide();
    } else if (Platform.isMacOS) {
      // On macOS, also hide to tray
      await windowManager.hide();
    }
  }

  @override
  void onWindowFocus() {
    // Set window as focused
    windowManager.setAlwaysOnTop(false);
  }

  @override
  void onWindowResized() {
    // No-op, but available for future use
  }

  @override
  void onWindowMoved() {
    // No-op, but available for future use
  }

  @override
  void onWindowMaximize() {
    // No-op
  }

  @override
  void onWindowUnmaximize() {
    // No-op
  }

  @override
  void onWindowMinimize() {
    // No-op
  }

  @override
  void onWindowRestored() {
    // No-op
  }

  @override
  void onWindowEnterFullScreen() {
    // No-op
  }

  @override
  void onWindowLeaveFullScreen() {
    // No-op
  }

  @override
  void onWindowEvent(String eventName) {
    debugPrint('[WindowManager] Event: $eventName');
  }

  @override
  void onWindowDocked() {
    // No-op
  }

  @override
  void onWindowUndocked() {
    // No-op
  }
}

// ── System Tray Initialization ───────────────────────────────────────────

/// Initialize the system tray with a context menu.
///
/// Menu items:
/// - **Show**: Show and focus the window.
/// - **Check Updates**: Trigger an update check.
/// - **Quit**: Exit the application.
///
/// Also handles single-click (show window) and right-click (show menu).
Future<void> _initSystemTray(UpdateChecker updateChecker) async {
  final systemTray = SystemTray();

  final menu = Menu(
    items: [
      MenuItemLabel(
        label: 'Show',
        onClick: () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItemLabel(
        label: 'Check for Updates',
        onClick: () async {
          await windowManager.show();
          await windowManager.focus();
          updateChecker.checkForUpdate(force: true);
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Quit',
        onClick: () async {
          // Perform cleanup before exiting
          await _cleanupBeforeExit();
          await systemTray.destroy();
          exit(0);
        },
      ),
    ],
  );

  // Determine icon path based on platform
  final iconPath = _getTrayIconPath();

  await systemTray.initSystemTray(
    title: 'GitHub Store',
    iconPath: iconPath,
    toolTip: 'GitHub Store - Browse & Install GitHub Apps',
  );

  await systemTray.setContextMenu(menu);

  // Register system tray event handler
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      // Single click: show window
      windowManager.show();
      windowManager.focus();
    } else if (eventName == kSystemTrayEventRightClick) {
      // Right click: show context menu
      systemTray.popUpContextMenu();
    }
  });
}

/// Get the appropriate icon path for the system tray based on platform.
String _getTrayIconPath() {
  if (Platform.isWindows) {
    return 'assets/icons/app_icon.ico';
  } else if (Platform.isMacOS) {
    return 'assets/icons/app_icon.png';
  } else {
    return 'assets/icons/app_icon.png';
  }
}

// ── Deep Link Handling ────────────────────────────────────────────────────

/// Handle any initial deep link arguments passed to the application.
///
/// On desktop, deep links are passed as command-line arguments.
void _handleInitialDeepLink() {
  // Check command-line arguments for a githubstore:// URL
  final args = Platform.executable.split(' ');
  if (args.length > 1) {
    for (final arg in args.skip(1)) {
      if (arg.startsWith('githubstore://')) {
        debugPrint('[Main] Initial deep link: $arg');
        // The deep link handler in the app will process this
        // when the widget tree is built.
        break;
      }
    }
  }
}

// ── Cleanup ──────────────────────────────────────────────────────────────

/// Perform cleanup before the application exits.
Future<void> _cleanupBeforeExit() async {
  debugPrint('[Main] Performing cleanup before exit...');

  // Flush any pending telemetry events
  // (The telemetry service is accessed through the ProviderScope,
  // so we can't directly flush here without a ref)
  // This is handled by the dispose() in the app widget.

  // Give a small delay for any pending I/O operations
  await Future.delayed(const Duration(milliseconds: 500));
}
