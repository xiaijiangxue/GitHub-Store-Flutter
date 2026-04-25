import 'dart:io';

/// Abstract platform service interface for OS-specific operations.
///
/// Implementations are provided for Windows, macOS, and Linux in
/// [InstallerService].
abstract class PlatformService {
  /// Human-readable platform name: "Windows", "macOS", "Linux".
  String get platformName;

  /// Detected CPU architecture: "x86_64", "arm64", etc.
  String get architecture;

  /// Install an application from a local file path.
  ///
  /// [filePath] is the absolute path to the installer package.
  /// [packageName] is an optional display name for the app.
  /// Returns `true` if installation succeeded.
  Future<bool> install(String filePath, {String? packageName});

  /// Uninstall an application by package name or identifier.
  ///
  /// [packageName] is the identifier or display name of the app.
  /// Returns `true` if uninstallation succeeded.
  Future<bool> uninstall(String packageName);

  /// Check whether an application is currently installed on the system.
  ///
  /// [packageName] is the identifier or display name to look for.
  Future<bool> isInstalled(String packageName);

  /// Show a native desktop notification.
  ///
  /// [title] is the notification title.
  /// [body] is the notification body text.
  Future<void> showNotification(String title, String body);

  /// Get the platform-appropriate downloads directory.
  ///
  /// Returns the path to the directory where downloaded files should be stored,
  /// or `null` if it cannot be determined.
  Future<String?> getDownloadsDir();

  /// Open the given [filePath] in the system file manager.
  Future<void> openFileLocation(String filePath);

  /// Launch an installed application.
  ///
  /// [packageName] or [executablePath] identifies the app to launch.
  Future<bool> launchApp({String? packageName, String? executablePath});
}

/// Factory that returns the correct [PlatformService] for the current OS.
PlatformService getPlatformService() {
  if (Platform.isWindows) {
    return WindowsPlatformService();
  } else if (Platform.isMacOS) {
    return MacOSPlatformService();
  } else if (Platform.isLinux) {
    return LinuxPlatformService();
  }
  throw UnsupportedError(
    'Platform ${Platform.operatingSystem} is not supported.',
  );
}

// ── Windows Implementation ─────────────────────────────────────────────────

class WindowsPlatformService implements PlatformService {
  @override
  String get platformName => 'Windows';

  @override
  String get architecture => _detectArchitecture();

  static String _detectArchitecture() {
    final env = Platform.environment;
    // Windows environment variable PROCESSOR_ARCHITECTURE
    final arch = env['PROCESSOR_ARCHITECTURE']?.toUpperCase() ?? '';
    if (arch == 'AMD64' || arch == 'X86_64') return 'x86_64';
    if (arch == 'ARM64') return 'arm64';
    if (arch == 'X86') return 'x86';
    return 'unknown';
  }

