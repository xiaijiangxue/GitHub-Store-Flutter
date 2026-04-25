import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/download_task_model.dart';
import '../../../core/models/release_asset_model.dart';

/// Singleton download manager that handles concurrent file downloads
/// with progress tracking, queue management, and error handling.
class DownloadManager {
  DownloadManager._();

  static final DownloadManager _instance = DownloadManager._();
  static DownloadManager get instance => _instance;

  // ── State ──────────────────────────────────────────────────────────────

  /// Active and queued download tasks, keyed by `"$owner/$name/$assetName"`.
  final Map<String, DownloadTaskModel> _tasks = {};

  /// Maximum number of concurrent downloads.
  int _maxConcurrent = 3;

  /// Broadcast stream controller for emitting state changes to the UI.
  final StreamController<DownloadTaskModel> _streamController =
      StreamController<DownloadTaskModel>.broadcast();

  /// Queue of task keys waiting to start.
  final List<String> _queue = [];

  /// The Dio instance used for downloads (separate from the API client to
  /// avoid interceptors that would interfere with large file downloads).
  Dio? _dio;

  /// Base downloads directory: `~/Downloads/GitHubStore/`.
  String? _baseDownloadsDir;

  /// Counter for generating unique task IDs.
  int _nextId = 1;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Stream of download state changes. UI widgets subscribe to this to
  /// receive real-time progress updates.
  Stream<DownloadTaskModel> get downloadStream => _streamController.stream;

  /// List of currently active (downloading) tasks.
  List<DownloadTaskModel> get activeDownloads => _tasks.values
      .where((t) => t.status == DownloadStatus.downloading)
      .toList();

  /// List of tasks that have completed (successfully or failed).
  List<DownloadTaskModel> get completedDownloads => _tasks.values
      .where((t) => t.status.isTerminal)
      .toList();

  /// List of tasks waiting in the queue.
  List<DownloadTaskModel> get queuedDownloads => _tasks.values
      .where((t) => t.status == DownloadStatus.queued)
      .toList();

  /// Total number of active (downloading) tasks.
  int get totalActive => activeDownloads.length;

