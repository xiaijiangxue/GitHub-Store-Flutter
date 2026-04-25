import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'arch_detector.dart';
import 'distro_detector.dart';
import 'platform_service.dart';

/// Install method for a given file type.
enum InstallMethod {
  /// Windows MSI installer.
  msi,

  /// Windows EXE installer.
  exe,

  /// Windows MSIX package.
  msix,

  /// Windows AppX package.
  appx,

  /// macOS DMG disk image.
  dmg,

  /// macOS PKG installer.
  pkg,

  /// Debian/Ubuntu package.
  deb,

  /// RPM package (Fedora, SUSE).
  rpm,

  /// Arch Linux package.
  pkgTarZst,

  /// AppImage (portable Linux).
  appimage,

  /// Flatpak package.
  flatpak,

  /// Snap package.
  snap,

  /// Generic / unknown.
  unknown;

  /// Detect install method from file extension.
  static InstallMethod fromFilePath(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.msi')) return InstallMethod.msi;
    if (lower.endsWith('.exe')) return InstallMethod.exe;
    if (lower.endsWith('.msix')) return InstallMethod.msix;
    if (lower.endsWith('.appx')) return InstallMethod.appx;
    if (lower.endsWith('.dmg')) return InstallMethod.dmg;
    if (lower.endsWith('.pkg')) return InstallMethod.pkg;
    if (lower.endsWith('.deb')) return InstallMethod.deb;
    if (lower.endsWith('.rpm')) return InstallMethod.rpm;
    if (lower.endsWith('.pkg.tar.zst')) return InstallMethod.pkgTarZst;
    if (lower.endsWith('.pkg.tar.xz')) return InstallMethod.pkgTarZst;
    if (lower.endsWith('.appimage')) return InstallMethod.appimage;
    if (lower.endsWith('.flatpak') || lower.endsWith('.flatpakref')) {
      return InstallMethod.flatpak;
    }
    if (lower.endsWith('.snap')) return InstallMethod.snap;
    return InstallMethod.unknown;
  }

  /// Human-readable label.
  String get label => switch (this) {
        InstallMethod.msi => 'MSI Installer',
        InstallMethod.exe => 'EXE Installer',
        InstallMethod.msix => 'MSIX Package',
        InstallMethod.appx => 'AppX Package',
        InstallMethod.dmg => 'DMG Disk Image',
        InstallMethod.pkg => 'PKG Installer',
        InstallMethod.deb => 'DEB Package',
        InstallMethod.rpm => 'RPM Package',
        InstallMethod.pkgTarZst => 'Arch Package',
        InstallMethod.appimage => 'AppImage',
        InstallMethod.flatpak => 'Flatpak',
        InstallMethod.snap => 'Snap',
        InstallMethod.unknown => 'Unknown',
      };

  /// Whether this method is supported on the current platform.
  bool get isSupportedOnCurrentPlatform {
    if (Platform.isWindows) {
      return this == InstallMethod.msi ||
          this == InstallMethod.exe ||
          this == InstallMethod.msix ||
          this == InstallMethod.appx;
    }
    if (Platform.isMacOS) {
      return this == InstallMethod.dmg || this == InstallMethod.pkg;
    }
    if (Platform.isLinux) {
      return this == InstallMethod.deb ||
          this == InstallMethod.rpm ||
          this == InstallMethod.pkgTarZst ||
          this == InstallMethod.appimage ||
          this == InstallMethod.flatpak ||
          this == InstallMethod.snap;
    }
    return false;
  }

  /// Icon data for UI display.
  int get iconCodePoint => switch (this) {
        InstallMethod.msi || InstallMethod.exe || InstallMethod.msix || InstallMethod.appx => 0xE900, // windows
        InstallMethod.dmg || InstallMethod.pkg => 0xE901, // apple
        InstallMethod.deb => 0xE902, // debian
        InstallMethod.rpm => 0xE903, // fedora
        InstallMethod.pkgTarZst => 0xE904, // arch
        InstallMethod.appimage || InstallMethod.flatpak || InstallMethod.snap => 0xE905, // linux
        InstallMethod.unknown => 0xE906, // unknown
      };
}

