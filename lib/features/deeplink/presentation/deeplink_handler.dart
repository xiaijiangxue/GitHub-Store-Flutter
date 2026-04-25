import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/deeplink_repository.dart';

/// Mixin that adds deep link handling to a [State] or [ConsumerState].
///
/// Usage:
/// ```dart
/// class _MyAppState extends State<MyApp> with DeepLinkHandlerMixin {
///   @override
///   void initState() {
///     super.initState();
///     registerDeepLinkHandler();
///   }
/// }
/// ```
mixin DeepLinkHandlerMixin {
  /// The deep link repository instance.
  final DeeplinkRepository _deeplinkRepo = DeeplinkRepository();

  /// Subscription to the deep link stream.
  StreamSubscription<Uri>? _deepLinkSubscription;

  /// Handle a deep link URL string.
  ///
  /// Parses the URL and, if valid, navigates to the appropriate screen.
  /// Returns `true` if the URL was handled successfully, `false` otherwise.
  @protected
  bool handleDeeplink(String url, {BuildContext? context}) {
    final result = _deeplinkRepo.parse(url);
    debugPrint('[DeepLink] Parsed: $url → $result');

    if (result.type == DeeplinkType.repoDetails &&
        result.owner != null &&
        result.repo != null) {
      _navigateToRepoDetails(result.owner!, result.repo!);
      return true;
    }

    debugPrint('[DeepLink] Unrecognised URL: $url');
    return false;
  }

  /// Navigate to the repository details screen.
  void _navigateToRepoDetails(String owner, String repo) {
    // Access the global GoRouter and navigate.
    // The GoRouter instance is obtained through the global navigator key.
    // When used from within the widget tree, the context should be available.
    final navigatorKey = WidgetsBinding.instance.platformDispatcher
        .onBeginFrame as GlobalKey<NavigatorState>?;

    // Fallback: use GoRouter directly.
    // This is designed to be called from within the app's BuildContext.
    try {
      final uri = Uri.parse('/details/$owner/$repo');
      // We push via the GoRouter using the navigation key if available.
      // In most cases, the app widget will call this during platform link setup.
      if (navigatorKey?.currentContext != null) {
        GoRouterHelper.navigate(navigatorKey!.currentContext!, uri.toString());
      } else {
        debugPrint(
          '[DeepLink] Cannot navigate: no context available. '
          'Queueing navigation to /details/$owner/$repo',
        );
        // Store the pending navigation for later processing
        _pendingNavigation = '/details/$owner/$repo';
      }
    } catch (e) {
      debugPrint('[DeepLink] Navigation error: $e');
    }
  }

  /// Pending navigation path that will be processed when context is available.
  static String? _pendingNavigation;

  /// If there is a pending navigation, process it and clear the pending state.
  @protected
  bool processPendingNavigation(BuildContext context) {
    if (_pendingNavigation != null) {
      final path = _pendingNavigation!;
      _pendingNavigation = null;
      GoRouterHelper.navigate(context, path);
      return true;
    }
    return false;
  }

  /// Register platform-specific deep link handlers.
  ///
  /// Call this during app initialisation (e.g., in `initState`).
  ///
  /// On **Windows**: registers a URL protocol handler in the Windows registry
  /// so that `githubstore://` URLs open the app.
  ///
  /// On **macOS**: registers a URL scheme via `CFBundleURLTypes` in
  /// `Info.plist` (must be done at build time, this method logs a warning).
  ///
  /// On **Linux**: creates a `.desktop` file entry with the `MimeType` entry
  /// for the `x-scheme-handler/githubstore` protocol.
  @protected
  Future<void> registerDeepLinkHandler() async {
    if (kIsWeb) {
      debugPrint('[DeepLink] Deep links are not supported on web.');
      return;
    }

    try {
      if (Platform.isWindows) {
        await _registerWindowsProtocol();
      } else if (Platform.isMacOS) {
        _registerMacOSUrlScheme();
      } else if (Platform.isLinux) {
        await _registerLinuxDesktopEntry();
      }
    } catch (e) {
      debugPrint('[DeepLink] Failed to register deep link handler: $e');
    }
  }

  /// Dispose the deep link subscription.
  @protected
  void disposeDeepLinkHandler() {
    _deepLinkSubscription?.cancel();
    _deepLinkSubscription = null;
  }

  // ── Windows ──────────────────────────────────────────────────────────────

  /// Register the `githubstore://` protocol in the Windows registry.
  ///
  /// This creates the following registry keys:
  /// - `HKEY_CURRENT_USER\Software\Classes\githubstore`
  /// - `HKEY_CURRENT_USER\Software\Classes\githubstore\shell\open\command`
  Future<void> _registerWindowsProtocol() async {
    try {
      final exePath = Platform.resolvedExecutable;

      // Use PowerShell to write registry keys (user scope).
      final commands = <String>[
        // Delete existing key if present
        'reg delete "HKCU\\Software\\Classes\\githubstore" /f 2>nul || true',

        // Create the protocol handler
        'reg add "HKCU\\Software\\Classes\\githubstore" '
            '/ve /t REG_SZ /d "URL:GitHub Store" /f',

        'reg add "HKCU\\Software\\Classes\\githubstore" '
            '/v "URL Protocol" /t REG_SZ /d "" /f',

        'reg add "HKCU\\Software\\Classes\\githubstore\\shell\\open\\command" '
            '/ve /t REG_SZ /d "\\"$exePath\\" \\"%1\\"" /f',
      ];

      for (final cmd in commands) {
        final process = await Process.run(
          'cmd.exe',
          ['/c', cmd],
          runInShell: true,
        );
        if (process.exitCode != 0 && !cmd.startsWith('reg delete')) {
          debugPrint(
            '[DeepLink] Registry command failed: ${process.stderr}',
          );
        }
      }

      debugPrint('[DeepLink] Windows protocol handler registered.');
    } catch (e) {
      debugPrint('[DeepLink] Failed to register Windows protocol: $e');
    }
  }

  // ── macOS ────────────────────────────────────────────────────────────────

  /// On macOS, the URL scheme must be declared in `Info.plist` at build time.
  ///
  /// The following entry should be added to `macos/Runner/Info.plist`:
  /// ```xml
  /// <key>CFBundleURLTypes</key>
  /// <array>
  ///   <dict>
  ///     <key>CFBundleURLSchemes</key>
  ///     <array>
  ///       <string>githubstore</string>
  ///     </array>
  ///     <key>CFBundleURLName</key>
  ///     <string>org.github-store.app</string>
  ///   </dict>
  /// </array>
  /// ```
  void _registerMacOSUrlScheme() {
    debugPrint(
      '[DeepLink] macOS URL scheme must be configured in Info.plist. '
      'Add CFBundleURLTypes with scheme "githubstore" to '
      'macos/Runner/Info.plist.',
    );
  }

  // ── Linux ────────────────────────────────────────────────────────────────

  /// Register the `githubstore://` scheme on Linux via a `.desktop` file.
  ///
  /// Creates/updates `~/.local/share/applications/github-store.desktop`
  /// with a `MimeType` entry for the custom URL scheme.
  Future<void> _registerLinuxDesktopEntry() async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return;

      final appsDir = Directory('$home/.local/share/applications');
      if (!await appsDir.exists()) {
        await appsDir.create(recursive: true);
      }

      final desktopFile = File('${appsDir.path}/github-store.desktop');
      final exePath = Platform.resolvedExecutable;

      final content = '''[Desktop Entry]
Type=Application
Name=GitHub Store
Comment=Browse and install GitHub applications
Exec=$exePath %u
Icon=github-store
Terminal=false
Categories=Development;Utility;
MimeType=x-scheme-handler/githubstore;
StartupNotify=true
''';

      await desktopFile.writeAsString(content);

      // Update desktop database
      await Process.run('update-desktop-database', [appsDir.path]);

      debugPrint('[DeepLink] Linux .desktop entry registered.');
    } catch (e) {
      debugPrint('[DeepLink] Failed to register Linux desktop entry: $e');
    }
  }
}

/// Helper for GoRouter navigation without direct access to a BuildContext.
class GoRouterHelper {
  /// Navigate to the given path using the GoRouter.
  ///
  /// This method should be called from within the widget tree where
  /// a [BuildContext] is available. It delegates to [GoRouter.of].
  static void navigate(BuildContext context, String path) {
    try {
      GoRouter.of(context).go(path);
    } catch (e) {
      debugPrint('[GoRouterHelper] Navigation failed: $e');
    }
  }

  /// Push a route onto the navigation stack.
  static void push(BuildContext context, String path) {
    try {
      GoRouter.of(context).push(path);
    } catch (e) {
      debugPrint('[GoRouterHelper] Push failed: $e');
    }
  }
}
