import 'dart:convert';

import 'release_asset_model.dart';

/// Status of an active download task.
enum DownloadStatus {
  /// Waiting in the download queue.
  queued,

  /// Currently downloading.
  downloading,

  /// Download finished successfully.
  completed,

  /// Download failed due to an error.
  failed,

  /// Download was cancelled by the user.
  cancelled,

  /// Post-download installation in progress.
  installing;

  static DownloadStatus fromString(String value) {
    return DownloadStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => DownloadStatus.queued,
    );
  }

  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.cancelled;

  bool get isActive =>
      this == DownloadStatus.queued || this == DownloadStatus.downloading;

  bool get canCancel =>
      this == DownloadStatus.queued || this == DownloadStatus.downloading;

  bool get canRetry => this == DownloadStatus.failed;
}

/// Represents an active download/install task.
class DownloadTaskModel {
  DownloadTaskModel({
    required this.id,
    required this.asset,
    required this.repoOwner,
    required this.repoName,
    this.version,
    this.filePath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.error,
    this.startedAt,
    this.completedAt,
    this.downloadSpeed = 0,
    this.cancelToken,
  });

  /// Local database ID (auto-increment).
  final int id;

  /// The release asset being downloaded.
  final ReleaseAssetModel asset;

  /// Repository owner login.
  final String repoOwner;

  /// Repository name.
  final String repoName;

  /// Release version/tag.
  final String? version;

  /// Local file path where the download is/will be saved.
  final String? filePath;

  /// Total file size in bytes.
  final int totalBytes;

  /// Number of bytes downloaded so far.
  final int downloadedBytes;

  /// Current download status.
  final DownloadStatus status;

  /// Download progress as a fraction from 0.0 to 1.0.
  final double progress;

  /// Error message if the download failed.
  final String? error;

  /// When the download started.
  final DateTime? startedAt;

  /// When the download completed or failed.
  final DateTime? completedAt;

  /// Current download speed in bytes/second.
  final int downloadSpeed;

  /// Optional cancel token for aborting the download.
  final dynamic cancelToken;

  /// Repository full name (owner/name).
  String get repoFullName => '$repoOwner/$repoName';

  /// Whether the download has started.
  bool get hasStarted => startedAt != null;

  /// Whether the download is complete.
  bool get isComplete => status == DownloadStatus.completed;

  /// Whether the download has failed.
  bool get isFailed => status == DownloadStatus.failed;

  /// Formatted download progress percentage.
  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  /// Remaining bytes to download.
  int get remainingBytes => totalBytes - downloadedBytes;

  /// Estimated time remaining in seconds, or null if indeterminate.
  int? get estimatedSecondsRemaining {
    if (downloadSpeed <= 0 || remainingBytes <= 0) return null;
    return (remainingBytes / downloadSpeed).ceil();
  }

  /// Formatted remaining time string.
  String get formattedRemaining {
    final seconds = estimatedSecondsRemaining;
    if (seconds == null) return '';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  /// Formatted download speed string.
  String get formattedSpeed {
    if (downloadSpeed < 1024) return '$downloadSpeed B/s';
    if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Formatted file size strings.
  String get formattedDownloaded {
    if (downloadedBytes < 1024) return '$downloadedBytes B';
    if (downloadedBytes < 1024 * 1024) {
      return '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedTotal {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DownloadTaskModel copyWith({
    int? id,
    ReleaseAssetModel? asset,
    String? repoOwner,
    String? repoName,
    String? version,
    String? filePath,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    double? progress,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
    int? downloadSpeed,
    dynamic cancelToken,
  }) {
    return DownloadTaskModel(
      id: id ?? this.id,
      asset: asset ?? this.asset,
      repoOwner: repoOwner ?? this.repoOwner,
      repoName: repoName ?? this.repoName,
      version: version ?? this.version,
      filePath: filePath ?? this.filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }

  factory DownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskModel(
      id: json['id'] as int,
      asset: json['asset'] != null
          ? ReleaseAssetModel.fromJson(json['asset'] as Map<String, dynamic>)
          : ReleaseAssetModel(
              id: 0,
              name: json['asset_name'] as String? ?? '',
            ),
      repoOwner: json['repo_owner'] as String? ?? '',
      repoName: json['repo_name'] as String? ?? '',
      version: json['version'] as String?,
      filePath: json['file_path'] as String?,
      totalBytes: json['total_bytes'] as int? ?? 0,
      downloadedBytes: json['downloaded_bytes'] as int? ?? 0,
      status: DownloadStatus.fromString(json['status'] as String? ?? 'queued'),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      downloadSpeed: json['download_speed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'asset': asset.toJson(),
      'repo_owner': repoOwner,
      'repo_name': repoName,
      if (version != null) 'version': version,
      if (filePath != null) 'file_path': filePath,
      'total_bytes': totalBytes,
      'downloaded_bytes': downloadedBytes,
      'status': status.name,
      'progress': progress,
      if (error != null) 'error': error,
      if (startedAt != null)
        'started_at': startedAt!.toUtc().toIso8601String(),
      if (completedAt != null)
        'completed_at': completedAt!.toUtc().toIso8601String(),
      'download_speed': downloadSpeed,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory DownloadTaskModel.fromJsonString(String source) =>
      DownloadTaskModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DownloadTaskModel(id: $id, repo: $repoFullName, '
      'asset: ${asset.name}, status: ${status.name}, progress: $formattedProgress)';
}
