import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Table Definitions ─────────────────────────────────────────────────────

/// Repositories table: caches GitHub repository metadata.
class Repositories extends Table {
  /// GitHub repository ID (unique, primary key).
  IntColumn get id => integer()()();

  /// Full name in format "owner/repo".
  TextColumn get fullName => text().withLength(min: 3, max: 200)()();

  /// Repository owner username.
  TextColumn get owner => text().withLength(min: 1, max: 100)()();

  /// Repository name.
  TextColumn get name => text().withLength(min: 1, max: 100)()();

  /// Repository description.
  TextColumn get description => text().nullable()();

  /// URL to the repository on GitHub.
  TextColumn get htmlUrl => text()();

  /// URL to the owner's avatar image.
  TextColumn get avatarUrl => text().nullable()();

  /// Primary programming language.
  TextColumn get language => text().nullable()();

  /// Language color code (hex).
  TextColumn get languageColor => text().nullable()();

  /// Number of stars.
  IntColumn get stargazersCount => integer().withDefault(const Constant(0))();

  /// Number of forks.
  IntColumn get forksCount => integer().withDefault(const Constant(0))();

  /// Number of open issues.
  IntColumn get openIssuesCount => integer().withDefault(const Constant(0))();

  /// Number of watchers.
  IntColumn get watchersCount => integer().withDefault(const Constant(0))();

  /// Number of subscribers.
  IntColumn get subscribersCount => integer().withDefault(const Constant(0))();

  /// Total disk usage in KB.
  IntColumn get size => integer().withDefault(const Constant(0))();

  /// Default branch name (e.g. "main", "master").
  TextColumn get defaultBranch => text().withDefault(const Constant('main'))();

  /// Whether this repo is a fork.
  BoolColumn get isFork => boolean().withDefault(const Constant(false))();

  /// Whether this repo is archived.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Whether this repo is a template.
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();

  /// Whether this repo is marked as private.
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  /// License SPDX identifier.
  TextColumn get license => text().nullable()();

  /// License name.
  TextColumn get licenseName => text().nullable()();

  /// JSON-encoded list of topic strings.
  TextColumn get topics => text().withDefault(const Constant('[]'))();

  /// JSON-encoded latest release info (tag, name, publishedAt, assets).
  TextColumn get latestRelease => text().nullable()();

  /// Homepage URL.
  TextColumn get homepage => text().nullable()();

  /// When the repo was created on GitHub.
  DateTimeColumn get createdAt => dateTime().nullable()();

  /// When the repo was last pushed to.
  DateTimeColumn get pushedAt => dateTime().nullable()();

  /// When the repo was last updated.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Local timestamp of when we last fetched/refreshed this entry.
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Is the repo currently favorited/bookmarked by the user.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Is the repo starred by the authenticated user.
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  /// Local sort order weight for pinned/custom lists.
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Downloads table: tracks download/install tasks.
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Associated repository full name.
  TextColumn get repoFullName => text()();

  /// Release tag/version that was downloaded.
  TextColumn get releaseTag => text()();

  /// Asset file name that was downloaded.
  TextColumn get assetName => text()();

  /// URL from which the file was downloaded.
  TextColumn get downloadUrl => text()();

  /// Local file path where the download was saved.
  TextColumn get localFilePath => text().nullable()();

  /// File size in bytes.
  IntColumn get fileSize => integer().nullable()();

  /// Download status: pending, downloading, completed, failed, cancelled.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Download progress as a fraction (0.0 to 1.0).
  RealColumn get progress => real().withDefault(const Constant(0.0))();

  /// Download speed in bytes/second.
  IntColumn get downloadSpeed => integer().withDefault(const Constant(0))();

  /// Error message if the download failed.
  TextColumn get errorMessage => text().nullable()();

  /// SHA-256 hash of the downloaded file for verification.
  TextColumn get fileHash => text().nullable()();

  /// SHA-256 hash provided by the release for attestation.
  TextColumn get expectedHash => text().nullable()();

  /// Whether the hash was verified successfully.
  BoolColumn get isHashVerified =>
      boolean().withDefault(const Constant(false))();

  /// When the download started.
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// When the download completed or failed.
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Content type / MIME type of the downloaded file.
  TextColumn get contentType => text().nullable()();
}

/// Installation history table: tracks which apps have been installed.
class Installations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Associated repository full name.
  TextColumn get repoFullName => text()();

  /// Installed version/release tag.
  TextColumn get installedVersion => text()();

  /// Asset file name that was installed.
  TextColumn get assetName => text()();

  /// Local file path of the installer/package.
  TextColumn get installerPath => text()();

  /// Install method: msi, exe, dmg, pkg, deb, rpm, appimage, etc.
  TextColumn get installMethod => text()();

  /// Installation status: pending, installing, completed, failed, uninstalled.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Error message if installation failed.
  TextColumn get errorMessage => text().nullable()();

  /// Install command or arguments used.
  TextColumn get installCommand => text().nullable()();

  /// Working directory used during installation.
  TextColumn get workingDirectory => text().nullable()();

  /// Process exit code (null if still running).
  IntColumn get exitCode => integer().nullable()();

  /// SHA-256 hash of the installed file for attestation.
  TextColumn get attestationHash => text().nullable()();

  /// Whether the attestation was verified.
  BoolColumn get isAttestationVerified =>
      boolean().withDefault(const Constant(false))();

  /// When installation started.
  DateTimeColumn get installedAt => dateTime().nullable()();

  /// When the record was last updated.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// When the app was uninstalled (null if still installed).
  DateTimeColumn get uninstalledAt => dateTime().nullable()();
}