/// Result of an installation attempt.
class InstallResult {
  const InstallResult({
    required this.success,
    this.exitCode,
    this.output,
    this.error,
    this.method,
    this.command,
  });

  /// Whether the installation succeeded.
  final bool success;

  /// Process exit code (null if process wasn't started).
  final int? exitCode;

  /// Standard output from the install command.
  final String? output;

  /// Error message if installation failed.
  final String? error;

  /// The install method used.
  final InstallMethod? method;

  /// The command that was executed.
  final String? command;

  @override
  String toString() =>
      'InstallResult(success: $success, method: ${method?.label}, '
      'exitCode: $exitCode, error: $error)';
}

/// Callback type for receiving real-time log lines during installation.
typedef InstallLogCallback = void Function(String line, {bool isError});

/// High-level installer service that selects the correct platform-specific
/// installer based on the file type and current OS.
///
/// Provides streaming log output via [InstallLogCallback] and returns
/// an [InstallResult] when complete.
class InstallerService {
  InstallerService({PlatformService? platformService})
      : _platformService = platformService ?? getPlatformService();

  final PlatformService _platformService;
  Process? _activeProcess;

  /// Whether an installation is currently in progress.
  bool get isInstalling => _activeProcess != null;

  /// The currently active platform service.
  PlatformService get platformService => _platformService;

  /// Install a file at [filePath] with optional [packageName].
  ///
  /// [onLog] receives real-time log lines during installation.
  /// Returns [InstallResult] when complete.
  ///
  /// Throws [StateError] if an installation is already in progress.
  Future<InstallResult> install(
    String filePath, {
    String? packageName,
    InstallLogCallback? onLog,
  }) async {
    if (isInstalling) {
      throw StateError('An installation is already in progress.');
    }

    final method = InstallMethod.fromFilePath(filePath);
    onLog?.call('Detected install method: ${method.label}');
    onLog?.call('Platform: ${_platformService.platformName}');

    if (!method.isSupportedOnCurrentPlatform) {
      final msg = '${method.label} is not supported on ${_platformService.platformName}';
      onLog?.call(msg, isError: true);
      return InstallResult(
        success: false,
        error: msg,
        method: method,
      );
    }

    // Verify file exists
    final file = File(filePath);
    if (!await file.exists()) {
      final msg = 'File not found: $filePath';
      onLog?.call(msg, isError: true);
      return InstallResult(
        success: false,
        error: msg,
        method: method,
      );
    }

    final fileSize = await file.length();
    onLog?.call('File size: ${_formatBytes(fileSize)}');

    try {
      final result = await _runInstallCommand(
        filePath,
        method,
        packageName: packageName,
        onLog: onLog,
      );

      if (result.success) {
        onLog?.call('✓ Installation completed successfully.');
      } else {
        onLog?.call('✗ Installation failed (exit code: ${result.exitCode}).', isError: true);
      }

      return result;
    } catch (e) {
      final msg = 'Installation error: $e';
      onLog?.call(msg, isError: true);
      return InstallResult(
        success: false,
        error: msg,
        method: method,
      );
    }
  }

  /// Cancel the currently running installation.
  void cancel() {
    _activeProcess?.kill();
    _activeProcess = null;
  }

