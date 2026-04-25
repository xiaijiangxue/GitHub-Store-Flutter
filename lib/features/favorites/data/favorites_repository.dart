import '../../../core/database/app_database.dart';
import '../../../core/models/owner_model.dart';
import '../../../core/models/repository_model.dart';

/// Repository for managing favorited repositories in the local database.
///
/// Favorites are stored in the [repositories] table using the `isFavorite`
/// column. This repository provides methods to query, add, remove, and
/// toggle favorites, as well as clear all favorites.
class FavoritesRepository {
  FavoritesRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  // ── Query Methods ───────────────────────────────────────────────────────

  /// Get all favorite repositories from the database.
  ///
  /// Returns a list of [RepositoryModel] populated from the database rows,
  /// ordered by sort order (ascending) then stars (descending).
  Future<List<RepositoryModel>> getAllFavorites() async {
    final rows = await _database.getFavorites();
    return rows.map(_rowToModel).toList();
  }

  /// Check whether a repository is favorited.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  Future<bool> isFavorited(String owner, String name) async {
    final fullName = '$owner/$name';
    final row = await _database.getRepositoryByFullName(fullName);
    return row?.isFavorite ?? false;
  }

  // ── Mutation Methods ────────────────────────────────────────────────────

  /// Toggle the favorite status of a repository.
  ///
  /// If the repo is not yet in the database, it will be upserted first with
  /// the provided metadata.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  /// [description] — optional description.
  /// [avatarUrl] — optional owner avatar URL.
  /// [stars] — star count (defaults to 0).
  /// [language] — primary language.
  Future<void> toggleFavorite(
    String owner,
    String name, {
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    final fullName = '$owner/$name';
    final existing = await _database.getRepositoryByFullName(fullName);

    if (existing != null) {
      final newStatus = !existing.isFavorite;
      await _database.toggleFavorite(existing.id, newStatus);
    } else {
      // Insert a minimal entry then set as favorite
      final id = await _insertMinimalRepo(
        owner: owner,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        stars: stars,
        language: language,
      );
      await _database.toggleFavorite(id, true);
    }
  }

  /// Remove a repository from favorites.
  ///
  /// Sets `isFavorite = false` for the matching repository.
  /// If the repository doesn't exist in the DB, this is a no-op.
  ///
  /// [owner] — repository owner login.
  /// [name] — repository name.
  Future<void> removeFavorite(String owner, String name) async {
    final fullName = '$owner/$name';
    final existing = await _database.getRepositoryByFullName(fullName);

    if (existing != null && existing.isFavorite) {
      await _database.toggleFavorite(existing.id, false);
    }
  }

  /// Clear all favorites by setting `isFavorite = false` on every repository.
  Future<void> clearAll() async {
    final favorites = await _database.getFavorites();

    for (final row in favorites) {
      await _database.toggleFavorite(row.id, false);
    }
  }

  /// Delete all favorite repository rows from the database.
  ///
  /// Unlike [clearAll] (which just unsets the flag), this permanently removes
  /// the rows that are only in the DB because they were favorited.
  Future<void> deleteAllFavorites() async {
    await _database.deleteFavorites();
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  /// Insert a minimal repository entry into the database.
  ///
  /// Returns the generated ID.
  Future<int> _insertMinimalRepo({
    required String owner,
    required String name,
    String? description,
    String? avatarUrl,
    int stars = 0,
    String? language,
  }) async {
    // Use a hash of fullName as a deterministic ID for locally-created entries.
    final fullName = '$owner/$name';
    final id = fullName.hashCode.abs();

    await _database.upsertRepository(
      DbRepository(
        id: id,
        fullName: fullName,
        owner: owner,
        name: name,
        description: description,
        htmlUrl: 'https://github.com/$fullName',
        avatarUrl: avatarUrl,
        language: language,
        stargazersCount: stars,
        cachedAt: DateTime.now(),
      ),
    );

    return id;
  }

  /// Convert a database [DbRepository] row to a domain [RepositoryModel].
  RepositoryModel _rowToModel(DbRepository row) {
    return RepositoryModel(
      id: row.id,
      name: row.name,
      fullName: row.fullName,
      owner: OwnerModel(
        login: row.owner,
        avatarUrl: row.avatarUrl,
      ),
      description: row.description,
      stars: row.stargazersCount,
      forks: row.forksCount,
      watchers: row.watchersCount,
      openIssues: row.openIssuesCount,
      language: row.language,
      languageColor: row.languageColor,
      license: row.license != null
          ? LicenseInfo(key: row.license, name: row.licenseName)
          : null,
      isFork: row.isFork,
      isArchived: row.isArchived,
      isPrivate: row.isPrivate,
      defaultBranch: row.defaultBranch,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pushedAt: row.pushedAt,
      homepage: row.homepage,
      htmlUrl: row.htmlUrl,
      subscribers: row.subscribersCount,
      sortOrder: row.sortOrder,
      isFavorited: row.isFavorite,
      isStarred: row.isStarred,
      topics: _parseTopics(row.topics),
      latestRelease: row.latestRelease != null
          ? LatestReleaseInfo.fromJsonString(row.latestRelease!)
          : null,
    );
  }

  /// Parse the JSON-encoded topics string into a list.
  List<String> _parseTopics(String topicsJson) {
    if (topicsJson.isEmpty) return const [];
    if (topicsJson == '[]') return const [];
    try {
      final decoded = List<dynamic>.from(
        _jsonDecode(topicsJson) as List,
      );
      return decoded.cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// Simple JSON decoder (avoids dart:convert dependency cycle in some configs).
  dynamic _jsonDecode(String source) {
    // ignore: avoid_dynamic_calls
    return const _JsonDecoder().convert(source);
  }
}

// Minimal JSON decoder
class _JsonDecoder {
  const _JsonDecoder();
  dynamic convert(String source) {
    return _parse(_JsonSource(source));
  }

  dynamic _parse(_JsonSource src) {
    src.skipWhitespace();
    if (src.isDone) return null;

    final ch = src.peek();
    if (ch == '{') return _parseObject(src);
    if (ch == '[') return _parseArray(src);
    if (ch == '"') return _parseString(src);
    if (ch == 't' || ch == 'f') return _parseBool(src);
    if (ch == 'n') return _parseNull(src);
    return _parseNumber(src);
  }

  Map<String, dynamic> _parseObject(_JsonSource src) {
    src.expect('{');
    final result = <String, dynamic>{};
    while (src.peek() != '}') {
      src.skipWhitespace();
      final key = _parseString(src) as String;
      src.skipWhitespace();
      src.expect(':');
      final value = _parse(src);
      result[key] = value;
      src.skipWhitespace();
      if (src.peek() == ',') src.advance();
    }
    src.expect('}');
    return result;
  }

  List<dynamic> _parseArray(_JsonSource src) {
    src.expect('[');
    final result = <dynamic>[];
    while (src.peek() != ']') {
      src.skipWhitespace();
      result.add(_parse(src));
      src.skipWhitespace();
      if (src.peek() == ',') src.advance();
    }
    src.expect(']');
    return result;
  }

  String _parseString(_JsonSource src) {
    src.expect('"');
    final buffer = StringBuffer();
    while (src.peek() != '"') {
      if (src.peek() == '\\') {
        src.advance();
        final esc = src.advance();
        switch (esc) {
          case 'n': buffer.write('\n');
          case 'r': buffer.write('\r');
          case 't': buffer.write('\t');
          case 'b': buffer.write('\b');
          case 'f': buffer.write('\f');
          case '\\': buffer.write('\\');
          case '"': buffer.write('"');
          case '/': buffer.write('/');
          default: buffer.write(esc);
        }
      } else {
        buffer.write(src.advance());
      }
    }
    src.expect('"');
    return buffer.toString();
  }

  bool _parseBool(_JsonSource src) {
    if (src.peek() == 't') {
      src.expect('true');
      return true;
    }
    src.expect('false');
    return false;
  }

  void _parseNull(_JsonSource src) {
    src.expect('null');
  }

  num _parseNumber(_JsonSource src) {
    final buffer = StringBuffer();
    while (!src.isDone) {
      final ch = src.peek();
      if (ch == '-' || ch == '+' || ch == '.' || ch == 'e' || ch == 'E' ||
          (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
        buffer.write(src.advance());
      } else {
        break;
      }
    }
    return num.parse(buffer.toString());
  }
}

class _JsonSource {
  _JsonSource(this.source);
  final String source;
  int _pos = 0;

  bool get isDone => _pos >= source.length;
  String peek() => isDone ? '' : source[_pos];
  String advance() => source[_pos++];
  void skipWhitespace() {
    while (!isDone && ' \t\n\r'.contains(source[_pos])) _pos++;
  }

  void expect(String s) {
    for (var i = 0; i < s.length; i++) {
      if (advance() != s[i]) {
        throw FormatException('Expected "$s" at position $_pos');
      }
    }
  }
}