  /// Set the maximum concurrent downloads.
  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 10);
  }

  /// Get the Dio client, lazily initialized.
  Dio get _client {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 0), // No timeout for large files
      sendTimeout: const Duration(seconds: 30),
      maxRedirects: 5,
      headers: {
        'Accept': 'application/octet-stream',
        'User-Agent': 'GitHubStore-Desktop/1.0',
      },
    ));
    return _dio!;
  }

  // ── Enqueue / Start ───────────────────────────────────────────────────

  /// Enqueue a download task and return the task key.
  ///
  /// The download will start immediately if there's room, otherwise it
  /// enters the queue and starts when an active slot opens.
  ///
  /// Returns the file path where the file will be saved (once complete).
  Future<String> enqueue({
    required ReleaseAssetModel asset,
    required String repoOwner,
    required String repoName,
    String? version,
  }) async {
    final key = '$repoOwner/$repoName/${asset.name}';

    // If this exact download is already queued/active, return existing
    if (_tasks.containsKey(key)) {
      final existing = _tasks[key]!;
      if (!existing.status.isTerminal) return existing.filePath ?? '';
    }

    // Determine save path
    final saveDir = await _ensureDownloadDir(repoOwner, repoName, version);
    final filePath = '$saveDir/${asset.name}';

    final task = DownloadTaskModel(
      id: _nextId++,
      asset: asset,
      repoOwner: repoOwner,
      repoName: repoName,
      version: version,
      filePath: filePath,
      totalBytes: asset.size,
      downloadedBytes: 0,
      status: DownloadStatus.queued,
      progress: 0.0,
      startedAt: DateTime.now(),
      downloadSpeed: 0,
      cancelToken: CancelToken(),
    );

    _tasks[key] = task;
    _queue.add(key);

    debugPrint('[DownloadManager] Enqueued: $key');

    // Emit initial state
    _streamController.add(task);

    // Try to start the download
    _processQueue();

    return filePath;
  }

  /// Retry a failed download.
  Future<String?> retry(String taskId) async {
    final entry = _tasks.entries
        .where((e) => e.key == taskId || e.value.id.toString() == taskId)
        .firstOrNull;

    if (entry == null) return null;
    final task = entry.value;
    if (!task.isFailed) return null;

    // Reset the task
    final updated = task.copyWith(
      status: DownloadStatus.queued,
      downloadedBytes: 0,
      progress: 0.0,
      downloadSpeed: 0,
      error: null,
      completedAt: null,
      startedAt: DateTime.now(),
      cancelToken: CancelToken(),
    );

    _tasks[entry.key] = updated;
    _queue.add(entry.key);
    _streamController.add(updated);
    _processQueue();

    return updated.filePath;
  }

  // ── Cancel ────────────────────────────────────────────────────────────

  /// Cancel a specific download by task key or ID.
  void cancel(String taskId) {
    final entry = _tasks.entries
        .where((e) => e.key == taskId || e.value.id.toString() == taskId)
        .firstOrNull;

    if (entry == null) return;
    final task = entry.value;
    if (!task.status.canCancel) return;

    // Cancel the Dio request
    final token = task.cancelToken;
    if (token is CancelToken) {
      token.cancel('User cancelled download');
    }

    final updated = task.copyWith(
      status: DownloadStatus.cancelled,
      completedAt: DateTime.now(),
    );
    _tasks[entry.key] = updated;
    _queue.remove(entry.key);

    _streamController.add(updated);
    debugPrint('[DownloadManager] Cancelled: ${entry.key}');

    // Process queue to fill the slot
    _processQueue();
  }

  /// Cancel all active and queued downloads.
  void cancelAll() {
    final keysToCancel = _tasks.entries
        .where((e) => e.value.status.canCancel)
        .map((e) => e.key)
        .toList();

    for (final key in keysToCancel) {
      cancel(key);
    }
  }

  /// Remove a completed/failed/cancelled task from tracking.
  void removeTask(String taskId) {
    final entry = _tasks.entries
        .where((e) => e.key == taskId || e.value.id.toString() == taskId)
        .firstOrNull;

    if (entry == null) return;
    final task = entry.value;
    if (!task.status.isTerminal) return;

    _tasks.remove(entry.key);
    _queue.remove(entry.key);
  }

  // ── Clear History ─────────────────────────────────────────────────────

  /// Remove all completed/failed/cancelled tasks.
  void clearCompleted() {
    final toRemove = _tasks.entries
        .where((e) => e.value.status.isTerminal)
        .map((e) => e.key)
        .toList();
    for (final key in toRemove) {
      _tasks.remove(key);
    }
  }

  /// Get a task by key or ID.
  DownloadTaskModel? getTask(String taskId) {
    return _tasks.entries
        .where((e) => e.key == taskId || e.value.id.toString() == taskId)
        .map((e) => e.value)
        .firstOrNull;
  }

  /// Get the base downloads directory.
  Future<String> getBaseDownloadsDir() async {
    _baseDownloadsDir ??= await _resolveBaseDownloadsDir();
    return _baseDownloadsDir!;
  }

  // ── Queue Processing ──────────────────────────────────────────────────

  /// Start queued downloads up to the maximum concurrent limit.
  void _processQueue() {
    while (_queue.isNotEmpty && totalActive < _maxConcurrent) {
      final nextKey = _queue.removeAt(0);
      final task = _tasks[nextKey];
      if (task == null || task.status != DownloadStatus.queued) continue;

      // Update status to downloading
      final updated = task.copyWith(status: DownloadStatus.downloading);
      _tasks[nextKey] = updated;
      _streamController.add(updated);

      // Start the download (fire and forget — errors handled internally)
      _downloadFile(nextKey, updated);
    }
  }

  // ── Download Implementation ───────────────────────────────────────────

  /// Download a file with progress tracking.
  Future<void> _downloadFile(String key, DownloadTaskModel task) async {
    final downloadUrl = task.asset.downloadUrl;
    final filePath = task.filePath;

    if (downloadUrl == null || downloadUrl.isEmpty || filePath == null) {
      _failTask(key, 'Missing download URL or file path.');
      return;
    }

    if (task.cancelToken is! CancelToken) {
      _failTask(key, 'Invalid cancel token.');
      return;
    }

    final cancelToken = task.cancelToken as CancelToken;

    // Ensure parent directory exists
    final dir = File(filePath).parent;
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      _failTask(key, 'Failed to create directory: $e');
      return;
    }

    // Track speed calculation
    int lastBytes = 0;
    DateTime lastSpeedCheck = DateTime.now();
    int currentSpeed = 0;

    try {
      await _client.download(
        downloadUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedCheck).inMilliseconds;

          // Calculate speed every 500ms
          if (elapsed >= 500) {
            currentSpeed = ((received - lastBytes) * 1000) ~/ elapsed;
            lastBytes = received;
            lastSpeedCheck = now;
          }

          final progress = total > 0 ? received / total : 0.0;

          final updated = task.copyWith(
            downloadedBytes: received,
            totalBytes: total,
            progress: progress,
            downloadSpeed: currentSpeed,
          );

          _tasks[key] = updated;
          _streamController.add(updated);
        },
        options: Options(
          receiveDataWhenStatusError: true,
          followRedirects: true,
          maxRedirects: 10,
        ),
      );

      // Download completed successfully
      final finalTask = _tasks[key];
      if (finalTask != null && finalTask.status != DownloadStatus.cancelled) {
        final completed = finalTask.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          downloadedBytes: finalTask.totalBytes,
          downloadSpeed: 0,
          completedAt: DateTime.now(),
        );
        _tasks[key] = completed;
        _streamController.add(completed);
        debugPrint('[DownloadManager] Completed: $key → $filePath');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Already handled in cancel()
        final existing = _tasks[key];
        if (existing != null && existing.status != DownloadStatus.cancelled) {
          _failTask(key, 'Download cancelled.');
        }
      } else {
        final message = _mapDioError(e);
        _failTask(key, message);
      }
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28 || e.message.contains('No space left')) {
        _failTask(key, 'Disk full. Free up space and retry.');
      } else if (e.message.contains('Permission denied')) {
        _failTask(key, 'Permission denied. Check file write permissions.');
      } else {
        _failTask(key, 'File system error: ${e.message}');
      }
    } catch (e) {
      _failTask(key, 'Unexpected error: $e');
    } finally {
      // Clean up partial file on failure
      final finalTask = _tasks[key];
      if (finalTask != null && finalTask.status == DownloadStatus.failed) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }

      // Process queue to fill the slot
      _processQueue();
    }
  }

  /// Mark a task as failed and emit the update.
  void _failTask(String key, String error) {
    final task = _tasks[key];
    if (task == null) return;

    final updated = task.copyWith(
      status: DownloadStatus.failed,
      error: error,
      downloadSpeed: 0,
      completedAt: DateTime.now(),
    );
    _tasks[key] = updated;
    _streamController.add(updated);
    debugPrint('[DownloadManager] Failed: $key — $error');
  }

  /// Map a DioException to a user-friendly error message.
  String _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout =>
        'Connection timeout. Check your internet connection.',
      DioExceptionType.sendTimeout =>
        'Send timeout. The server is not responding.',
      DioExceptionType.receiveTimeout =>
        'Receive timeout. The download took too long.',
      DioExceptionType.badResponse => _parseErrorResponse(e),
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      DioExceptionType.badCertificate =>
        'SSL certificate error. The download source may be compromised.',
      DioExceptionType.cancel => 'Download was cancelled.',
      DioExceptionType.unknown =>
        'Download failed: ${e.message ?? "Unknown error"}',
    };
  }

  /// Parse a bad response error into a meaningful message.
  String _parseErrorResponse(DioException e) {
    final statusCode = e.response?.statusCode;
    return switch (statusCode) {
      401 => 'Authentication required. Add a GitHub token in settings.',
      403 => 'Access denied. The repository may be private.',
      404 => 'File not found. The asset may have been removed.',
      429 => 'Rate limited by GitHub. Wait a moment and retry.',
      _ when statusCode != null && statusCode! >= 500 =>
        'Server error ($statusCode). GitHub may be experiencing issues.',
      _ => 'Download failed with status ${statusCode ?? "unknown"}.',
    };
  }

  // ── Directory Management ──────────────────────────────────────────────

  /// Resolve the base downloads directory for the current platform.
  Future<String> _resolveBaseDownloadsDir() async {
    String? downloadsDir;

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        downloadsDir = '$userProfile\\Downloads\\GitHubStore';
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        downloadsDir = '$home/Downloads/GitHubStore';
      }
    } else if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DOWNLOAD_DIR'];
      if (xdg != null) {
        final home = Platform.environment['HOME'] ?? '';
        downloadsDir = '${xdg.replaceAll('~', home)}/GitHubStore';
      } else {
        final home = Platform.environment['HOME'];
        if (home != null) {
          downloadsDir = '$home/Downloads/GitHubStore';
        }
      }
    }

    downloadsDir ??= '${Directory.systemTemp.path}/GitHubStore';

    final dir = Directory(downloadsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return downloadsDir;
  }

  /// Ensure the specific download subdirectory exists.
  ///
  /// Structure: `GitHubStore/{owner}/{name}/v{version}/`
  Future<String> _ensureDownloadDir(
    String owner,
    String name,
    String? version,
  ) async {
    final base = await getBaseDownloadsDir();
    final versionDir = version != null ? 'v$version' : 'latest';
    final dirPath = '$base/$owner/$name/$versionDir';

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dirPath;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  /// Calculate total size of all downloaded files.
  Future<int> getCacheSize() async {
    final base = await getBaseDownloadsDir();
    return await _calculateDirSize(Directory(base));
  }

  /// Recursively calculate the size of a directory.
  Future<int> _calculateDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return totalSize;
  }

  /// Delete all downloaded files.
  Future<void> clearDownloadCache() async {
    final base = await getBaseDownloadsDir();
    final dir = Directory(base);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        debugPrint('[DownloadManager] Failed to clear cache: $e');
      }
    }
    _tasks.clear();
    _queue.clear();
  }

  /// Dispose resources.
  void dispose() {
    cancelAll();
    _dio?.close();
    _streamController.close();
    _instance; // Keep singleton alive but clear state
  }
}