/// Search history table: stores recent search queries.
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The search query text.
  TextColumn get query => text()();

  /// Search type: repositories, users, code, issues.
  TextColumn get searchType =>
      text().withDefault(const Constant('repositories'))();

  /// Number of results returned.
  IntColumn get resultCount => integer().nullable()();

  /// When the search was performed.
  DateTimeColumn get searchedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Recently viewed repositories table.
class RecentlyViewed extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Associated repository ID (foreign key to Repositories).
  IntColumn get repositoryId => integer().nullable()();

  /// Repository full name (denormalized for quick lookup).
  TextColumn get repoFullName => text()();

  /// When the repo was last viewed.
  DateTimeColumn get viewedAt => dateTime().withDefault(currentDateAndTime)();

  /// View count.
  IntColumn get viewCount => integer().withDefault(const Constant(1))();
}

/// Developer profiles cache table.
class DeveloperProfiles extends Table {
  IntColumn get id => integer()()();

  /// GitHub username (primary key alternative).
  TextColumn get username => text().unique()();

  /// Display name (if set).
  TextColumn get name => text().nullable()();

  /// User bio.
  TextColumn get bio => text().nullable()();

  /// Avatar URL.
  TextColumn get avatarUrl => text().nullable()();

  /// Company or organization.
  TextColumn get company => text().nullable()();

  /// Location.
  TextColumn get location => text().nullable()();

  /// Personal website / blog URL.
  TextColumn get blogUrl => text().nullable()();

  /// Twitter username.
  TextColumn get twitterUsername => text().nullable()();

  /// Number of public repositories.
  IntColumn get publicRepoCount => integer().withDefault(const Constant(0))();

  /// Number of followers.
  IntColumn get followersCount => integer().withDefault(const Constant(0))();

  /// Number of accounts following.
  IntColumn get followingCount => integer().withDefault(const Constant(0))();

  /// JSON-encoded list of pinned repositories.
  TextColumn get pinnedRepositories =>
      text().withDefault(const Constant('[]'))();

  /// Account type: User or Organization.
  TextColumn get accountType =>
      text().withDefault(const Constant('User'))();

  /// Whether this profile is a pro account.
  BoolColumn get isPro => boolean().withDefault(const Constant(false))();

  /// When the profile was last cached.
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// App settings stored in the database.
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unique setting key.
  TextColumn get key => text().unique()();

  /// Setting value as a string (JSON for complex types).
  TextColumn get value => text()();

  /// Last updated timestamp.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ── Database Class ────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Repositories,
    Downloads,
    Installations,
    SearchHistory,
    RecentlyViewed,
    DeveloperProfiles,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();

