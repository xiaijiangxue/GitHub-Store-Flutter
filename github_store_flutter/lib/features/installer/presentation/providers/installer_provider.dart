import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/installer_service.dart';
import '../../../core/platform/platform_service.dart';

/// Provider for the platform [PlatformService] singleton.
final platformServiceProvider = Provider<PlatformService>((ref) {
  return getPlatformService();
});

/// Provider for the [InstallerService] (high-level install orchestrator).
final installerServiceProvider = Provider<InstallerService>((ref) {
  final platformService = ref.watch(platformServiceProvider);
  return InstallerService(platformService: platformService);
});

/// Install state enum for tracking the installation lifecycle.
enum InstallState {
  /// Waiting to start (download not yet begun).
  idle,

  /// File is being downloaded.
  downloading,

  /// Download complete, starting installation.
  installing,

  /// Installation completed successfully.
  success,

  /// Installation failed.
  failed,

  /// User cancelled the operation.
  cancelled,
}

/// State class for the installer flow.
class InstallerState {
  const InstallerState({
    this.installState = InstallState.idle,
    this.downloadProgress = 0.0,
    this.downloadSpeed = 0,
    this.downloadEta = '',
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.logLines = const [],
    this.error,
    this.filePath,
    this.exitCode,
    this.method,
  });

  final InstallState installState;
  final double downloadProgress;
  final int downloadSpeed;
  final String downloadEta;
  final int downloadedBytes;
  final int totalBytes;
  final List<String> logLines;
  final String? error;
  final String? filePath;
  final int? exitCode;
  final InstallMethod? method;

  String get downloadProgressPercent =>
      '${(downloadProgress * 100).toStringAsFixed(1)}%';

  bool get canCancel =>
      installState == InstallState.downloading ||
      installState == InstallState.installing;

  InstallerState copyWith({
    InstallState? installState,
    double? downloadProgress,
    int? downloadSpeed,
    String? downloadEta,
    int? downloadedBytes,
    int? totalBytes,
    List<String>? logLines,
    String? error,
    String? filePath,
    int? exitCode,
    InstallMethod? method,
  }) {
    return InstallerState(
      installState: installState ?? this.installState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      downloadEta: downloadEta ?? this.downloadEta,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      logLines: logLines ?? this.logLines,
      error: error,
      filePath: filePath ?? this.filePath,
      exitCode: exitCode ?? this.exitCode,
      method: method ?? this.method,
    );
  }
}

/// StateNotifier for managing the installer flow.
class InstallerNotifier extends StateNotifier<InstallerState> {
  InstallerNotifier(this._installerService)
      : super(const InstallerState());

  final InstallerService _installerService;

  /// Install a file at [filePath] with optional [packageName].
  ///
  /// Streams real-time log output into [state.logLines].
  Future<void> install(String filePath, {String? packageName}) async {
    if (state.installState == InstallState.installing) {
      throw StateError('An installation is already in progress.');
    }

    final method = InstallMethod.fromFilePath(filePath);

    state = state.copyWith(
      installState: InstallState.installing,
      filePath: filePath,
      method: method,
      logLines: [],
      error: null,
      exitCode: null,
    );

    final result = await _installerService.install(
      filePath,
      packageName: packageName,
      onLog: (line, {bool isError = false}) {
        state = state.copyWith(
          logLines: [...state.logLines, line],
        );
      },
    );

    if (result.success) {
      state = state.copyWith(
        installState: InstallState.success,
        exitCode: result.exitCode,
      );
    } else {
      state = state.copyWith(
        installState: InstallState.failed,
        error: result.error ?? 'Installation failed (code: ${result.exitCode})',
        exitCode: result.exitCode,
      );
    }
  }

  /// Cancel the currently running installation.
  void cancel() {
    if (state.canCancel) {
      _installerService.cancel();
      state = state.copyWith(
        installState: InstallState.cancelled,
      );
    }
  }

  /// Reset state to initial.
  void reset() {
    state = const InstallerState();
  }

  /// Add a log line (for external log injection, e.g., during download phase).
  void addLog(String line, {bool isError = false}) {
    state = state.copyWith(
      logLines: [...state.logLines, isError ? '❌ $line' : line],
    );
  }

  /// Update download progress.
  void updateDownloadProgress({
    required double progress,
    required int speed,
    required String eta,
    required int downloaded,
    required int total,
  }) {
    state = state.copyWith(
      installState: InstallState.downloading,
      downloadProgress: progress,
      downloadSpeed: speed,
      downloadEta: eta,
      downloadedBytes: downloaded,
      totalBytes: total,
    );
  }

  /// Set state to installing (transition from downloading).
  void setInstalling() {
    state = state.copyWith(
      installState: InstallState.installing,
    );
  }
}

/// Provider for the [InstallerNotifier].
final installerNotifierProvider =
    StateNotifierProvider<InstallerNotifier, InstallerState>((ref) {
  final installerService = ref.watch(installerServiceProvider);
  return InstallerNotifier(installerService);
});

/// Convenience provider for the current install state enum.
final installStateProvider =
    Provider<InstallState>((ref) => ref.watch(installerNotifierProvider).installState);

/// Convenience provider for the install log lines.
final installLogProvider =
    Provider<List<String>>((ref) => ref.watch(installerNotifierProvider).logLines);

/// Format bytes for display.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Format speed for display.
String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
  if (bytesPerSecond < 1024 * 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
  return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}

/// Format remaining time in seconds.
String formatEta(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
}
