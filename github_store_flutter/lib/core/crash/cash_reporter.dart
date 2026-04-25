import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Represents a single crash log entry with metadata.
class CrashLog {
  CrashLog({
    required this.filePath,
    required this.timestamp,
    required this.appVersion,
    required this.platform,
    required this.errorMessage,
    required this.stackTrace,
  });

  final String filePath;
  final DateTime timestamp;
  final String appVersion;
  final String platform;
  final String errorMessage;
  final String stackTrace;

  /// Read a crash log from a file.
  factory CrashLog.fromFile(File file) {
    final lines = file.readAsLinesSync();
    String timestamp = '';
    String appVersion = 'unknown';
    String platform = 'unknown';
    String errorMessage = '';
    String stackTrace = '';

    final stackLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('Timestamp: ')) {
        timestamp = line.substring('Timestamp: '.length);
      } else if (line.startsWith('Version: ')) {
        appVersion = line.substring('Version: '.length);
      } else if (line.startsWith('Platform: ')) {
        platform = line.substring('Platform: '.length);
      } else if (line.startsWith('Error: ')) {
        errorMessage = line.substring('Error: '.length);
      } else if (line.startsWith('--- Stack Trace ---')) {
        // Stack trace starts after this line
      } else if (line.isNotEmpty && errorMessage.isNotEmpty) {
        stackLines.add(line);
      }
    }

    stackTrace = stackLines.join('\n').trimRight();

    return CrashLog(
      filePath: file.path,
      timestamp: DateTime.tryParse(timestamp) ?? file.lastModifiedSync(),
      appVersion: appVersion,
      platform: platform,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() =>
      'CrashLog($timestamp, $appVersion, $platform, $errorMessage)';
}

/// Crash reporter service that captures unhandled Flutter errors and
/// writes crash logs to platform-specific directories.
///
/// Log format:
/// ```
/// Timestamp: 2024-01-15T10:30:00.000Z
/// Version: 1.0.0+1
/// Platform: windows
/// Error: Exception: Something went wrong
/// --- Stack Trace ---
/// #0      someMethod (package:example/file.dart:42:5)
/// #1      anotherMethod (package:example/file.dart:10:3)
/// ```
///
/// Maintains a maximum of 5 crash log files, removing the oldest when
/// the limit is exceeded.
class CrashReporter {
  CrashReporter({
    String? appVersion,
  }) : _appVersion = appVersion ?? _extractAppVersion();

  final String _appVersion;
  Directory? _crashLogDir;
  bool _initialized = false;

  /// Maximum number of crash log files to keep.
  static const int _maxCrashLogs = 5;

  /// Maximum number of characters for a single stack trace.
  static const int _maxStackTraceLength = 10000;

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initialize the crash reporter.
  ///
  /// Installs [FlutterError.onError] and [PlatformDispatcher.onError] handlers.
  /// Ensures the crash log directory exists.
  ///
  /// Call this once during app startup, before [runApp].
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Setup crash log directory
    _crashLogDir = await _getCrashLogDirectory();
    await _crashLogDir!.create(recursive: true);

