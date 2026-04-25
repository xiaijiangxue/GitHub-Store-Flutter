import 'dart:io';

/// Detected Linux distribution family.
enum LinuxDistroFamily {
  /// Debian-based: Ubuntu, Debian, Linux Mint, Pop!_OS, elementary OS, etc.
  debian,

  /// Fedora/RHEL-based: Fedora, CentOS, RHEL, Rocky, AlmaLinux, etc.
  fedora,

  /// Arch-based: Arch Linux, Manjaro, EndeavourOS, Garuda, etc.
  arch,

  /// openSUSE-based: openSUSE Leap, openSUSE Tumbleweed.
  suse,

  /// Could not determine the distro family.
  unknown;

  static LinuxDistroFamily fromString(String value) {
    final lower = value.toLowerCase().trim();
    return switch (lower) {
      'debian' || 'ubuntu' || 'linuxmint' || 'pop_os' || 'elementary' ||
      'zorin' || 'kali' || 'parrot' || 'deepin' || 'lxde' ||
      'lmde' || 'steamos' =>
        LinuxDistroFamily.debian,
      'fedora' || 'rhel' || 'centos' || 'rocky' || 'almalinux' ||
      'ol' || 'nobara' || 'opensuse-leap' || 'opensuse-tumbleweed' =>
        LinuxDistroFamily.fedora,
      'arch' || 'manjaro' || 'endeavouros' || 'garuda' || 'cachyos' ||
      'artix' ||
      'kaos' =>
        LinuxDistroFamily.arch,
      'suse' || 'opensuse' =>
        LinuxDistroFamily.suse,
      _ => LinuxDistroFamily.unknown,
    };
  }

  /// Primary package manager for this distro family.
  String get packageManager => switch (this) {
        LinuxDistroFamily.debian => 'apt',
        LinuxDistroFamily.fedora => 'dnf',
        LinuxDistroFamily.arch => 'pacman',
        LinuxDistroFamily.suse => 'zypper',
        LinuxDistroFamily.unknown => 'unknown',
      };

  /// Package file extension supported by this distro.
  String get packageExtension => switch (this) {
        LinuxDistroFamily.debian => '.deb',
        LinuxDistroFamily.fedora => '.rpm',
        LinuxDistroFamily.arch => '.pkg.tar.zst',
        LinuxDistroFamily.suse => '.rpm',
        LinuxDistroFamily.unknown => '',
      };

  /// Install command template: `{command} install {filePath}`.
  List<String> installCommand(String filePath) => switch (this) {
        LinuxDistroFamily.debian => ['apt', 'install', '-y', filePath],
        LinuxDistroFamily.fedora => ['dnf', 'install', '-y', filePath],
        LinuxDistroFamily.arch => ['pacman', '-U', '--noconfirm', filePath],
        LinuxDistroFamily.suse => ['zypper', '--non-interactive', 'install', filePath],
        LinuxDistroFamily.unknown => [],
      };
}

/// Detailed information about the detected Linux distribution.
class LinuxDistroInfo {
  LinuxDistroInfo({
    this.id,
    this.idLike,
    this.name,
    this.versionId,
    this.version,
    this.prettyName,
    this.family = LinuxDistroFamily.unknown,
  });

  /// Distribution ID (e.g., "ubuntu", "fedora", "arch").
  final String? id;

  /// ID_LIKE field — parent distro IDs (e.g., "ubuntu" for Linux Mint).
  final String? idLike;

  /// Distribution name (e.g., "Ubuntu").
  final String? name;

  /// Version ID (e.g., "22.04").
  final String? versionId;

  /// Full version string (e.g., "22.04.3 LTS (Jammy Jellyfish)").
  final String? version;

  /// Pretty name (e.g., "Ubuntu 22.04.3 LTS").
  final String? prettyName;

  /// Detected distro family based on [id] and [idLike].
  final LinuxDistroFamily family;

  /// Whether we are running inside a Flatpak sandbox.
  bool get isFlatpakSandbox => id == 'flatpak';

  @override
  String toString() =>
      'LinuxDistroInfo(id: $id, family: ${family.name}, version: $versionId, '
      'prettyName: $prettyName)';
}

/// Detects the Linux distribution by reading /etc/os-release.
///
/// Falls back to /usr/lib/os-release if /etc/os-release doesn't exist.
/// Handles Flatpak sandboxes by checking /run/host/os-release.
class DistroDetector {
  DistroDetector._();

  /// Cached detection result to avoid repeated file reads.
  static LinuxDistroInfo? _cachedInfo;

  /// Detect and return the current Linux distribution information.
  ///
  /// Results are cached after the first call.
  static Future<LinuxDistroInfo> detect() async {
    if (_cachedInfo != null) return _cachedInfo!;

    _cachedInfo = await _detectInternal();
    return _cachedInfo!;
  }

  /// Clear the cached detection result.
  static void resetCache() {
    _cachedInfo = null;
  }

  static Future<LinuxDistroInfo> _detectInternal() async {
    final osRelease = await _readOsRelease();
    if (osRelease == null) {
      return LinuxDistroInfo(family: LinuxDistroFamily.unknown);
    }

    final id = osRelease['ID'] as String?;
    final idLike = osRelease['ID_LIKE'] as String?;
    final name = osRelease['NAME'] as String?;
    final versionId = osRelease['VERSION_ID'] as String?;
    final version = osRelease['VERSION'] as String?;
    final prettyName = osRelease['PRETTY_NAME'] as String?;

    // Determine family
    LinuxDistroFamily family = LinuxDistroFamily.unknown;

    // First check the direct ID
    if (id != null) {
      family = LinuxDistroFamily.fromString(id);
    }

    // If still unknown, check ID_LIKE (for derivatives like Linux Mint)
    if (family == LinuxDistroFamily.unknown && idLike != null) {
      final likeIds = idLike.split(RegExp(r'\s+'));
      for (final likeId in likeIds) {
        final detected = LinuxDistroFamily.fromString(likeId);
        if (detected != LinuxDistroFamily.unknown) {
          family = detected;
          break;
        }
      }
    }

    return LinuxDistroInfo(
      id: id,
      idLike: idLike,
      name: name,
      versionId: versionId,
      version: version,
      prettyName: prettyName,
      family: family,
    );
  }

  /// Parse /etc/os-release into a key-value map.
  ///
  /// Also checks /usr/lib/os-release and /run/host/os-release (Flatpak).
  static Future<Map<String, String>?> _readOsRelease() async {
    final paths = [
      '/etc/os-release',
      '/usr/lib/os-release',
      '/run/host/os-release', // Flatpak sandbox
    ];

    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        try {
          final contents = await file.readAsLines();
          return _parseOsRelease(contents);
        } catch (e) {
          stderr.writeln('[DistroDetector] Failed to read $path: $e');
          continue;
        }
      }
    }

    return null;
  }

  /// Parse the os-release file format (key=value pairs, some quoted).
  static Map<String, String> _parseOsRelease(List<String> lines) {
    final result = <String, String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final eqIndex = trimmed.indexOf('=');
      if (eqIndex == -1) continue;

      final key = trimmed.substring(0, eqIndex).trim();
      var value = trimmed.substring(eqIndex + 1).trim();

      // Remove surrounding quotes
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      result[key] = value;
    }
    return result;
  }
}
