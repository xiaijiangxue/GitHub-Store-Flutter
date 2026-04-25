import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/installer_service.dart';
import '../../../core/platform/platform_service.dart';
import 'providers/installer_provider.dart';

/// Installation progress/conversation screen.
///
/// Shows the selected asset being downloaded with real-time progress,
/// then transitions to the installation phase with a scrollable log console.
class InstallerScreen extends ConsumerStatefulWidget {
  const InstallerScreen({
    required this.owner,
    required this.repo,
    this.filePath,
    this.assetName,
    super.key,
  });

  /// Repository owner login.
  final String owner;

  /// Repository name.
  final String repo;

  /// Path to the already-downloaded file (optional; if null, download is needed).
  final String? filePath;

  /// Asset file name for display purposes.
  final String? assetName;

  @override
  ConsumerState<InstallerScreen> createState() => _InstallerScreenState();
}

class _InstallerScreenState extends ConsumerState<InstallerScreen> {
  late final ScrollController _logScrollController;
  CancelToken? _downloadCancelToken;
  bool _disposed = false;
  String? _resolvedFilePath;

  @override
  void initState() {
    super.initState();
    _logScrollController = ScrollController();
    // If filePath is provided, go straight to install; otherwise download first
    if (widget.filePath != null) {
      _resolvedFilePath = widget.filePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInstallation();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _downloadCancelToken?.cancel('Screen disposed');
    _logScrollController.dispose();
    super.dispose();
  }

  void _scrollLogToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Watch the log lines and auto-scroll.
  void _watchLog() {
    ref.listen(installLogProvider, (previous, next) {
      if (next.length > (previous?.length ?? 0)) {
        _scrollLogToBottom();
      }
    });
  }

  /// Start the installation phase.
  Future<void> _startInstallation() async {
    final notifier = ref.read(installerNotifierProvider.notifier);
    final path = _resolvedFilePath ?? widget.filePath;

    if (path == null) {
      notifier.addLog('Error: No file path provided.', isError: true);
      notifier.copyWithError('No file to install.');
      return;
    }

    // Verify the file exists
    final file = File(path);
    if (!await file.exists()) {
      notifier.addLog('Error: File not found at $path', isError: true);
      notifier.copyWithError('File not found: $path');
      return;
    }

    final fileSize = await file.length();
    final method = InstallMethod.fromFilePath(path);

    notifier.addLog('─' * 50);
    notifier.addLog('Installing ${widget.owner}/${widget.repo}');
    notifier.addLog('File: ${path.split('/').last}');
    notifier.addLog('Size: ${_formatBytes(fileSize)}');
    notifier.addLog('Method: ${method.label}');
    notifier.addLog('─' * 50);

    try {
      await notifier.install(path, packageName: widget.repo);
    } catch (e) {
      if (!_disposed && mounted) {
        notifier.addLog('Installation error: $e', isError: true);
      }
    }
  }

  /// Start downloading the file (when filePath is not provided).
  Future<void> _startDownload(String downloadUrl) async {
    final notifier = ref.read(installerNotifierProvider.notifier);

    notifier.addLog('─' * 50);
    notifier.addLog('Downloading asset for ${widget.owner}/${widget.repo}...');
    notifier.addLog('URL: $downloadUrl');
    notifier.addLog('─' * 50);

    // Determine save path
    final homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final downloadsDir = '$homeDir/Downloads/GitHubStore';
    final dir = Directory(downloadsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final fileName = widget.assetName ?? downloadUrl.split('/').last;
    final savePath = '$downloadsDir/${widget.owner}/${widget.repo}/$fileName';
    final saveDir = File(savePath).parent;
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    _downloadCancelToken = CancelToken();
    int lastBytes = 0;
    DateTime lastSpeedCheck = DateTime.now();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 0),
        headers: {
          'Accept': 'application/octet-stream',
          'User-Agent': 'GitHubStore-Desktop/1.0',
        },
      ));

      await dio.download(
        downloadUrl,
        savePath,
        cancelToken: _downloadCancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedCheck).inMilliseconds;

          int speed = 0;
          if (elapsed >= 500) {
            speed = ((received - lastBytes) * 1000) ~/ elapsed;
            lastBytes = received;
            lastSpeedCheck = now;
          }

          final progress = total > 0 ? received / total : 0.0;
          final remaining = speed > 0 ? ((total - received) ~/ speed) : 0;