  /// Run the platform-specific install command with streaming output.
  Future<InstallResult> _runInstallCommand(
    String filePath,
    InstallMethod method, {
    String? packageName,
    InstallLogCallback? onLog,
  }) async {
    late List<String> command;
    String? workingDir;

    switch (method) {
      case InstallMethod.msi:
        command = ['msiexec', '/i', filePath, '/quiet', '/norestart'];
        onLog?.call('Running: msiexec /i "$filePath" /quiet /norestart');
      case InstallMethod.exe:
        command = ['cmd', '/c', 'start', '', filePath];
        onLog?.call('Launching installer: $filePath');
        // EXE installers typically launch their own GUI; we fire and forget.
        final result = await Process.run('cmd', ['/c', 'start', '', filePath]);
        return InstallResult(
          success: result.exitCode == 0,
          exitCode: result.exitCode,
          output: result.stdout.toString(),
          error: result.stderr.toString(),
          method: method,
          command: 'cmd /c start "" "$filePath"',
        );
      case InstallMethod.msix:
      case InstallMethod.appx:
        command = ['powershell', '-Command', 'Add-AppxPackage -Path "$filePath"'];
        onLog?.call('Running: Add-AppxPackage -Path "$filePath"');
      case InstallMethod.dmg:
        return await _installDmg(filePath, onLog: onLog);
      case InstallMethod.pkg:
        command = ['installer', '-pkg', filePath, '-target', '/'];
        onLog?.call('Running: installer -pkg "$filePath" -target /');
      case InstallMethod.deb:
        command = ['apt', 'install', '-y', filePath];
        onLog?.call('Running: apt install -y "$filePath"');
      case InstallMethod.rpm:
        command = ['dnf', 'install', '-y', filePath];
        onLog?.call('Running: dnf install -y "$filePath"');
      case InstallMethod.pkgTarZst:
        command = ['pacman', '-U', '--noconfirm', filePath];
        onLog?.call('Running: pacman -U --noconfirm "$filePath"');
      case InstallMethod.appimage:
        return await _installAppImage(filePath, onLog: onLog);
      case InstallMethod.flatpak:
        command = ['flatpak', 'install', '--user', '-y', filePath];
        onLog?.call('Running: flatpak install --user -y "$filePath"');
      case InstallMethod.snap:
        command = ['snap', 'install', filePath];
        onLog?.call('Running: snap install "$filePath"');
      case InstallMethod.unknown:
        return InstallResult(
          success: false,
          error: 'Unknown file type. Cannot determine install method.',
          method: method,
        );
    }

    return await _executeProcess(
      command,
      method: method,
      onLog: onLog,
      workingDirectory: workingDir,
    );
  }

  /// Execute a process and stream its output to the log callback.
  Future<InstallResult> _executeProcess(
    List<String> command, {
    required InstallMethod method,
    InstallLogCallback? onLog,
    String? workingDirectory,
  }) async {
    final commandStr = command.join(' ');
    onLog?.call('Executing: $commandStr');

    try {
      _activeProcess = await Process.start(
        command.first,
        command.skip(1).toList(),
        workingDirectory: workingDirectory,
      );

      final outputBuffer = StringBuffer();
      final errorBuffer = StringBuffer();

      // Stream stdout
      _activeProcess!.stdout
          .transform(const SystemEncoding().decoder)
          .listen(
        (data) {
          outputBuffer.write(data);
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              onLog?.call(line.trim());
            }
          }
        },
      );

