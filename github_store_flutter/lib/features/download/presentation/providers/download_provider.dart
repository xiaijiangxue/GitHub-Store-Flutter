import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/download_task_model.dart';
import '../../data/download_manager.dart';
import '../../data/download_repository.dart';

/// Provider for the [DownloadManager] singleton.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager.instance;
});

/// Provider for the [DownloadRepository].
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository();
});

/// Stream provider that listens to the download manager's broadcast stream
/// and exposes the current list of all active/queued/completed tasks.
///
/// UI widgets can watch this provider to receive real-time updates.
final activeDownloadsProvider = StreamProvider<List<DownloadTaskModel>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);

  // Create a stream that emits the full list of tasks whenever any task changes.
  final controller = StreamController<List<DownloadTaskModel>>();

  // Debounce: emit the current snapshot on each download event
  StreamSubscription<DownloadTaskModel>? subscription;
  Timer? debounce;

  subscription = repo.downloadStream.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 100), () {
      // Collect all non-terminal tasks (active + queued)
      final active = repo.getActiveDownloads();
      final queued = repo.getQueuedDownloads();
      controller.add([...active, ...queued]);
    });
  });

  // Emit initial state
  final active = repo.getActiveDownloads();
  final queued = repo.getQueuedDownloads();
  controller.add([...active, ...queued]);

  ref.onDispose(() {
    subscription?.cancel();
    debounce?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider for download history (completed/failed/cancelled tasks).
final downloadHistoryProvider = StateProvider<List<DownloadTaskModel>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.getDownloadHistory();
});

/// Future provider that computes the total cache size as a formatted string.
final cacheSizeProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(downloadRepositoryProvider);
  return repo.getCacheSizeFormatted();
});

/// State notifier for managing download-related UI state.
class DownloadNotifier extends StateNotifier<AsyncValue<void>> {
  DownloadNotifier(this._repo) : super(const AsyncValue.data(null));

  final DownloadRepository _repo;

  /// Start a new download.
  Future<String> startDownload({
    required String downloadUrl,
    required String assetName,
    required String owner,
    required String name,
    required int assetId,
    int fileSize = 0,
    String? version,
  }) async {
    state = const AsyncValue.loading();
    try {
      final path = await _repo.startDownload(
        asset: _createAsset(downloadUrl, assetName, assetId, fileSize),
        owner: owner,
        name: name,
        version: version,
      );
      state = const AsyncValue.data(null);
      return path;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Cancel a specific download.
  void cancel(String taskId) {
    _repo.cancelDownload(taskId);
    _refreshHistory();
  }

  /// Cancel all downloads.
  void cancelAll() {
    _repo.cancelAllDownloads();
    _refreshHistory();
  }

  /// Retry a failed download.
  void retry(String taskId) {
    _repo.retryDownload(taskId);
  }

  /// Clear download history.
  void clearHistory() {
    _repo.clearHistory();
    _refreshHistory();
  }

  /// Clear all downloads and cache.
  Future<void> clearCache() async {
    await _repo.clearDownloadCache();
    _refreshHistory();
  }

  /// Remove a specific task.
  void removeTask(String taskId) {
    _repo.removeTask(taskId);
    _refreshHistory();
  }

  void _refreshHistory() {
    // History is updated via the repository; consumers watch
    // downloadHistoryProvider which pulls from the manager.
  }

  /// Helper to create a ReleaseAssetModel from parameters.
  /// Import is avoided by using the model directly from core.
  // This is handled by passing the asset directly in most cases.
}

/// Create a minimal ReleaseAssetModel for download purposes.
// Note: This uses a factory approach to avoid circular imports.
// The caller should pass the full ReleaseAssetModel when available.