  @override
  Future<bool> install(String filePath, {String? packageName}) async {
    final ext = filePath.toLowerCase();
    try {
      if (ext.endsWith('.msi')) {
        // MSI installer: use msiexec for silent install
        final result = await Process.run(
          'msiexec',
          ['/i', filePath, '/quiet', '/norestart'],
        );
        if (result.exitCode == 3010) {
          // 3010 = ERROR_SUCCESS_REBOOT_REQUIRED — treated as success
          return true;
        }
        return result.exitCode == 0;
      } else if (ext.endsWith('.exe')) {
        // EXE installer: launch it
        final result = await Process.run('cmd', ['/c', 'start', '', filePath]);
        return result.exitCode == 0;
      } else if (ext.endsWith('.msix') || ext.endsWith('.appx')) {
        // MSIX/AppX packages
        final result = await Process.run(
          'powershell',
          ['-Command', 'Add-AppxPackage -Path "$filePath"'],
        );
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      stderr.writeln('[WindowsPlatformService] Install error: $e');
      return false;
    }
  }

  @override
  Future<bool> uninstall(String packageName) async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-AppxPackage *$packageName* | Remove-AppxPackage'],
      );
      return result.exitCode == 0;
    } catch (e) {
      stderr.writeln('[WindowsPlatformService] Uninstall error: $e');
      return false;
    }
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-AppxPackage *$packageName*'],
      );
      return (result.stdout as String).trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> showNotification(String title, String body) async {
    try {
      final escapedTitle = title.replaceAll('"', '\\"');
      final escapedBody = body.replaceAll('"', '\\"');
      await Process.run(
        'powershell',
        [
          '-Command',
          '[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, '
              'ContentType = WindowsRuntime] > \$null; '
              '\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent('
              '[Windows.UI.Notifications.ToastTemplateType]::ToastText02); '
              '\$textNodes = \$template.GetElementsByTagName("text"); '
              '\$textNodes.Item(0).AppendChild(\$template.CreateTextNode("$escapedTitle")) > \$null; '
              '\$textNodes.Item(1).AppendChild(\$template.CreateTextNode("$escapedBody")) > \$null; '
              '\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template); '
              '[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("GitHub Store")'
              '.Show(\$toast)',
        ],
      );
    } catch (e) {
      stderr.writeln('[WindowsPlatformService] Notification error: $e');
    }
  }

  @override
  Future<String?> getDownloadsDir() async {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final dir = Directory('$userProfile\\Downloads');
      if (await dir.exists()) return dir.path;
    }
    return null;
  }

  @override
  Future<void> openFileLocation(String filePath) async {
    try {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } catch (e) {
      stderr.writeln('[WindowsPlatformService] Open location error: $e');
    }
  }

  @override
  Future<bool> launchApp({String? packageName, String? executablePath}) async {
    try {
      if (executablePath != null) {
        await Process.run('cmd', ['/c', 'start', '', executablePath]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// ── macOS Implementation ───────────────────────────────────────────────────

class MacOSPlatformService implements PlatformService {
  @override
  String get platformName => 'macOS';

  @override
  String get architecture => _detectArchitecture();

  static String _detectArchitecture() {
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = (result.stdout as String).trim().toLowerCase();
      if (arch == 'arm64') return 'arm64';
      if (arch == 'x86_64') return 'x86_64';
      return arch;
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Future<bool> install(String filePath, {String? packageName}) async {
    final ext = filePath.toLowerCase();
    try {
      if (ext.endsWith('.dmg')) {
        return await _installDmg(filePath);
      } else if (ext.endsWith('.pkg')) {
        return await _installPkg(filePath);
      }
      return false;
    } catch (e) {
      stderr.writeln('[MacOSPlatformService] Install error: $e');
      return false;
    }
  }

  Future<bool> _installDmg(String filePath) async {
    // Mount the DMG
    final mountResult = await Process.run('hdiutil', ['attach', '-nobrowse', filePath]);
    if (mountResult.exitCode != 0) {
      stderr.writeln('[MacOS] Failed to mount DMG: ${mountResult.stderr}');
      return false;
    }

    // Parse mount point from output
    final output = mountResult.stdout as String;
    final mountPoint = _parseMountPoint(output);
    if (mountPoint == null) {
      stderr.writeln('[MacOS] Could not determine mount point.');
      await Process.run('hdiutil', ['detach', filePath]);
      return false;
    }

    try {
      // Look for .app inside the mounted volume
      final volumeDir = Directory(mountPoint);
      final apps = await volumeDir
          .list()
          .where((e) => e.path.toLowerCase().endsWith('.app'))
          .toList();

      if (apps.isEmpty) {
        stderr.writeln('[MacOS] No .app found in DMG at $mountPoint');
        return false;
      }

      // Copy the first .app to /Applications
      final appName = apps.first.path.split('/').last;
      final destPath = '/Applications/$appName';

      final copyResult = await Process.run('cp', ['-R', apps.first.path, destPath]);
      return copyResult.exitCode == 0;
    } finally {
      // Always detach the DMG
      await Process.run('hdiutil', ['detach', mountPoint]);
    }
  }

  String? _parseMountPoint(String output) {
    final lines = output.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('/Volumes/') && !trimmed.contains('Apple_HFS')) {
        return trimmed;
      }
    }
    // Fallback: try tab-separated format
    for (final line in lines) {
      if (line.contains('/Volumes/')) {
        final parts = line.split(RegExp(r'\s+'));
        for (final part in parts) {
          if (part.startsWith('/Volumes/')) return part;
        }
      }
    }
    return null;
  }

  Future<bool> _installPkg(String filePath) async {
    final result = await Process.run(
      'installer',
      ['-pkg', filePath, '-target', '/'],
    );
    if (result.exitCode != 0) {
      stderr.writeln('[MacOS] Package install failed: ${result.stderr}');
    }
    return result.exitCode == 0;
  }

  @override
  Future<bool> uninstall(String packageName) async {
    try {
      // Try to find and remove .app from /Applications
      final result = await Process.run('rm', ['-rf', '/Applications/$packageName.app']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    try {
      final path = '/Applications/$packageName.app';
      return await Directory(path).exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showNotification(String title, String body) async {
    try {
      final escapedTitle = title.replaceAll('"', '\\"');
      final escapedBody = body.replaceAll('"', '\\"');
      await Process.run(
        'osascript',
        [
          '-e',
          'display notification "$escapedBody" with title "$escapedTitle"',
        ],
      );
    } catch (e) {
      stderr.writeln('[MacOSPlatformService] Notification error: $e');
    }
  }

  @override
  Future<String?> getDownloadsDir() async {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final dir = Directory('$home/Downloads');
      if (await dir.exists()) return dir.path;
    }
    return null;
  }

  @override
  Future<void> openFileLocation(String filePath) async {
    try {
      final dir = File(filePath).parent;
      await Process.run('open', [dir.path]);
    } catch (e) {
      stderr.writeln('[MacOSPlatformService] Open location error: $e');
    }
  }

  @override
  Future<bool> launchApp({String? packageName, String? executablePath}) async {
    try {
      if (executablePath != null) {
        final result = await Process.run('open', [executablePath]);
        return result.exitCode == 0;
      }
      if (packageName != null) {
        final result = await Process.run('open', ['-a', packageName]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// ── Linux Implementation ───────────────────────────────────────────────────

class LinuxPlatformService implements PlatformService {
  @override
  String get platformName => 'Linux';

  @override
  String get architecture => _detectArchitecture();

  static String _detectArchitecture() {
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = (result.stdout as String).trim().toLowerCase();
      if (arch == 'x86_64' || arch == 'amd64') return 'x86_64';
      if (arch == 'aarch64' || arch == 'arm64') return 'arm64';
      if (arch == 'i386' || arch == 'i686') return 'x86';
      return arch;
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Future<bool> install(String filePath, {String? packageName}) async {
    final ext = filePath.toLowerCase();
    try {
      if (ext.endsWith('.deb')) {
        return await _installDeb(filePath);
      } else if (ext.endsWith('.rpm')) {
        return await _installRpm(filePath);
      } else if (ext.endsWith('.pkg.tar.zst') || ext.endsWith('.pkg.tar.xz')) {
        return await _installPacman(filePath);
      } else if (ext.endsWith('.appimage')) {
        return await _installAppImage(filePath);
      } else if (ext.endsWith('.flatpak') || ext.endsWith('.flatpakref')) {
        return await _installFlatpak(filePath);
      } else if (ext.endsWith('.snap')) {
        return await _installSnap(filePath);
      }
      return false;
    } catch (e) {
      stderr.writeln('[LinuxPlatformService] Install error: $e');
      return false;
    }
  }

  Future<bool> _installDeb(String filePath) async {
    // Try apt first (Debian/Ubuntu)
    var result = await Process.run('apt', ['install', '-y', filePath]);
    if (result.exitCode == 0) return true;

    // Fallback: dpkg
    result = await Process.run('dpkg', ['-i', filePath]);
    if (result.exitCode == 0) return true;

    // Try to fix broken deps
    await Process.run('apt', ['install', '-f', '-y']);
    return false;
  }

  Future<bool> _installRpm(String filePath) async {
    // Try dnf first (Fedora)
    var result = await Process.run('dnf', ['install', '-y', filePath]);
    if (result.exitCode == 0) return true;

    // Fallback: yum
    result = await Process.run('yum', ['install', '-y', filePath]);
    if (result.exitCode == 0) return true;

    // Fallback: zypper (openSUSE)
    result = await Process.run('zypper', ['install', '-y', filePath]);
    if (result.exitCode == 0) return true;

    // Last resort: rpm directly
    result = await Process.run('rpm', ['-i', filePath]);
    return result.exitCode == 0;
  }

  Future<bool> _installPacman(String filePath) async {
    final result = await Process.run('pacman', ['-U', '--noconfirm', filePath]);
    return result.exitCode == 0;
  }

  Future<bool> _installAppImage(String filePath) async {
    // Make executable and move to ~/Applications or ~/bin
    final home = Platform.environment['HOME'] ?? '/tmp';
    final appImagesDir = Directory('$home/Applications');
    if (!await appImagesDir.exists()) {
      await appImagesDir.create(recursive: true);
    }

    final fileName = filePath.split('/').last;
    final destPath = '${appImagesDir.path}/$fileName';

    // Copy to Applications dir
    final copyResult = await Process.run('cp', [filePath, destPath]);
    if (copyResult.exitCode != 0) return false;

    // Make executable
    final chmodResult = await Process.run('chmod', ['+x', destPath]);
    return chmodResult.exitCode == 0;
  }

  Future<bool> _installFlatpak(String filePath) async {
    final result = await Process.run('flatpak', ['install', '--user', '-y', filePath]);
    return result.exitCode == 0;
  }

  Future<bool> _installSnap(String filePath) async {
    final result = await Process.run('snap', ['install', filePath]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> uninstall(String packageName) async {
    // Try multiple package managers
    final commands = [
      ['apt', ['remove', '-y', packageName]],
      ['dpkg', ['-r', packageName]],
      ['dnf', ['remove', '-y', packageName]],
      ['yum', ['remove', '-y', packageName]],
      ['pacman', ['-R', '--noconfirm', packageName]],
      ['flatpak', ['uninstall', '-y', packageName]],
      ['snap', ['remove', packageName]],
    ];

    for (final entry in commands) {
      try {
        final result = await Process.run(entry[0], entry[1] as List<String>);
        if (result.exitCode == 0) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Future<bool> isInstalled(String packageName) async {
    final commands = [
      ['dpkg', ['-s', packageName]],
      ['rpm', ['-q', packageName]],
      ['pacman', ['-Q', packageName]],
      ['flatpak', ['list', '--app', '--columns=name']],
      ['snap', ['list', packageName]],
    ];

    for (final entry in commands) {
      try {
        final result = await Process.run(entry[0], entry[1] as List<String>);
        if (result.exitCode == 0) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Future<void> showNotification(String title, String body) async {
    try {
      final escapedTitle = title.replaceAll('"', '\\"');
      final escapedBody = body.replaceAll('"', '\\"');
      await Process.run(
        'notify-send',
        ['$escapedTitle', '$escapedBody', '--app-name=GitHub Store'],
      );
    } catch (e) {
      stderr.writeln('[LinuxPlatformService] Notification error: $e');
    }
  }

  @override
  Future<String?> getDownloadsDir() async {
    final xdg = Platform.environment['XDG_DOWNLOAD_DIR'];
    if (xdg != null && xdg.isNotEmpty) {
      // Expand ~ in path
      final home = Platform.environment['HOME'] ?? '';
      final expanded = xdg.replaceAll('~', home);
      if (await Directory(expanded).exists()) return expanded;
    }

    final home = Platform.environment['HOME'];
    if (home != null) {
      final dir = Directory('$home/Downloads');
      if (await dir.exists()) return dir.path;
    }
    return null;
  }

  @override
  Future<void> openFileLocation(String filePath) async {
    try {
      final dir = File(filePath).parent;
      await Process.run('xdg-open', [dir.path]);
    } catch (e) {
      stderr.writeln('[LinuxPlatformService] Open location error: $e');
    }
  }

  @override
  Future<bool> launchApp({String? packageName, String? executablePath}) async {
    try {
      if (executablePath != null) {
        final result = await Process.run(executablePath, []);
        return result.exitCode == 0;
      }
      if (packageName != null) {
        final result = await Process.run('xdg-open', [packageName]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
