import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// ── Data Classes ──────────────────────────────────────────────────────────

/// A repository row from the local database.
class DbRepository {
  const DbRepository({
    required this.id,
    required this.fullName,
    required this.owner,
    required this.name,
    this.description,
    required this.htmlUrl,
    this.avatarUrl,
    this.language,
    this.languageColor,
    this.stargazersCount = 0,
    this.forksCount = 0,
    this.openIssuesCount = 0,
    this.watchersCount = 0,
    this.subscribersCount = 0,
    this.size = 0,
    this.defaultBranch = 'main',
    this.isFork = false,
    this.isArchived = false,
    this.isTemplate = false,
    this.isPrivate = false,
    this.license,
    this.licenseName,
    this.topics = '[]',
    this.latestRelease,
    this.homepage,
    this.createdAt,
    this.pushedAt,
    this.updatedAt,
    this.cachedAt,
    this.isFavorite = false,
    this.isStarred = false,
    this.sortOrder = 0.0,
  });

  final int id;
  final String fullName;
  final String owner;
  final String name;
  final String? description;
  final String htmlUrl;
  final String? avatarUrl;
  final String? language;
  final String? languageColor;
  final int stargazersCount;
  final int forksCount;
  final int openIssuesCount;
  final int watchersCount;
  final int subscribersCount;
  final int size;
  final String defaultBranch;
  final bool isFork;
  final bool isArchived;
  final bool isTemplate;
  final bool isPrivate;
  final String? license;
  final String? licenseName;
  final String topics;
  final String? latestRelease;
  final String? homepage;
  final DateTime? createdAt;
  final DateTime? pushedAt;
  final DateTime? updatedAt;
  final DateTime? cachedAt;
  final bool isFavorite;
  final bool isStarred;
  final double sortOrder;