      // Stream stderr
      _activeProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen(
        (data) {
          errorBuffer.write(data);
          final lines = data.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              onLog?.call(line.trim(), isError: true);
            }
          }
        },
      );

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      return InstallResult(
        success: exitCode == 0,
        exitCode: exitCode,
        output: outputBuffer.toString(),
        error: errorBuffer.toString().isNotEmpty
            ? errorBuffer.toString()
            : null,
        method: method,
        command: commandStr,
      );
    } catch (e) {
      _activeProcess = null;
      return InstallResult(
        success: false,
        error: 'Failed to start process: $e',
        method: method,
        command: commandStr,
      );
    }
  }

  /// Special DMG installation: mount → copy .app → unmount.
  Future<InstallResult> _installDmg(
    String filePath, {
    InstallLogCallback? onLog,
  }) async {
    onLog?.call('Mounting DMG image...');

    // Mount
    final mountResult = await Process.run(
      'hdiutil',
      ['attach', '-nobrowse', '-plist', filePath],
    );

    if (mountResult.exitCode != 0) {
      final err = mountResult.stderr.toString();
      onLog?.call('Failed to mount DMG: $err', isError: true);
      return InstallResult(
        success: false,
        exitCode: mountResult.exitCode,
        error: err,
        method: InstallMethod.dmg,
      );
    }

    // Parse mount point
    final mountOutput = mountResult.stdout.toString();
    final mountPoint = _parseDmgMountPoint(mountOutput);
    if (mountPoint == null) {
      onLog?.call('Could not determine DMG mount point.', isError: true);
      // Try to detach as cleanup
      await Process.run('hdiutil', ['detach', filePath]);
      return InstallResult(
        success: false,
        error: 'Could not determine DMG mount point.',
        method: InstallMethod.dmg,
      );
    }

    onLog?.call('Mounted at: $mountPoint');

    try {
      // Find .app bundles
      final volumeDir = Directory(mountPoint);
      final apps = <String>[];
      await for (final entity in volumeDir.list()) {
        if (entity.path.toLowerCase().endsWith('.app')) {
          apps.add(entity.path);
        }
      }

      if (apps.isEmpty) {
        onLog?.call('No .app bundle found in DMG.', isError: true);
        return InstallResult(
          success: false,
          error: 'No .app found in DMG.',
          method: InstallMethod.dmg,
        );
      }

      final appName = apps.first.split('/').last;
      final destPath = '/Applications/$appName';

      onLog?.call('Copying $appName to /Applications...');

      final copyResult = await Process.run('cp', ['-R', apps.first, destPath]);

      if (copyResult.exitCode != 0) {
        onLog?.call('Failed to copy: ${copyResult.stderr}', isError: true);
        return InstallResult(
          success: false,
          exitCode: copyResult.exitCode,
          error: copyResult.stderr.toString(),
          method: InstallMethod.dmg,
        );
      }

      return InstallResult(
        success: true,
        exitCode: 0,
        output: 'Installed $appName to /Applications',
        method: InstallMethod.dmg,
        command: 'hdiutil attach → cp -R → hdiutil detach',
      );
    } finally {
      onLog?.call('Unmounting DMG...');
      await Process.run('hdiutil', ['detach', mountPoint]);
    }
  }

  /// Parse the mount point from hdiutil output.
  String? _parseDmgMountPoint(String output) {
    // hdiutil with -plist returns XML, but without it returns text
    // Try text parsing first
    final lines = output.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('/Volumes/') && !trimmed.contains('Apple_')) {
        return trimmed;
      }
    }
    // Tab/space-separated format
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

  /// Special AppImage installation: copy + chmod.
  Future<InstallResult> _installAppImage(
    String filePath, {
    InstallLogCallback? onLog,
  }) async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final appImagesDir = Directory('$home/Applications');

    if (!await appImagesDir.exists()) {
      onLog?.call('Creating ~/Applications directory...');
      await appImagesDir.create(recursive: true);
    }

    final fileName = filePath.split('/').last;
    final destPath = '${appImagesDir.path}/$fileName';

    onLog?.call('Copying AppImage to ${appImagesDir.path}...');

    final copyResult = await Process.run('cp', [filePath, destPath]);
    if (copyResult.exitCode != 0) {
      return InstallResult(
        success: false,
        exitCode: copyResult.exitCode,
        error: copyResult.stderr.toString(),
        method: InstallMethod.appimage,
      );
    }

    onLog?.call('Setting executable permissions...');
    final chmodResult = await Process.run('chmod', ['+x', destPath]);
    if (chmodResult.exitCode != 0) {
      return InstallResult(
        success: false,
        exitCode: chmodResult.exitCode,
        error: chmodResult.stderr.toString(),
        method: InstallMethod.appimage,
      );
    }

    return InstallResult(
      success: true,
      exitCode: 0,
      output: 'AppImage installed to $destPath',
      method: InstallMethod.appimage,
      command: 'cp → chmod +x',
    );
  }

  /// Get the recommended install method for the current platform and distro.
  ///
  /// Useful for suggesting which asset to download.
  static Future<InstallMethod?> getRecommendedMethod() async {
    if (Platform.isWindows) {
      return InstallMethod.exe; // Most common on Windows
    }
    if (Platform.isMacOS) {
      return InstallMethod.dmg; // Most common on macOS
    }
    if (Platform.isLinux) {
      final distro = await DistroDetector.detect();
      return switch (distro.family) {
        LinuxDistroFamily.debian => InstallMethod.deb,
        LinuxDistroFamily.fedora => InstallMethod.rpm,
        LinuxDistroFamily.arch => InstallMethod.pkgTarZst,
        LinuxDistroFamily.suse => InstallMethod.rpm,
        LinuxDistroFamily.unknown => InstallMethod.appimage,
      };
    }
    return null;
  }

  /// Get the current architecture for asset matching.
  static Future<Architecture> getCurrentArchitecture() {
    return ArchDetector.detect();
  }

  /// Format bytes to a human-readable string.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
