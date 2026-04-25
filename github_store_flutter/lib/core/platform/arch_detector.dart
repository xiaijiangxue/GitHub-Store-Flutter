import 'dart:io';

/// Detected CPU architecture.
enum Architecture {
  x86_64,
  arm64,
  x86,
  arm,
  unknown;

  /// Friendly display name.
  String get displayName => switch (this) {
        Architecture.x86_64 => 'x86_64 (64-bit)',
        Architecture.arm64 => 'ARM64',
        Architecture.x86 => 'x86 (32-bit)',
        Architecture.arm => 'ARM',
        Architecture.unknown => 'Unknown',
      };

  /// Short name.
  String get shortName => switch (this) {
        Architecture.x86_64 => 'x86_64',
        Architecture.arm64 => 'arm64',
        Architecture.x86 => 'x86',
        Architecture.arm => 'arm',
        Architecture.unknown => 'unknown',
      };

  /// Map a raw architecture string to an [Architecture] enum value.
  static Architecture fromString(String raw) {
    final lower = raw.toLowerCase().trim();
    return switch (lower) {
      'x86_64' || 'amd64' || 'x64' || 'ia64' || 'x86-64' => Architecture.x86_64,
      'arm64' || 'aarch64' || 'armv8' || 'armv8l' => Architecture.arm64,
      'i386' || 'i686' || 'x86' => Architecture.x86,
      'armv7' || 'armv7l' || 'armhf' || 'arm' => Architecture.arm,
      _ => Architecture.unknown,
    };
  }
}

/// Detects the CPU architecture of the current system.
///
/// Uses multiple detection strategies:
/// 1. `uname -m` via [Process.run]
/// 2. [Platform.version] parsing (Dart VM)
/// 3. Environment variables (Windows: PROCESSOR_ARCHITECTURE)
class ArchDetector {
  ArchDetector._();

  /// Cached detection result.
  static Architecture? _cachedArch;

  /// Detect and return the current CPU architecture.
  ///
  /// Results are cached after the first call.
  static Future<Architecture> detect() async {
    if (_cachedArch != null) return _cachedArch!;

    _cachedArch = await _detectInternal();
    return _cachedArch!;
  }

  /// Clear the cached detection result.
  static void resetCache() {
    _cachedArch = null;
  }

  /// Synchronous detection (uses only cached value or [Platform]).
  ///
  /// Falls back to [Architecture.unknown] if detection fails.
  static Architecture detectSync() {
    if (_cachedArch != null) return _cachedArch!;

    // Try Dart VM
    final fromDart = _detectFromDartVm();
    if (fromDart != Architecture.unknown) {
      _cachedArch = fromDart;
      return fromDart;
    }

    // Try environment (sync-safe for Windows)
    if (Platform.isWindows) {
      final fromEnv = _detectFromWindowsEnv();
      if (fromEnv != Architecture.unknown) {
        _cachedArch = fromEnv;
        return fromEnv;
      }
    }

    return Architecture.unknown;
  }

  static Future<Architecture> _detectInternal() async {
    // Strategy 1: uname -m (Unix systems)
    if (!Platform.isWindows) {
      try {
        final result = await Process.run('uname', ['-m']);
        if (result.exitCode == 0) {
          final output = (result.stdout as String).trim();
          final arch = Architecture.fromString(output);
          if (arch != Architecture.unknown) return arch;
        }
      } catch (_) {}
    }

    // Strategy 2: Dart VM version string
    final fromDart = _detectFromDartVm();
    if (fromDart != Architecture.unknown) return fromDart;

    // Strategy 3: Environment variables
    if (Platform.isWindows) {
      final fromEnv = _detectFromWindowsEnv();
      if (fromEnv != Architecture.unknown) return fromEnv;
    }

    return Architecture.unknown;
  }

  /// Detect architecture from Dart's [Platform.version] string.
  ///
  /// Example: "3.2.0 (stable) ... on "linux_x64""
  /// Example: "3.2.0 (stable) ... on "macos_arm64""
  static Architecture _detectFromDartVm() {
    final version = Platform.version;
    // Find the "on" platform string
    final onMatch = RegExp(r'on\s+"([^"]+)"').firstMatch(version);
    if (onMatch != null) {
      final platformStr = onMatch.group(1)!;
      // Extract the arch part (after underscore)
      final parts = platformStr.split('_');
      if (parts.length >= 2) {
        return Architecture.fromString(parts.last);
      }
    }

    // Fallback: check for keywords in the version string
    if (version.contains('arm64') || version.contains('aarch64')) {
      return Architecture.arm64;
    }
    if (version.contains('x64') || version.contains('x86_64') || version.contains('amd64')) {
      return Architecture.x86_64;
    }
    if (version.contains('ia32') || version.contains('x86')) {
      return Architecture.x86;
    }

    return Architecture.unknown;
  }

  /// Detect architecture from Windows environment variables.
  static Architecture _detectFromWindowsEnv() {
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.toUpperCase();
    if (arch == null) return Architecture.unknown;

    return switch (arch) {
      'AMD64' || 'X86_64' => Architecture.x86_64,
      'ARM64' => Architecture.arm64,
      'X86' => Architecture.x86,
      _ => Architecture.unknown,
    };
  }
}