          // Create indexes for common queries
          await customStatement(
            'CREATE INDEX idx_repos_full_name ON repositories (full_name)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_owner ON repositories (owner)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_language ON repositories (language)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_stars ON repositories (stargazers_count)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_favorite ON repositories (is_favorite)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_starred ON repositories (is_starred)',
          );
          await customStatement(
            'CREATE INDEX idx_repos_cached_at ON repositories (cached_at)',
          );
          await customStatement(
            'CREATE INDEX idx_downloads_repo ON downloads (repo_full_name)',
          );
          await customStatement(
            'CREATE INDEX idx_downloads_status ON downloads (status)',
          );
          await customStatement(
            'CREATE INDEX idx_installations_repo ON installations (repo_full_name)',
          );
          await customStatement(
            'CREATE INDEX idx_installations_status ON installations (status)',
          );
          await customStatement(
            'CREATE INDEX idx_search_history_date ON search_history (searched_at DESC)',
          );
          await customStatement(
            'CREATE INDEX idx_recently_viewed_date ON recently_viewed (viewed_at DESC)',
          );
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Future migrations go here
        },
      );

  // ── Repository Queries ─────────────────────────────────────────────────

  /// Get all favorite repositories, sorted by sort order.
  Stream<List<Repository>> watchFavorites() {
    return (select(repositories)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.stargazersCount),
          ]))
        .watch();
  }

  /// Get all starred repositories.
  Stream<List<Repository>> watchStarred() {
    return (select(repositories)
          ..where((t) => t.isStarred.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.stargazersCount)]))
        .watch();
  }

  /// Get recently viewed repositories.
  Stream<List<RecentlyViewedEntry>> watchRecentlyViewed({int limit = 50}) {
    return (select(recentlyViewed)
          ..orderBy([(t) => OrderingTerm.desc(t.viewedAt)])
          ..limit(limit))
        .watch();
  }

  /// Search repositories by name or description.
  Future<List<Repository>> searchRepositories(String query) {
    return (select(repositories)
          ..where((t) =>
              t.name.like('%$query%') | t.description.like('%$query%'))
          ..orderBy([(t) => OrderingTerm.desc(t.stargazersCount)])
          ..limit(50))
        .get();
  }

  /// Insert or update a repository (upsert).
  Future<void> upsertRepository(RepositoriesCompanion repo) {
    return into(repositories).insertOnConflictUpdate(repo);
  }

  /// Toggle favorite status.
  Future<void> toggleFavorite(int repoId, bool isFavorite) {
    return (update(repositories)..where((t) => t.id.equals(repoId)))
        .write(RepositoriesCompanion(isFavorite: Value(isFavorite)));
  }

  /// Toggle starred status.
  Future<void> toggleStarred(int repoId, bool isStarred) {
    return (update(repositories)..where((t) => t.id.equals(repoId)))
        .write(RepositoriesCompanion(isStarred: Value(isStarred)));
  }

  /// Get a repository by ID.
  Future<Repository?> getRepositoryById(int id) {
    return (select(repositories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a repository by full name.
  Future<Repository?> getRepositoryByFullName(String fullName) {
    return (select(repositories)..where((t) => t.fullName.equals(fullName)))
        .getSingleOrNull();
  }

  /// Clean up cached entries older than the given duration.
  Future<int> cleanupOldCache(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(repositories)..where((t) => t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  // ── Download Queries ───────────────────────────────────────────────────

  Stream<List<Download>> watchDownloads() {
    return (select(downloads)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  Future<void> updateDownloadProgress(int id, double progress, int speed) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(
        progress: Value(progress),
        downloadSpeed: Value(speed),
        status: const Value('downloading'),
      ),
    );
  }

  Future<void> completeDownload(int id, String localPath, String? fileHash) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(
        localFilePath: Value(localPath),
        fileHash: Value(fileHash),
        isHashVerified: Value(fileHash != null),
        status: const Value('completed'),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> failDownload(int id, String errorMessage) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Installation Queries ───────────────────────────────────────────────

  Stream<List<Installation>> watchInstallations() {
    return (select(installations)
          ..orderBy([(t) => OrderingTerm.desc(t.installedAt)]))
        .watch();
  }

  Future<List<Installation>> getActiveInstallations() {
    return (select(installations)
          ..where((t) => t.status.equals('installing')))
        .get();
  }

  Future<void> completeInstallation(int id, int exitCode) {
    return (update(installations)..where((t) => t.id.equals(id))).write(
      InstallationsCompanion(
        status: Value(exitCode == 0 ? 'completed' : 'failed'),
        exitCode: Value(exitCode),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Search History Queries ─────────────────────────────────────────────

  Stream<List<SearchHistoryEntry>> watchSearchHistory({int limit = 20}) {
    return (select(searchHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> addSearchHistory(String query, String searchType) {
    return into(searchHistory).insert(
      SearchHistoryCompanion(
        query: Value(query),
        searchType: Value(searchType),
      ),
    );
  }

  Future<void> clearSearchHistory() {
    return delete(searchHistory).go();
  }

  // ── Recently Viewed Queries ────────────────────────────────────────────

  Future<void> addRecentlyViewed(String repoFullName, int? repoId) async {
    final existing = await (select(recentlyViewed)
          ..where((t) => t.repoFullName.equals(repoFullName)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(recentlyViewed)..where((t) => t.id.equals(existing.id)))
          .write(
        RecentlyViewedCompanion(
          viewedAt: Value(DateTime.now()),
          viewCount: Value(existing.viewCount + 1),
        ),
      );
    } else {
      await into(recentlyViewed).insert(
        RecentlyViewedCompanion(
          repoFullName: Value(repoFullName),
          repositoryId: Value(repoId),
        ),
      );
    }
  }

  Future<void> clearRecentlyViewed() {
    return delete(recentlyViewed).go();
  }

  // ── Settings Queries ───────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    final existing = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(appSettings)..where((t) => t.id.equals(existing.id)))
          .write(AppSettingsCompanion(
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ));
    } else {
      await into(appSettings).insert(
        AppSettingsCompanion(
          key: Value(key),
          value: Value(value),
        ),
      );
    }
  }
}

/// Opens the SQLite database at the appropriate platform path.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await _getDatabasePath();
    final file = File(p.join(dbFolder.path, 'github_store.db'));
    return NativeDatabase.createInBackground(file);
  });
}

Future<Directory> _getDatabasePath() async {
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
    final configDir =
        Directory(Platform.environment['XDG_CONFIG_HOME'] ??
            '${Platform.environment['HOME']}/.config');
    final dbDir = Directory(p.join(configDir.path, 'github-store'));
    if (!await dbDir.exists()) await dbDir.create(recursive: true);
    return dbDir;
  }
  // Fallback
  return await getApplicationDocumentsDirectory();
}
