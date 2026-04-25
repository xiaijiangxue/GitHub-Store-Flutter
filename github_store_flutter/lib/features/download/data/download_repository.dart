import 'dart:io';

import '../../../core/models/download_task_model.dart';
import '../../../core/models/release_asset_model.dart';
import 'download_manager.dart';

/// Repository layer that bridges the [DownloadManager] singleton with
/// the rest of the application (providers, screens, etc.).
///
/// Provides a clean API for starting downloads, managing the queue,
/// and querying download history.
class DownloadRepository {
  DownloadRepository() : _manager = DownloadManager.instance;

  final DownloadManager _manager;

  /// Reference to the underlying [DownloadManager].
  DownloadManager get manager => _manager;

  /// Start downloading a release asset.
  ///
  /// [asset] — the release asset to download.
  /// [owner] — repository owner login.
  /// [name] — repository name.
  /// [version] — release tag/version (used for directory naming).
  ///
  /// Returns the local file path where the file will be saved.
  Future<String> startDownload({
    required ReleaseAssetModel asset,
    required String owner,
    required String name,
    String? version,
  }) {
    return _manager.enqueue(
      asset: asset,
      repoOwner: owner,
      repoName: name,
      version: version,
    );
  }

  /// Cancel a download by task key or ID.
  void cancelDownload(String taskId) {
    _manager.cancel(taskId);
  }

  /// Cancel all active and queued downloads.
  void cancelAllDownloads() {
    _manager.cancelAll();
  }

  /// Retry a failed download.
  Future<String?> retryDownload(String taskId) {
    return _manager.retry(taskId);
  }

  /// Remove a completed/failed task from tracking.
  void removeTask(String taskId) {
    _manager.removeTask(taskId);
  }

  /// Get a specific task by key or ID.
  DownloadTaskModel? getTask(String taskId) {
    return _manager.getTask(taskId);
  }

  /// Get all currently active (downloading) tasks.
  List<DownloadTaskModel> getActiveDownloads() {
    return _manager.activeDownloads;
  }

  /// Get all queued (waiting) tasks.
  List<DownloadTaskModel> getQueuedDownloads() {
    return _manager.queuedDownloads;
  }

  /// Get all completed downloads (successful, failed, or cancelled).
  List<DownloadTaskModel> getDownloadHistory() {
    return _manager.completedDownloads;
  }

  /// Get the download stream for real-time progress updates.
  Stream<DownloadTaskModel> get downloadStream => _manager.downloadStream;

  /// Clear all completed/failed/cancelled tasks from memory.
  void clearHistory() {
    _manager.clearCompleted();
  }

  /// Clear all tasks (active, queued, and completed) and delete all cached files.
  Future<void> clearDownloadCache() async {
    _manager.cancelAll();
    await _manager.clearDownloadCache();
  }

  /// Get the total size of all cached download files, formatted.
  Future<String> getCacheSizeFormatted() async {
    final bytes = await _manager.getCacheSize();
    return _formatBytes(bytes);
  }

  /// Get the total size of all cached download files in bytes.
  Future<int> getCacheSizeBytes() async {
    return _manager.getCacheSize();
  }

  /// Get the base downloads directory path.
  Future<String> getDownloadsDir() {
    return _manager.getBaseDownloadsDir();
  }

  /// Get the total number of active downloads.
  int get totalActive => _manager.totalActive;

  /// Check whether a specific asset is currently being downloaded.
  bool isDownloading(String owner, String name, String assetName) {
    final key = '$owner/$name/$assetName';
    final task = _manager.getTask(key);
    return task != null && task.status.isActive;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Format bytes to a human-readable string.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