  /// Construct from a sqlite3 [ResultSet] row.
  factory DbRepository.fromRow(Row row) {
    return DbRepository(
      id: row['id'] as int,
      fullName: row['full_name'] as String,
      owner: row['owner'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      htmlUrl: row['html_url'] as String,
      avatarUrl: row['avatar_url'] as String?,
      language: row['language'] as String?,
      languageColor: row['language_color'] as String?,
      stargazersCount: row['stargazers_count'] as int? ?? 0,
      forksCount: row['forks_count'] as int? ?? 0,
      openIssuesCount: row['open_issues_count'] as int? ?? 0,
      watchersCount: row['watchers_count'] as int? ?? 0,
      subscribersCount: row['subscribers_count'] as int? ?? 0,
      size: row['size'] as int? ?? 0,
      defaultBranch: row['default_branch'] as String? ?? 'main',
      isFork: (row['is_fork'] as int? ?? 0) == 1,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      isTemplate: (row['is_template'] as int? ?? 0) == 1,
      isPrivate: (row['is_private'] as int? ?? 0) == 1,
      license: row['license'] as String?,
      licenseName: row['license_name'] as String?,
      topics: row['topics'] as String? ?? '[]',
      latestRelease: row['latest_release'] as String?,
      homepage: row['homepage'] as String?,
      createdAt: _parseDateTime(row['created_at'] as String?),
      pushedAt: _parseDateTime(row['pushed_at'] as String?),
      updatedAt: _parseDateTime(row['updated_at'] as String?),
      cachedAt: _parseDateTime(row['cached_at'] as String?),
      isFavorite: (row['is_favorite'] as int? ?? 0) == 1,
      isStarred: (row['is_starred'] as int? ?? 0) == 1,
      sortOrder: (row['sort_order'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to a map suitable for INSERT / UPDATE.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'owner': owner,
      'name': name,
      'description': description,
      'html_url': htmlUrl,
      'avatar_url': avatarUrl,
      'language': language,
      'language_color': languageColor,
      'stargazers_count': stargazersCount,
      'forks_count': forksCount,
      'open_issues_count': openIssuesCount,
      'watchers_count': watchersCount,
      'subscribers_count': subscribersCount,
      'size': size,
      'default_branch': defaultBranch,
      'is_fork': isFork ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_template': isTemplate ? 1 : 0,
      'is_private': isPrivate ? 1 : 0,
      'license': license,
      'license_name': licenseName,
      'topics': topics,
      'latest_release': latestRelease,
      'homepage': homepage,
      'created_at': _formatDateTime(createdAt),
      'pushed_at': _formatDateTime(pushedAt),
      'updated_at': _formatDateTime(updatedAt),
      'cached_at': _formatDateTime(cachedAt ?? DateTime.now()),
      'is_favorite': isFavorite ? 1 : 0,
      'is_starred': isStarred ? 1 : 0,
      'sort_order': sortOrder,
    };
  }
}

/// A download row from the local database.
class DbDownload {
  const DbDownload({
    required this.id,
    required this.repoFullName,
    required this.releaseTag,
    required this.assetName,
    required this.downloadUrl,
    this.localFilePath,
    this.fileSize,
    this.status = 'pending',
    this.progress = 0.0,
    this.downloadSpeed = 0,
    this.errorMessage,
    this.fileHash,
    this.expectedHash,
    this.isHashVerified = false,
    this.startedAt,
    this.completedAt,
    this.contentType,
  });

  final int id;
  final String repoFullName;
  final String releaseTag;
  final String assetName;
  final String downloadUrl;
  final String? localFilePath;
  final int? fileSize;
  final String status;
  final double progress;
  final int downloadSpeed;
  final String? errorMessage;
  final String? fileHash;
  final String? expectedHash;
  final bool isHashVerified;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? contentType;

  factory DbDownload.fromRow(Row row) {
    return DbDownload(
      id: row['id'] as int,
      repoFullName: row['repo_full_name'] as String,
      releaseTag: row['release_tag'] as String,
      assetName: row['asset_name'] as String,
      downloadUrl: row['download_url'] as String,
      localFilePath: row['local_file_path'] as String?,
      fileSize: row['file_size'] as int?,
      status: row['status'] as String? ?? 'pending',
      progress: (row['progress'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: row['download_speed'] as int? ?? 0,
      errorMessage: row['error_message'] as String?,
      fileHash: row['file_hash'] as String?,
      expectedHash: row['expected_hash'] as String?,
      isHashVerified: (row['is_hash_verified'] as int? ?? 0) == 1,
      startedAt: _parseDateTime(row['started_at'] as String?),
      completedAt: _parseDateTime(row['completed_at'] as String?),
      contentType: row['content_type'] as String?,
    );
  }
}

/// An installation row from the local database.
class DbInstallation {
  const DbInstallation({
    required this.id,
    required this.repoFullName,
    required this.installedVersion,
    required this.assetName,
    required this.installerPath,
    required this.installMethod,
    this.status = 'pending',
    this.errorMessage,
    this.installCommand,
    this.workingDirectory,
    this.exitCode,
    this.attestationHash,
    this.isAttestationVerified = false,
    this.installedAt,
    this.updatedAt,
    this.uninstalledAt,
  });

  final int id;
  final String repoFullName;
  final String installedVersion;
  final String assetName;
  final String installerPath;
  final String installMethod;
  final String status;
  final String? errorMessage;
  final String? installCommand;
  final String? workingDirectory;
  final int? exitCode;
  final String? attestationHash;
  final bool isAttestationVerified;
  final DateTime? installedAt;
  final DateTime? updatedAt;
  final DateTime? uninstalledAt;

  factory DbInstallation.fromRow(Row row) {
    return DbInstallation(
      id: row['id'] as int,
      repoFullName: row['repo_full_name'] as String,
      installedVersion: row['installed_version'] as String,
      assetName: row['asset_name'] as String,
      installerPath: row['installer_path'] as String,
      installMethod: row['install_method'] as String,
      status: row['status'] as String? ?? 'pending',
      errorMessage: row['error_message'] as String?,
      installCommand: row['install_command'] as String?,
      workingDirectory: row['working_directory'] as String?,
      exitCode: row['exit_code'] as int?,
      attestationHash: row['attestation_hash'] as String?,
      isAttestationVerified: (row['is_attestation_verified'] as int? ?? 0) == 1,
      installedAt: _parseDateTime(row['installed_at'] as String?),
      updatedAt: _parseDateTime(row['updated_at'] as String?),
      uninstalledAt: _parseDateTime(row['uninstalled_at'] as String?),
    );
  }
}

/// A search history entry from the local database.
class DbSearchHistoryEntry {
  const DbSearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchType,
    this.resultCount,
    required this.searchedAt,
  });

  final int id;
  final String query;
  final String searchType;
  final int? resultCount;
  final DateTime searchedAt;

  factory DbSearchHistoryEntry.fromRow(Row row) {
    return DbSearchHistoryEntry(
      id: row['id'] as int,
      query: row['query'] as String,
      searchType: row['search_type'] as String? ?? 'repositories',
      resultCount: row['result_count'] as int?,
      searchedAt: _parseDateTime(row['searched_at'] as String?) ??
          DateTime.now(),
    );
  }
}

/// A recently-viewed entry from the local database.
class DbRecentlyViewedEntry {
  const DbRecentlyViewedEntry({
    required this.id,
    this.repositoryId,
    required this.repoFullName,
    required this.viewedAt,
    this.viewCount = 1,
  });

  final int id;
  final int? repositoryId;
  final String repoFullName;
  final DateTime viewedAt;
  final int viewCount;

  factory DbRecentlyViewedEntry.fromRow(Row row) {
    return DbRecentlyViewedEntry(
      id: row['id'] as int,
      repositoryId: row['repository_id'] as int?,
      repoFullName: row['repo_full_name'] as String,
      viewedAt: _parseDateTime(row['viewed_at'] as String?) ?? DateTime.now(),
      viewCount: row['view_count'] as int? ?? 1,
    );
  }
}

// ── DateTime Helpers ───────────────────────────────────────────────────────

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _formatDateTime(DateTime? value) {
  if (value == null) return null;
  return value.toUtc().toIso8601String();
}

// ── Database Class ────────────────────────────────────────────────────────

/// Local SQLite database for the GitHub Store application.
///
/// Provides typed methods for all CRUD operations on the various tables
/// (repositories, downloads, installations, search history, recently viewed,
/// developer profiles, and settings).
///
/// Unlike the previous Drift-based implementation, this version uses raw
/// [sqlite3] and does not require code generation.
class AppDatabase {
  Database? _db;

  /// A completer that resolves when the database has been opened and tables created.
  final Completer<void> _readyCompleter = Completer<void>();

  /// Future that completes when the database is ready for use.
  Future<void> get ready => _readyCompleter.future;

  /// Stream controllers for reactive queries.
  final _repositoriesController =
      StreamController<List<DbRepository>>.broadcast();
  final _downloadsController = StreamController<List<DbDownload>>.broadcast();
  final _installationsController =
      StreamController<List<DbInstallation>>.broadcast();
  final _searchHistoryController =
      StreamController<List<DbSearchHistoryEntry>>.broadcast();
  final _recentlyViewedController =
      StreamController<List<DbRecentlyViewedEntry>>.broadcast();

  AppDatabase() {
    _open();
  }

  /// Constructor for testing with an in-memory database.
  AppDatabase.inMemory() {
    _db = sqlite3.open(':memory:');
    _createTables(_db!);
    _readyCompleter.complete();
  }

  Future<void> _open() async {
    final path = await _getDatabasePath();
    _db = sqlite3.open(path);
    _createTables(_db!);
    _readyCompleter.complete();
  }

  /// Ensures the database is open before returning it.
  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('AppDatabase has not been initialized yet. Await ready first.');
    }
    return d;
  }

  /// Close the database and all stream controllers.
  void close() {
    _repositoriesController.close();
    _downloadsController.close();
    _installationsController.close();
    _searchHistoryController.close();
    _recentlyViewedController.close();
    _db?.dispose();
  }

  /// Notify listeners that repositories have changed.
  void _notifyRepositoriesChanged() {
    _repositoriesController.add(getFavoritesSync());
  }

  void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS repositories (
        id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        owner TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        html_url TEXT NOT NULL,
        avatar_url TEXT,
        language TEXT,
        language_color TEXT,
        stargazers_count INTEGER NOT NULL DEFAULT 0,
        forks_count INTEGER NOT NULL DEFAULT 0,
        open_issues_count INTEGER NOT NULL DEFAULT 0,
        watchers_count INTEGER NOT NULL DEFAULT 0,
        subscribers_count INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0,
        default_branch TEXT NOT NULL DEFAULT 'main',
        is_fork INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_template INTEGER NOT NULL DEFAULT 0,
        is_private INTEGER NOT NULL DEFAULT 0,
        license TEXT,
        license_name TEXT,
        topics TEXT NOT NULL DEFAULT '[]',
        latest_release TEXT,
        homepage TEXT,
        created_at TEXT,
        pushed_at TEXT,
        updated_at TEXT,
        cached_at TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_starred INTEGER NOT NULL DEFAULT 0,
        sort_order REAL NOT NULL DEFAULT 0.0
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repo_full_name TEXT NOT NULL,
        release_tag TEXT NOT NULL,
        asset_name TEXT NOT NULL,
        download_url TEXT NOT NULL,
        local_file_path TEXT,
        file_size INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        progress REAL NOT NULL DEFAULT 0.0,
        download_speed INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        file_hash TEXT,
        expected_hash TEXT,
        is_hash_verified INTEGER NOT NULL DEFAULT 0,
        started_at TEXT,
        completed_at TEXT,
        content_type TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS installations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repo_full_name TEXT NOT NULL,
        installed_version TEXT NOT NULL,
        asset_name TEXT NOT NULL,
        installer_path TEXT NOT NULL,
        install_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        install_command TEXT,
        working_directory TEXT,
        exit_code INTEGER,
        attestation_hash TEXT,
        is_attestation_verified INTEGER NOT NULL DEFAULT 0,
        installed_at TEXT,
        updated_at TEXT,
        uninstalled_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        search_type TEXT NOT NULL DEFAULT 'repositories',
        result_count INTEGER,
        searched_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS recently_viewed (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        repository_id INTEGER,
        repo_full_name TEXT NOT NULL,
        viewed_at TEXT NOT NULL,
        view_count INTEGER NOT NULL DEFAULT 1
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS developer_profiles (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        name TEXT,
        bio TEXT,
        avatar_url TEXT,
        company TEXT,
        location TEXT,
        blog_url TEXT,
        twitter_username TEXT,
        public_repo_count INTEGER NOT NULL DEFAULT 0,
        followers_count INTEGER NOT NULL DEFAULT 0,
        following_count INTEGER NOT NULL DEFAULT 0,
        pinned_repositories TEXT NOT NULL DEFAULT '[]',
        account_type TEXT NOT NULL DEFAULT 'User',
        is_pro INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Create indexes
    _createIndexes(db);
  }

  void _createIndexes(Database db) {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_repos_full_name ON repositories (full_name)',
      'CREATE INDEX IF NOT EXISTS idx_repos_owner ON repositories (owner)',
      'CREATE INDEX IF NOT EXISTS idx_repos_language ON repositories (language)',
      'CREATE INDEX IF NOT EXISTS idx_repos_stars ON repositories (stargazers_count)',
      'CREATE INDEX IF NOT EXISTS idx_repos_favorite ON repositories (is_favorite)',
      'CREATE INDEX IF NOT EXISTS idx_repos_starred ON repositories (is_starred)',
      'CREATE INDEX IF NOT EXISTS idx_repos_cached_at ON repositories (cached_at)',
      'CREATE INDEX IF NOT EXISTS idx_downloads_repo ON downloads (repo_full_name)',
      'CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads (status)',
      'CREATE INDEX IF NOT EXISTS idx_installations_repo ON installations (repo_full_name)',
      'CREATE INDEX IF NOT EXISTS idx_installations_status ON installations (status)',
      'CREATE INDEX IF NOT EXISTS idx_search_history_date ON search_history (searched_at DESC)',
      'CREATE INDEX IF NOT EXISTS idx_recently_viewed_date ON recently_viewed (viewed_at DESC)',
    ];
    for (final sql in indexes) {
      db.execute(sql);
    }
  }

  // ── Repository Queries ─────────────────────────────────────────────────

  /// Get all favorite repositories, sorted by sort order then stars.
  Stream<List<DbRepository>> watchFavorites() {
    // For now, return a single-emission stream. A full implementation would
    // use sqlite3 updates/hooks for real-time reactivity.
    return _repositoriesController.stream;
  }

  /// Get all favorite repositories synchronously (for internal use).
  List<DbRepository> getFavoritesSync() {
    final results = db.select('''
      SELECT * FROM repositories
      WHERE is_favorite = 1
      ORDER BY sort_order ASC, stargazers_count DESC
    ''');
    return results.map((r) => DbRepository.fromRow(r)).toList();
  }

  /// Get all favorite repositories.
  Future<List<DbRepository>> getFavorites() async {
    return getFavoritesSync();
  }

  /// Get all starred repositories.
  Stream<List<DbRepository>> watchStarred() {
    return Stream.value(
      db
          .select('''
            SELECT * FROM repositories
            WHERE is_starred = 1
            ORDER BY stargazers_count DESC
          ''')
          .map((r) => DbRepository.fromRow(r))
          .toList(),
    );
  }

  /// Get recently viewed repositories.
  Stream<List<DbRecentlyViewedEntry>> watchRecentlyViewed({int limit = 50}) {
    return Stream.value(getRecentlyViewedSync(limit: limit));
  }

  /// Get recently viewed entries synchronously.
  List<DbRecentlyViewedEntry> getRecentlyViewedSync({int limit = 50}) {
    final results = db.select(
      'SELECT * FROM recently_viewed ORDER BY viewed_at DESC LIMIT ?',
      [limit],
    );
    return results.map((r) => DbRecentlyViewedEntry.fromRow(r)).toList();
  }

  /// Search repositories by name or description.
  Future<List<DbRepository>> searchRepositories(String query) {
    final results = db.select(
      "SELECT * FROM repositories WHERE name LIKE '%' || ? || '%' OR description LIKE '%' || ? || '%' ORDER BY stargazers_count DESC LIMIT 50",
      [query, query],
    );
    return Future.value(
      results.map((r) => DbRepository.fromRow(r)).toList(),
    );
  }

  /// Insert or update a repository (upsert).
  Future<void> upsertRepository(DbRepository repo) {
    final map = repo.toMap();
    final keys = map.keys.join(', ');
    final values = map.keys.map((k) => '?').join(', ');
    final updates = map.keys
        .where((k) => k != 'id')
        .map((k) => '$k = excluded.$k')
        .join(', ');

    db.execute(
      'INSERT INTO repositories ($keys) VALUES ($values) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      map.values.toList(),
    );
    _notifyRepositoriesChanged();
    return Future.value();
  }

  /// Toggle favorite status.
  Future<void> toggleFavorite(int repoId, bool isFavorite) {
    db.execute(
      'UPDATE repositories SET is_favorite = ? WHERE id = ?',
      [isFavorite ? 1 : 0, repoId],
    );
    _notifyRepositoriesChanged();
    return Future.value();
  }

  /// Toggle starred status.
  Future<void> toggleStarred(int repoId, bool isStarred) {
    db.execute(
      'UPDATE repositories SET is_starred = ? WHERE id = ?',
      [isStarred ? 1 : 0, repoId],
    );
    return Future.value();
  }

  /// Get a repository by ID.
  Future<DbRepository?> getRepositoryById(int id) {
    final results = db.select(
      'SELECT * FROM repositories WHERE id = ?',
      [id],
    );
    if (results.isEmpty) return Future.value(null);
    return Future.value(DbRepository.fromRow(results.first));
  }

  /// Get a repository by full name.
  Future<DbRepository?> getRepositoryByFullName(String fullName) {
    final results = db.select(
      'SELECT * FROM repositories WHERE full_name = ?',
      [fullName],
    );
    if (results.isEmpty) return Future.value(null);
    return Future.value(DbRepository.fromRow(results.first));
  }

  /// Clean up cached entries older than the given duration.
  Future<int> cleanupOldCache(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge).toUtc().toIso8601String();
    db.execute(
      'DELETE FROM repositories WHERE cached_at IS NOT NULL AND cached_at < ? AND is_favorite = 0 AND is_starred = 0',
      [cutoff],
    );
    return Future.value(db.updatedRows);
  }

  /// Get all repositories (for profile stats).
  Future<List<DbRepository>> getAllRepositories() async {
    final results = db.select('SELECT * FROM repositories');
    return results.map((r) => DbRepository.fromRow(r)).toList();
  }

  /// Get favorite repositories count.
  Future<int> getFavoritesCount() async {
    final results = db
        .select('SELECT COUNT(*) as cnt FROM repositories WHERE is_favorite = 1');
    return results.first['cnt'] as int? ?? 0;
  }

  /// Delete repositories that are favorited.
  Future<void> deleteFavorites() {
    db.execute('DELETE FROM repositories WHERE is_favorite = 1');
    _notifyRepositoriesChanged();
    return Future.value();
  }

  // ── Download Queries ───────────────────────────────────────────────────

  Stream<List<DbDownload>> watchDownloads() {
    return Stream.value(getDownloadsSync());
  }

  List<DbDownload> getDownloadsSync() {
    final results =
        db.select('SELECT * FROM downloads ORDER BY id DESC');
    return results.map((r) => DbDownload.fromRow(r)).toList();
  }

  Future<List<DbDownload>> getDownloads({String? statusFilter}) async {
    if (statusFilter != null) {
      final results = db.select(
        'SELECT * FROM downloads WHERE status = ? ORDER BY id DESC',
        [statusFilter],
      );
      return results.map((r) => DbDownload.fromRow(r)).toList();
    }
    return getDownloadsSync();
  }

  Future<void> updateDownloadProgress(
      int id, double progress, int speed) {
    db.execute(
      'UPDATE downloads SET progress = ?, download_speed = ?, status = ? WHERE id = ?',
      [progress, speed, 'downloading', id],
    );
    return Future.value();
  }

  Future<void> completeDownload(
      int id, String localPath, String? fileHash) {
    db.execute(
      'UPDATE downloads SET local_file_path = ?, file_hash = ?, is_hash_verified = ?, status = ?, completed_at = ? WHERE id = ?',
      [
        localPath,
        fileHash,
        fileHash != null ? 1 : 0,
        'completed',
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
    return Future.value();
  }

  Future<void> failDownload(int id, String errorMessage) {
    db.execute(
      'UPDATE downloads SET status = ?, error_message = ?, completed_at = ? WHERE id = ?',
      [
        'failed',
        errorMessage,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
    return Future.value();
  }

  /// Get count of completed downloads (distinct repo full names).
  Future<int> getCompletedDownloadsCount() async {
    final results = db.select(
      'SELECT COUNT(DISTINCT repo_full_name) as cnt FROM downloads WHERE status = ?',
      ['completed'],
    );
    return results.first['cnt'] as int? ?? 0;
  }

  // ── Installation Queries ───────────────────────────────────────────────

  Stream<List<DbInstallation>> watchInstallations() {
    return Stream.value(getInstallationsSync());
  }

  List<DbInstallation> getInstallationsSync() {
    final results =
        db.select('SELECT * FROM installations ORDER BY installed_at DESC');
    return results.map((r) => DbInstallation.fromRow(r)).toList();
  }

  Future<List<DbInstallation>> getInstallations({
    bool activeOnly = false,
  }) async {
    if (activeOnly) {
      final results = db.select(
        'SELECT * FROM installations WHERE uninstalled_at IS NULL ORDER BY installed_at DESC',
      );
      return results.map((r) => DbInstallation.fromRow(r)).toList();
    }
    return getInstallationsSync();
  }

  Future<List<DbInstallation>> getActiveInstallations() {
    return getInstallations(activeOnly: false);
  }

  Future<DbInstallation?> getInstallationByRepoFullName(String fullName) {
    final results = db.select(
      'SELECT * FROM installations WHERE repo_full_name = ? AND uninstalled_at IS NULL',
      [fullName],
    );
    if (results.isEmpty) return Future.value(null);
    return Future.value(DbInstallation.fromRow(results.first));
  }

  Future<int> insertInstallation({
    required String repoFullName,
    required String installedVersion,
    required String assetName,
    required String installerPath,
    required String installMethod,
    String status = 'completed',
    DateTime? installedAt,
  }) async {
    db.execute(
      'INSERT INTO installations (repo_full_name, installed_version, asset_name, installer_path, install_method, status, installed_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        repoFullName,
        installedVersion,
        assetName,
        installerPath,
        installMethod,
        status,
        _formatDateTime(installedAt ?? DateTime.now()),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    return db.lastInsertRowId;
  }

  Future<void> updateInstallation(int id, {
    String? status,
    String? installedVersion,
    String? installerPath,
    String? assetName,
    String? installMethod,
    int? exitCode,
    DateTime? uninstalledAt,
  }) {
    final sets = <String>[];
    final values = <Object?>[];

    if (status != null) {
      sets.add('status = ?');
      values.add(status);
    }
    if (installedVersion != null) {
      sets.add('installed_version = ?');
      values.add(installedVersion);
    }
    if (installerPath != null) {
      sets.add('installer_path = ?');
      values.add(installerPath);
    }
    if (assetName != null) {
      sets.add('asset_name = ?');
      values.add(assetName);
    }
    if (installMethod != null) {
      sets.add('install_method = ?');
      values.add(installMethod);
    }
    if (exitCode != null) {
      sets.add('exit_code = ?');
      values.add(exitCode);
    }
    if (uninstalledAt != null) {
      sets.add('uninstalled_at = ?');
      values.add(_formatDateTime(uninstalledAt));
    }
    // Always update timestamp
    sets.add('updated_at = ?');
    values.add(DateTime.now().toUtc().toIso8601String());

    values.add(id);

    if (sets.isNotEmpty) {
      db.execute(
        'UPDATE installations SET ${sets.join(', ')} WHERE id = ?',
        values,
      );
    }
    return Future.value();
  }

  Future<void> completeInstallation(int id, int exitCode) {
    return updateInstallation(
      id,
      status: exitCode == 0 ? 'completed' : 'failed',
      exitCode: exitCode,
    );
  }

  /// Get count of completed installations (distinct repo full names).
  Future<int> getCompletedInstallationsCount() async {
    final results = db.select(
      'SELECT COUNT(DISTINCT repo_full_name) as cnt FROM installations WHERE status = ?',
      ['completed'],
    );
    return results.first['cnt'] as int? ?? 0;
  }

  /// Get total count of recently viewed entries.
  Future<int> getRecentlyViewedCount() async {
    final results =
        db.select('SELECT COUNT(*) as cnt FROM recently_viewed');
    return results.first['cnt'] as int? ?? 0;
  }

  // ── Search History Queries ─────────────────────────────────────────────

  Stream<List<DbSearchHistoryEntry>> watchSearchHistory({int limit = 20}) {
    return Stream.value(getSearchHistorySync(limit: limit));
  }

  List<DbSearchHistoryEntry> getSearchHistorySync({int limit = 20}) {
    final results = db.select(
      'SELECT * FROM search_history ORDER BY searched_at DESC LIMIT ?',
      [limit],
    );
    return results.map((r) => DbSearchHistoryEntry.fromRow(r)).toList();
  }

  Future<void> addSearchHistory(String query, String searchType) {
    db.execute(
      'INSERT INTO search_history (query, search_type, searched_at) VALUES (?, ?, ?)',
      [query, searchType, DateTime.now().toUtc().toIso8601String()],
    );
    return Future.value();
  }

  Future<void> clearSearchHistory() {
    db.execute('DELETE FROM search_history');
    return Future.value();
  }

  // ── Recently Viewed Queries ────────────────────────────────────────────

  Future<void> addRecentlyViewed(String repoFullName, int? repoId) async {
    final existing = db.select(
      'SELECT id, view_count FROM recently_viewed WHERE repo_full_name = ?',
      [repoFullName],
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      db.execute(
        'UPDATE recently_viewed SET viewed_at = ?, view_count = ? WHERE id = ?',
        [
          DateTime.now().toUtc().toIso8601String(),
          (row['view_count'] as int? ?? 0) + 1,
          row['id'] as int,
        ],
      );
    } else {
      db.execute(
        'INSERT INTO recently_viewed (repo_full_name, repository_id, viewed_at, view_count) VALUES (?, ?, ?, ?)',
        [
          repoFullName,
          repoId,
          DateTime.now().toUtc().toIso8601String(),
          1,
        ],
      );
    }
  }

  Future<void> removeRecentlyViewed(String repoFullName) {
    db.execute(
      'DELETE FROM recently_viewed WHERE repo_full_name = ?',
      [repoFullName],
    );
    return Future.value();
  }

  Future<void> clearRecentlyViewed() {
    db.execute('DELETE FROM recently_viewed');
    return Future.value();
  }

  // ── Settings Queries ───────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final results = db.select(
      'SELECT value FROM app_settings WHERE key = ?',
      [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    db.execute(
      'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
      [
        key,
        value,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  /// Delete a setting by key.
  Future<void> deleteSetting(String key) async {
    db.execute('DELETE FROM app_settings WHERE key = ?', [key]);
  }
}

// ── Database Path Helper ──────────────────────────────────────────────────

/// Returns the platform-appropriate path for the database file.
Future<String> _getDatabasePath() async {
  final dbFolder = await _getDatabaseDirectory();
  final file = File(p.join(dbFolder.path, 'github_store.db'));
  return file.path;
}

Future<Directory> _getDatabaseDirectory() async {
  if (Platform.isWindows) {
    final appDataDir =
        Directory(Platform.environment['APPDATA'] ?? r'C:\AppData\Roaming');
    final dbDir = Directory(p.join(appDataDir.path, 'GitHubStore'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    return dbDir;
  } else if (Platform.isMacOS) {
    final appSupportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appSupportDir.path, 'GitHubStore'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    return dbDir;
  } else if (Platform.isLinux) {
    final configDir = Directory(
      Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME']}/.config',
    );
    final dbDir = Directory(p.join(configDir.path, 'github-store'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    return dbDir;
  }
  // Fallback
  return await getApplicationDocumentsDirectory();
}