    // Install Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      _reportFlutterError(details);
    };

    // Install async error handler via runZonedGuarded
    // Note: The actual runZonedGuarded wrapping should be done in main()
    // Here we just set up the handler logic.

    debugPrint('[CrashReporter] Initialized. Log directory: ${_crashLogDir!.path}');
  }

  /// Run the app inside a guarded zone that catches unhandled async errors.
  ///
  /// This should wrap the [runApp] call in main():
  /// ```dart
  /// await crashReporter.initialize();
  /// runZonedGuarded(
  ///   () => runApp(const MyApp()),
  ///   crashReporter.handleZoneError,
  /// );
  /// ```
  static void runZoned(Runnable body, void Function(Object, StackTrace) onError) {
    runZonedGuarded(body, onError);
  }

  /// Handle an error caught by [runZonedGuarded].
  ///
  /// This is a convenience method to be passed as the error handler
  /// to [runZonedGuarded].
  Future<void> handleZoneError(Object error, StackTrace stack) async {
    debugPrint('[CrashReporter] Unhandled zone error: $error');
    await _writeCrashLog(
      errorMessage: error.toString(),
      stackTrace: stack.toString(),
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Get all recent crash logs sorted by timestamp (newest first).
  ///
  /// Returns an empty list if the crash log directory does not exist.
  Future<List<CrashLog>> getRecentCrashLogs() async {
    if (_crashLogDir == null) return [];

    try {
      final files = await _crashLogDir!
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Read and parse each crash log
      final logs = <CrashLog>[];
      for (final file in files) {
        try {
          logs.add(CrashLog.fromFile(file));
        } catch (e) {
          debugPrint('[CrashReporter] Failed to read crash log: ${file.path}');
        }
      }

      return logs;
    } catch (e) {
      debugPrint('[CrashReporter] Failed to list crash logs: $e');
      return [];
    }
  }

  /// Clear all crash log files.
  ///
  /// Returns the number of files deleted.
  Future<int> clearCrashLogs() async {
    if (_crashLogDir == null) return 0;

    try {
      int deletedCount = 0;
      await for (final entity in _crashLogDir!.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (_) {}
        }
      }

      debugPrint('[CrashReporter] Cleared $deletedCount crash log(s)');
      return deletedCount;
    } catch (e) {
      debugPrint('[CrashReporter] Failed to clear crash logs: $e');
      return 0;
    }
  }

  /// Manually report a crash/error for diagnostic purposes.
  ///
  /// This is useful for catching errors that are handled but should
  /// still be logged for analysis.
  Future<void> reportError(String errorMessage, StackTrace stackTrace) async {
    await _writeCrashLog(
      errorMessage: errorMessage,
      stackTrace: stackTrace.toString(),
    );
  }

  /// Get the crash log directory path.
  String? get crashLogDirectoryPath => _crashLogDir?.path;

  // ── Private Methods ─────────────────────────────────────────────────────

  /// Handle a Flutter framework error.
  void _reportFlutterError(FlutterErrorDetails details) {
    final errorMessage = details.exceptionAsString();
    final stackTrace = details.stack?.toString() ?? '';

    // Also print to debug console
    FlutterError.dumpErrorToConsole(details);

    // Write to crash log file
    _writeCrashLog(
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );
  }

  /// Write a crash log to a file in the platform-specific directory.
  Future<void> _writeCrashLog({
    required String errorMessage,
    required String stackTrace,
  }) async {
    if (_crashLogDir == null) return;

    try {
      // Truncate very long stack traces
      String truncatedStack = stackTrace;
      if (truncatedStack.length > _maxStackTraceLength) {
        truncatedStack =
            '${truncatedStack.substring(0, _maxStackTraceLength)}\n... (truncated)';
      }

      final timestamp = DateTime.now().toUtc();
      final fileName =
          'crash_${timestamp.millisecondsSinceEpoch}.log';
      final filePath = p.join(_crashLogDir!.path, fileName);

      final logContent = [
        'Timestamp: ${timestamp.toIso8601String()}',
        'Version: $_appVersion',
        'Platform: ${Platform.operatingSystem}',
        'Error: $errorMessage',
        '--- Stack Trace ---',
        truncatedStack,
        '',
      ].join('\n');

      final file = File(filePath);
      await file.writeAsString(logContent);

      debugPrint('[CrashReporter] Crash log written to: $filePath');

      // Enforce max crash logs
      await _enforceMaxCrashLogs();
    } catch (e) {
      debugPrint('[CrashReporter] Failed to write crash log: $e');
    }
  }

  /// Remove the oldest crash log files if the count exceeds [_maxCrashLogs].
  Future<void> _enforceMaxCrashLogs() async {
    if (_crashLogDir == null) return;

    try {
      final files = await _crashLogDir!
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // Sort by modification time (oldest first)
      files.sort((a, b) =>
          a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Remove excess files
      while (files.length > _maxCrashLogs) {
        final oldest = files.removeAt(0);
        try {
          await oldest.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Get the platform-specific crash log directory.
  Future<Directory> _getCrashLogDirectory() async {
    if (Platform.isWindows) {
      final appDataDir =
          Directory(Platform.environment['APPDATA'] ?? r'C:\AppData\Roaming');
      return Directory(p.join(appDataDir.path, 'GitHubStore', 'crash_logs'));
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return Directory(p.join(
          home, 'Library', 'Application Support', 'GitHubStore', 'crash_logs'));
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return Directory(p.join(
          home, '.local', 'share', 'github_store', 'crash_logs'));
    }

    // Fallback
    final tempDir = Directory.systemTemp;
    return Directory(p.join(tempDir.path, 'github_store', 'crash_logs'));
  }

  /// Extract app version from environment or default.
  static String _extractAppVersion() {
    return const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');
  }
}