          if (!_disposed) {
            notifier.updateDownloadProgress(
              progress: progress,
              speed: speed,
              eta: remaining > 0 ? '${remaining ~/ 60}m ${remaining % 60}s' : '',
              downloaded: received,
              total: total,
            );
          }
        },
      );

      if (!_disposed) {
        _resolvedFilePath = savePath;
        notifier.addLog('');
        notifier.addLog('✓ Download complete: $savePath');
        notifier.addLog('');
        notifier.setInstalling();
        _startInstallation();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        notifier.addLog('Download cancelled.', isError: true);
      } else {
        notifier.addLog('Download failed: ${e.message}', isError: true);
      }
      notifier.copyWithError('Download failed: ${e.message}');
    } catch (e) {
      notifier.addLog('Download error: $e', isError: true);
      notifier.copyWithError('Download error: $e');
    }
  }

  /// Cancel the current operation.
  void _cancel() {
    _downloadCancelToken?.cancel('User cancelled');
    ref.read(installerNotifierProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context) {
    _watchLog();

    final theme = Theme.of(context);
    final installState = ref.watch(installerNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Install ${widget.repo}'),
        actions: [
          if (installState.canCancel)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Cancel',
              onPressed: _cancel,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Status Bar ─────────────────────────────────────────────
          _buildStatusBar(theme, installState),

          // ── Download Progress Section ─────────────────────────────
          if (installState.installState == InstallState.downloading)
            _buildDownloadProgress(theme, installState),

          // ── Log Console ───────────────────────────────────────────
          Expanded(
            child: Container(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF0D1117)
                  : const Color(0xFFF6F8FA),
              margin: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: installState.logLines.isEmpty
                    ? _buildLogPlaceholder(theme, installState)
                    : ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: installState.logLines.length,
                        itemBuilder: (context, index) {
                          return _buildLogLine(
                            theme,
                            installState.logLines[index],
                          );
                        },
                      ),
              ),
            ),
          ),

          // ── Bottom Actions ────────────────────────────────────────
          _buildBottomActions(theme, installState),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, InstallerState state) {
    final isFailed = state.installState == InstallState.failed;
    final isSuccess = state.installState == InstallState.success;
    final isCancelled = state.installState == InstallState.cancelled;
    final isInstalling = state.installState == InstallState.installing;
    final isDownloading = state.installState == InstallState.downloading;

    final bgColor = isFailed
        ? theme.colorScheme.errorContainer
        : isSuccess
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceVariant;
    final fgColor = isFailed
        ? theme.colorScheme.error
        : isSuccess
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface;
    final icon = isFailed
        ? Icons.error
        : isSuccess
            ? Icons.check_circle
            : isCancelled
                ? Icons.remove_circle
                : isInstalling
                    ? Icons.build
                    : Icons.downloading;
    final label = isFailed
        ? 'Installation Failed'
        : isSuccess
            ? 'Installation Complete'
            : isCancelled
                ? 'Cancelled'
                : isInstalling
                    ? 'Installing...'
                    : isDownloading
                        ? 'Downloading...'
                        : 'Preparing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, color: fgColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (isInstalling || isDownloading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isSuccess && state.exitCode != null)
            Text(
              'Exit code: ${state.exitCode}',
              style: theme.textTheme.labelSmall?.copyWith(color: fgColor),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(ThemeData theme, InstallerState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Download Progress',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                state.downloadProgressPercent,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.downloadProgress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatBytes(state.downloadedBytes)} / ${_formatBytes(state.totalBytes)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${formatSpeed(state.downloadSpeed)}${state.downloadEta.isNotEmpty ? ' · ${state.downloadEta}' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogPlaceholder(ThemeData theme, InstallerState state) {
    final isInstalling = state.installState == InstallState.installing;
    final isDownloading = state.installState == InstallState.downloading;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isInstalling || isDownloading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 12),
          Text(
            isInstalling
                ? 'Running installation commands...'
                : isDownloading
                    ? 'Waiting for log output...'
                    : 'Ready to install.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogLine(ThemeData theme, String line) {
    final isError = line.contains('❌') ||
        line.contains('[ERROR]') ||
        line.contains('Error:') ||
        line.contains('Failed');
    final isSuccess = line.contains('✓') ||
        line.contains('[OK]') ||
        line.contains('complete');
    final isHeader = line.startsWith('─');
    final isInfo = line.contains('[INFO]') || line.contains('Running:');

    Color textColor;
    if (isError) {
      textColor = theme.colorScheme.error;
    } else if (isSuccess) {
      textColor = theme.colorScheme.tertiary;
    } else if (isHeader) {
      textColor = theme.colorScheme.outline.withOpacity(0.6);
    } else if (isInfo) {
      textColor = theme.colorScheme.primary;
    } else {
      textColor = theme.brightness == Brightness.dark
          ? const Color(0xFFC9D1D9)
          : const Color(0xFF1F2328);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.6,
          color: textColor,
          fontWeight: isError || isHeader ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme, InstallerState state) {
    final isSuccess = state.installState == InstallState.success;
    final isFailed = state.installState == InstallState.failed;
    final isCancelled = state.installState == InstallState.cancelled;
    final filePath = state.filePath ?? _resolvedFilePath;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Success actions
          if (isSuccess) ...[
            if (filePath != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFileLocation(filePath),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Open Location'),
                ),
              ),
            const SizedBox(width: 12),
          ],

          // Failed / Cancelled — retry
          if (isFailed || isCancelled) ...[
            if (filePath != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(installerNotifierProvider.notifier).reset();
                    _startInstallation();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            const SizedBox(width: 12),
          ],

          // Cancel button during active operations
          if (state.canCancel) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Close button
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isSuccess ? 'Close' : 'Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFileLocation(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        final dir = File(filePath).parent;
        await Process.run('open', [dir.path]);
      } else {
        final dir = File(filePath).parent;
        await Process.run('xdg-open', [dir.path]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file location: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Extension on InstallerNotifier for convenience.
extension InstallerNotifierExt on InstallerNotifier {
  void copyWithError(String error) {
    state = state.copyWith(
      installState: InstallState.failed,
      error: error,
    );
  }
}
