import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/download_task_model.dart';
import '../../../core/models/release_asset_model.dart';
import '../data/download_repository.dart';
import 'providers/download_provider.dart';

/// Downloads manager screen showing active downloads and download history.
///
/// When navigated to with [owner], [repo], [tag], and [assetName],
/// it will automatically start the download and then show the manager.
class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({
    this.owner,
    this.repo,
    this.tag,
    this.assetName,
    this.downloadUrl,
    this.assetId,
    this.fileSize,
    super.key,
  });

  /// Repository owner (optional — auto-starts download if provided).
  final String? owner;

  /// Repository name (optional — auto-starts download if provided).
  final String? repo;

  /// Release tag/version (optional).
  final String? tag;

  /// Asset file name (optional).
  final String? assetName;

  /// Direct download URL for the asset.
  final String? downloadUrl;

  /// GitHub asset ID.
  final int? assetId;

  /// File size in bytes.
  final int? fileSize;

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  StreamSubscription<DownloadTaskModel>? _downloadSubscription;
  final List<DownloadTaskModel> _activeTasks = [];
  final List<DownloadTaskModel> _completedTasks = [];
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    _listenToDownloads();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _listenToDownloads() {
    final repo = ref.read(downloadRepositoryProvider);
    _downloadSubscription = repo.downloadStream.listen((task) {
      if (!mounted) return;
      setState(() {
        _activeTasks.removeWhere(
            (t) => t.id == task.id || _taskKey(t) == _taskKey(task));
        _completedTasks.removeWhere(
            (t) => t.id == task.id || _taskKey(t) == _taskKey(task));

        if (task.status.isActive) {
          _activeTasks.add(task);
        } else if (task.status.isTerminal) {
          _completedTasks.add(task);
        }
      });
    });

    // Load initial state
    setState(() {
      _activeTasks.clear();
      _activeTasks.addAll(repo.getActiveDownloads());
      _activeTasks.addAll(repo.getQueuedDownloads());
      _completedTasks.clear();
      _completedTasks.addAll(repo.getDownloadHistory());
    });

    // Auto-start download if params are provided
    if (!_autoStarted &&
        widget.owner != null &&
        widget.repo != null &&
        widget.assetName != null) {
      _autoStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoDownload();
      });
    }
  }

  Future<void> _startAutoDownload() async {
    final repo = ref.read(downloadRepositoryProvider);
    try {
      final asset = ReleaseAssetModel(
        id: widget.assetId ?? 0,
        name: widget.assetName!,
        downloadUrl: widget.downloadUrl,
        size: widget.fileSize ?? 0,
      );
      await repo.startDownload(
        asset: asset,
        owner: widget.owner!,
        name: widget.repo!,
        version: widget.tag,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start download: $e')),
        );
      }
    }
  }

  String _taskKey(DownloadTaskModel task) =>
      '${task.repoOwner}/${task.repoName}/${task.asset.name}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActive = _activeTasks.isNotEmpty;
    final hasCompleted = _completedTasks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.owner != null
              ? '${widget.owner}/${widget.repo}'
              : 'Downloads',
        ),
        actions: [
          if (hasActive || hasCompleted)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                final repo = ref.read(downloadRepositoryProvider);
                if (value == 'cancel_all') {
                  repo.cancelAllDownloads();
                } else if (value == 'clear_completed') {
                  repo.clearHistory();
                  setState(() => _completedTasks.clear());
                }
              },
              itemBuilder: (context) => [
                if (hasActive)
                  const PopupMenuItem(
                    value: 'cancel_all',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, size: 18),
                        SizedBox(width: 8),
                        Text('Cancel All Active'),
                      ],
                    ),
                  ),
                if (hasCompleted)
                  const PopupMenuItem(
                    value: 'clear_completed',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, size: 18),
                        SizedBox(width: 8),
                        Text('Clear Completed'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _activeTasks.isEmpty && _completedTasks.isEmpty
          ? _buildEmptyState(theme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hasActive) ...[
                  _buildSectionHeader(
                    theme,
                    title: 'Active Downloads',
                    count: _activeTasks.length,
                    icon: Icons.downloading,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  ..._activeTasks
                      .map((task) => _buildActiveTaskCard(theme, task)),
                  const SizedBox(height: 24),
                ],
                if (hasCompleted) ...[
                  _buildSectionHeader(
                    theme,
                    title: 'Download History',
                    count: _completedTasks.length,
                    icon: Icons.history,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  ..._completedTasks
                      .map((task) => _buildCompletedTaskCard(theme, task)),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 80,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloads',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloads you start from release pages\nwill appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTaskCard(ThemeData theme, DownloadTaskModel task) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isQueued = task.status == DownloadStatus.queued;
    final progressColor = isDownloading
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final statusColor = isDownloading
        ? theme.colorScheme.primary
        : isQueued
            ? theme.colorScheme.tertiary
            : task.status == DownloadStatus.failed
                ? theme.colorScheme.error
                : task.status == DownloadStatus.cancelled
                    ? theme.colorScheme.outline
                    : theme.colorScheme.tertiary;

    final statusLabel = switch (task.status) {
      DownloadStatus.queued => 'Queued',
      DownloadStatus.downloading => 'Downloading',
      DownloadStatus.completed => 'Completed',
      DownloadStatus.failed => 'Failed',
      DownloadStatus.cancelled => 'Cancelled',
      DownloadStatus.installing => 'Installing',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPlatformIcon(task.asset.name),
                    size: 20,
                    color: progressColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.repoFullName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.asset.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDownloading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: statusColor,
                          ),
                        )
                      else
                        Icon(
                          _getStatusIcon(task.status),
                          size: 12,
                          color: statusColor,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Progress Bar ───────────────────────────────────────
            if (task.totalBytes > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      task.formattedProgress,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (isDownloading) ...[
                    Icon(Icons.speed,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      task.formattedSpeed,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule,
                        size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      task.formattedRemaining,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    '${task.formattedDownloaded} / ${task.formattedTotal}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (task.status.canCancel)
                    InkWell(
                      onTap: () {
                        ref
                            .read(downloadRepositoryProvider)
                            .cancelDownload(_taskKey(task));
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 18, color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Text(
                isQueued ? 'Waiting to start...' : statusLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],

            // ── Error Message ──────────────────────────────────────
            if (task.error != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 14, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.error!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Version + Install button ───────────────────────────
            if (task.version != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'v${task.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  if (task.status == DownloadStatus.completed &&
                      task.filePath != null)
                    TextButton.icon(
                      onPressed: () => _navigateToInstaller(task),
                      icon: const Icon(Icons.build, size: 16),
                      label: const Text('Install'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        textStyle: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTaskCard(ThemeData theme, DownloadTaskModel task) {
    final isSuccess = task.status == DownloadStatus.completed;
    final isFailed = task.status == DownloadStatus.failed;
    final statusColor = isSuccess
        ? theme.colorScheme.tertiary
        : isFailed
            ? theme.colorScheme.error
            : theme.colorScheme.outline;
    final statusIcon = isSuccess
        ? Icons.check_circle
        : isFailed
            ? Icons.error
            : Icons.remove_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(statusIcon, color: statusColor, size: 28),
        title: Text(
          task.asset.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              task.repoFullName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (task.version != null) ...[
              Text(
                ' · v${task.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const Spacer(),
            Text(
              task.formattedTotal,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSuccess && task.filePath != null)
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: 'Open file location',
                onPressed: () => _openFileLocation(task.filePath!),
              ),
            if (isSuccess && task.filePath != null)
              IconButton(
                icon: const Icon(Icons.build, size: 20),
                tooltip: 'Install',
                onPressed: () => _navigateToInstaller(task),
              ),
            if (isFailed)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Retry download',
                onPressed: () {
                  ref
                      .read(downloadRepositoryProvider)
                      .retryDownload(_taskKey(task));
                },
              ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: () {
                ref
                    .read(downloadRepositoryProvider)
                    .removeTask(_taskKey(task));
                setState(() {
                  _completedTasks.removeWhere((t) =>
                      t.id == task.id || _taskKey(t) == _taskKey(task));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openFileLocation(String filePath) async {
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
    } catch (_) {}
  }

  void _navigateToInstaller(DownloadTaskModel task) {
    final uri = Uri(
      path: '/installer/${task.repoOwner}/${task.repoName}',
      queryParameters: {
        if (task.filePath != null) 'filePath': task.filePath,
        'assetName': task.asset.name,
      },
    );
    context.push(uri.toString());
  }

  IconData _getPlatformIcon(String assetName) {
    final lower = assetName.toLowerCase();
    if (lower.contains('.exe') ||
        lower.contains('.msi') ||
        lower.contains('.msix')) {
      return Icons.window;
    }
    if (lower.contains('.dmg') || lower.contains('.pkg')) {
      return Icons.apple;
    }
    if (lower.contains('.deb') ||
        lower.contains('.rpm') ||
        lower.contains('.appimage') ||
        lower.contains('.flatpak') ||
        lower.contains('.snap') ||
        lower.contains('linux')) {
      return Icons.terminal;
    }
    if (lower.contains('.zip') ||
        lower.contains('.tar') ||
        lower.contains('.gz')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }

  IconData _getStatusIcon(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.queued => Icons.schedule,
      DownloadStatus.downloading => Icons.downloading,
      DownloadStatus.completed => Icons.check_circle,
      DownloadStatus.failed => Icons.error,
      DownloadStatus.cancelled => Icons.remove_circle,
      DownloadStatus.installing => Icons.build,
    };
  }
}
