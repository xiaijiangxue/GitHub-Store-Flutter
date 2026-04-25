/// Result of parsing a deep link URL.
enum DeeplinkType {
  /// Navigate to a repository details page.
  repoDetails,

  /// The URL was not recognised.
  unknown,
}

/// Parsed result from a deep link.
class DeeplinkResult {
  const DeeplinkResult({
    required this.type,
    this.owner,
    this.repo,
    this.originalUrl,
  });

  /// The type of navigation action this deeplink represents.
  final DeeplinkType type;

  /// Repository owner (login). Non-null for [DeeplinkType.repoDetails].
  final String? owner;

  /// Repository name. Non-null for [DeeplinkType.repoDetails].
  final String? repo;

  /// The original URL string that was parsed.
  final String? originalUrl;

  /// Convenience: the "owner/repo" full name, or null.
  String? get fullName {
    if (owner != null && repo != null) return '$owner/$repo';
    return null;
  }

  @override
  String toString() =>
      'DeeplinkResult(type: $type, owner: $owner, repo: $repo)';
}

/// Repository for parsing and validating deep link URLs.
///
/// Supported URL formats:
///
/// - Custom scheme: `githubstore://repo/{owner}/{name}`
/// - GitHub direct: `https://github.com/{owner}/{name}`
/// - GitHub Store web: `https://github-store.org/app?repo={owner}/{name}`
///
/// All owner/repo names must be valid GitHub identifiers: alphanumeric
/// characters, hyphens, underscores, and dots.
class DeeplinkRepository {
  DeeplinkRepository();

  /// Regex for valid GitHub owner / repo name identifiers.
  ///
  /// GitHub allows: letters, digits, hyphens, underscores, and dots.
  /// Must not start or end with a hyphen, and must not contain consecutive
  /// hyphens.
  static final _identifierPattern = RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9._-]*[a-zA-Z0-9])?$');

  /// Parse a URL string and return a [DeeplinkResult].
  ///
  /// Returns [DeeplinkResult.unknown] if the URL does not match any
  /// recognised format or contains invalid identifiers.
  DeeplinkResult parse(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const DeeplinkResult(type: DeeplinkType.unknown, originalUrl: '');
    }

    // ── Custom scheme ───────────────────────────────────────────────────
    if (trimmed.startsWith('githubstore://')) {
      return _parseCustomScheme(trimmed);
    }

    // ── HTTPS URLs ──────────────────────────────────────────────────────
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return _parseHttpsUrl(trimmed);
    }

    // ── Bare "owner/repo" format ────────────────────────────────────────
    if (trimmed.contains('/') && !trimmed.contains('://')) {
      final parts = trimmed.split('/');
      if (parts.length == 2) {
        final owner = parts[0].trim();
        final repo = parts[1].trim();
        if (_isValidIdentifier(owner) && _isValidIdentifier(repo)) {
          return DeeplinkResult(
            type: DeeplinkType.repoDetails,
            owner: owner,
            repo: repo,
            originalUrl: trimmed,
          );
        }
      }
    }

    return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: trimmed);
  }

  // ── Custom scheme parser ────────────────────────────────────────────────

  DeeplinkResult _parseCustomScheme(String url) {
    // Format: githubstore://repo/{owner}/{name}
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
    }

    final pathSegments = uri.pathSegments;

    // Expected: ["repo", "owner", "name"]
    if (pathSegments.length >= 3 &&
        pathSegments[0] == 'repo' &&
        _isValidIdentifier(pathSegments[1]) &&
        _isValidIdentifier(pathSegments[2])) {
      return DeeplinkResult(
        type: DeeplinkType.repoDetails,
        owner: pathSegments[1],
        repo: pathSegments[2],
        originalUrl: url,
      );
    }

    // Fallback: githubstore://owner/repo (without "repo" prefix)
    if (pathSegments.length >= 2 &&
        _isValidIdentifier(pathSegments[0]) &&
        _isValidIdentifier(pathSegments[1])) {
      return DeeplinkResult(
        type: DeeplinkType.repoDetails,
        owner: pathSegments[0],
        repo: pathSegments[1],
        originalUrl: url,
      );
    }

    return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
  }

  // ── HTTPS URL parser ────────────────────────────────────────────────────

  DeeplinkResult _parseHttpsUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
    }

    final host = uri.host.toLowerCase();

    // ── github.com/{owner}/{repo} ─────────────────────────────────────
    if (host == 'github.com' || host == 'www.github.com') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          _isValidIdentifier(segments[0]) &&
          _isValidIdentifier(segments[1])) {
        return DeeplinkResult(
          type: DeeplinkType.repoDetails,
          owner: segments[0],
          repo: segments[1],
          originalUrl: url,
        );
      }
      return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
    }

    // ── github-store.org/app?repo=owner/repo ──────────────────────────
    if (host == 'github-store.org' || host == 'www.github-store.org') {
      final repoParam = uri.queryParameters['repo'];
      if (repoParam != null && repoParam.contains('/')) {
        final parts = repoParam.split('/');
        if (parts.length == 2 &&
            _isValidIdentifier(parts[0]) &&
            _isValidIdentifier(parts[1])) {
          return DeeplinkResult(
            type: DeeplinkType.repoDetails,
            owner: parts[0],
            repo: parts[1],
            originalUrl: url,
          );
        }
      }
      return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
    }

    return DeeplinkResult(type: DeeplinkType.unknown, originalUrl: url);
  }

  // ── Validation ───────────────────────────────────────────────────────────

  /// Check if a string is a valid GitHub owner or repo name identifier.
  ///
  /// Rules (from GitHub):
  /// - Only alphanumeric, hyphen, underscore, and dot characters.
  /// - Must not be empty.
  /// - Must not start or end with a hyphen or dot.
  /// - Maximum 39 characters for usernames, 100 for repo names.
  bool _isValidIdentifier(String name) {
    if (name.isEmpty) return false;
    if (name.length > 100) return false;
    // Must not start or end with hyphen/dot
    if (name.startsWith('-') ||
        name.startsWith('.') ||
        name.endsWith('-') ||
        name.endsWith('.')) {
      return false;
    }
    // Must not contain consecutive hyphens
    if (name.contains('--')) return false;
    return _identifierPattern.hasMatch(name);
  }
}
