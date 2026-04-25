import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../constants/api_constants.dart';
import '../network/api_client.dart';

/// Result of starting the GitHub OAuth Device Flow.
class DeviceFlowResult {
  DeviceFlowResult({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  /// Opaque device code used for polling. Do not expose to the user.
  final String deviceCode;

  /// Short user code the user should enter at the verification URI.
  final String userCode;

  /// URL where the user should enter the user code to authorize.
  final String verificationUri;

  /// Number of seconds until the device code expires.
  final int expiresIn;

  /// Minimum number of seconds the client should wait between polling attempts.
  final int interval;

  /// Formatted expiration time.
  String get formattedExpiresIn {
    final minutes = expiresIn ~/ 60;
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours hours $remainingMinutes minutes';
  }

  @override
  String toString() =>
      'DeviceFlowResult(userCode: $userCode, uri: $verificationUri, '
      'expiresIn: $formattedExpiresIn)';
}

/// Errors that can occur during the OAuth Device Flow.
class AuthException implements Exception {
  const AuthException({
    required this.message,
    this.errorCode,
    this.uri,
  });

  final String message;
  final String? errorCode;
  final String? uri;

  /// Common error codes from GitHub's OAuth endpoint.
  bool get isAuthorizationPending => errorCode == 'authorization_pending';
  bool get isSlowDown => errorCode == 'slow_down';
  bool get isExpiredToken => errorCode == 'expired_token';
  bool get isAccessDenied => errorCode == 'access_denied';
  bool get isBadVerificationCode =>
      errorCode == 'bad_verification_code';

  @override
  String toString() =>
      'AuthException: $message${errorCode != null ? ' (code: $errorCode)' : ''}';
}

/// Service that manages GitHub OAuth Device Flow authentication.
///
/// The Device Flow is a two-step authentication process:
/// 1. Request a device code and show the user a verification URL + code.
/// 2. Poll the token endpoint until the user authorizes (or the code expires).
///
/// The token is stored locally in an encrypted file.
class AuthService {
  AuthService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // Token storage keys
  static const String _tokenFileName = 'gh_auth_token.dat';
  static const String _tokenVersion = 'v1';

  // State
  String? _cachedToken;
  bool _initialized = false;

  // ── Device Flow ─────────────────────────────────────────────────────────

  /// Start the GitHub OAuth Device Flow.
  ///
  /// Returns a [DeviceFlowResult] containing the device code, user code,
  /// and verification URI. The user must visit the URI and enter the code.
  ///
  /// After calling this method, use [pollForToken] to wait for authorization.
  ///
  /// Throws [AuthException] if the request fails.
  Future<DeviceFlowResult> startDeviceFlow() async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.deviceCodeUrl,
        data: {
          'client_id': ApiConstants.clientId,
          'scope': 'read:user,repo,notifications',
        },
        options: const _FormUrlEncodedOptions(),
      );

      final data = response.data;
      if (data == null) {
        throw const AuthException(
          message: 'Empty response from device code endpoint',
        );
      }

      // Validate required fields
      final deviceCode = data['device_code'] as String?;
      final userCode = data['user_code'] as String?;
      final verificationUri = data['verification_uri'] as String?;

      if (deviceCode == null ||
          userCode == null ||
          verificationUri == null) {
        throw const AuthException(
          message: 'Invalid response from device code endpoint',
        );
      }

      return DeviceFlowResult(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        expiresIn: data['expires_in'] as int? ?? 900,
        interval: data['interval'] as int? ?? 5,
      );
    } on DioException catch (e) {
      final message = _parseErrorResponse(e);
      throw AuthException(
        message: message,
        errorCode: 'DEVICE_FLOW_ERROR',
      );
    }
  }

  /// Poll the token endpoint until the user authorizes or an error occurs.
  ///
  /// [deviceCode] - The device code from [startDeviceFlow].
  /// [onPoll] - Optional callback invoked on each poll attempt.
  ///
  /// Returns the access token string when the user authorizes.
  ///
  /// Throws [AuthException] with specific error codes:
  /// - `authorization_pending` - User hasn't authorized yet (handled internally).
  /// - `slow_down` - Polling too fast, will retry with longer interval.
  /// - `expired_token` - The device code has expired.
  /// - `access_denied` - The user denied authorization.
  Future<String> pollForToken(
    String deviceCode, {
    int? initialInterval,
    void Function(int attempt)? onPoll,
  }) async {
    int interval = initialInterval ?? 5;
    int attempt = 0;
    final startTime = DateTime.now();
    // Default max wait is 15 minutes
    final maxWait = const Duration(minutes: 15);

    while (true) {
      attempt++;
      onPoll?.call(attempt);

      // Check timeout
      if (DateTime.now().difference(startTime) > maxWait) {
        throw const AuthException(
          message: 'Device flow polling timed out',
          errorCode: 'TIMEOUT',
        );
      }

      // Small delay before polling
      await Future.delayed(Duration(seconds: interval));

      try {
        final response = await _apiClient.post<Map<String, dynamic>>(
          ApiConstants.deviceTokenUrl,
          data: {
            'client_id': ApiConstants.clientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
          options: const _FormUrlEncodedOptions(),
        );

        final data = response.data;
        if (data == null) {
          throw const AuthException(
            message: 'Empty response from token endpoint',
          );
        }

        final error = data['error'] as String?;

        if (error != null) {
          switch (error) {
            case 'authorization_pending':
              // User hasn't authorized yet, continue polling
              continue;
            case 'slow_down':
              // GitHub wants us to slow down
              interval += 5;
              continue;
            case 'expired_token':
              throw const AuthException(
                message: 'Device code has expired. Please restart authentication.',
                errorCode: 'expired_token',
              );
            case 'access_denied':
              throw const AuthException(
                message: 'Authorization was denied by the user.',
                errorCode: 'access_denied',
              );
            case 'bad_verification_code':
              throw const AuthException(
                message: 'Invalid device code. Please restart authentication.',
                errorCode: 'bad_verification_code',
              );
            default:
              throw AuthException(
                message: 'OAuth error: $error',
                errorCode: error,
              );
          }
        }

        // Success! Extract the token
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) {
          throw const AuthException(
            message: 'No access token in response',
            errorCode: 'NO_TOKEN',
          );
        }

        // Persist the token
        await saveToken(token);
        _cachedToken = token;

        return token;
      } on AuthException {
        rethrow;
      } on DioException catch (e) {
        // Try to parse the error from the response body
        final message = _parseErrorResponse(e);
        if (message.contains('authorization_pending')) {
          continue;
        }
        throw AuthException(
          message: message,
          errorCode: 'POLL_ERROR',
        );
      }
    }
  }

  /// Start the device flow and poll for a token in a single call.
  ///
  /// [onUserCodeReady] - Called with the user code and verification URI.
  /// The caller should display these to the user.
  /// [onPoll] - Optional callback invoked on each poll attempt.
  ///
  /// Returns the access token string.
  ///
  /// Example:
  /// ```dart
  /// final token = await authService.authenticate(
  ///   onUserCodeReady: (code, uri) {
  ///     print('Go to $uri and enter code: $code');
  ///   },
  /// );
  /// ```
  Future<String> authenticate({
    required void Function(String userCode, String verificationUri)
        onUserCodeReady,
    void Function(int attempt)? onPoll,
  }) async {
    final flowResult = await startDeviceFlow();
    onUserCodeReady(flowResult.userCode, flowResult.verificationUri);

    return pollForToken(
      flowResult.deviceCode,
      initialInterval: flowResult.interval,
      onPoll: onPoll,
    );
  }

  // ── Token Management ────────────────────────────────────────────────────

  /// Save the access token to encrypted local storage.
  ///
  /// The token is XOR-encrypted with a device-specific key derived from
  /// the application support directory path. This is not military-grade
  /// encryption, but prevents casual reading of the token.
  Future<void> saveToken(String token) async {
    try {
      final file = await _getTokenFile();
      final key = await _deriveKey();
      final encrypted = _xorEncrypt(token, key);
      final payload = jsonEncode({
        'version': _tokenVersion,
        'token': encrypted,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
      await file.writeAsString(payload);
    } catch (e) {
      debugPrint('[AuthService] Failed to save token: $e');
      rethrow;
    }
  }

  /// Retrieve the saved access token from local storage.
  ///
  /// Returns `null` if no token is stored or it cannot be decrypted.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    try {
      final file = await _getTokenFile();
      if (!await file.exists()) return null;

      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;

      // Check version
      final version = data['version'] as String?;
      if (version != _tokenVersion) return null;

      final encrypted = data['token'] as String?;
      if (encrypted == null || encrypted.isEmpty) return null;

      final key = await _deriveKey();
      final token = _xorDecrypt(encrypted, key);

      if (token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to read token: $e');
    }

    return null;
  }

  /// Delete the stored access token.
  Future<void> clearToken() async {
    _cachedToken = null;
    try {
      final file = await _getTokenFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to clear token: $e');
    }
  }

  /// Check if the user is authenticated (has a stored token).
  Future<bool> isAuthenticated() async {
    if (!_initialized) {
      final token = await getToken();
      _initialized = true;
      return token != null;
    }
    return _cachedToken != null;
  }

  /// Initialize the auth service by loading the stored token.
  ///
  /// Call this during app startup. Returns true if a token was loaded.
  Future<bool> initialize() async {
    final token = await getToken();
    _initialized = true;
    if (token != null) {
      _apiClient.setAuthToken(token);
      return true;
    }
    return false;
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  Future<File> _getTokenFile() async {
    final dir = await _getAuthDirectory();
    return File(p.join(dir.path, _tokenFileName));
  }

  Future<Directory> _getAuthDirectory() async {
    if (Platform.isWindows) {
      final appDataDir =
          Directory(Platform.environment['APPDATA'] ?? r'C:\AppData\Roaming');
      final authDir = Directory(p.join(appDataDir.path, 'GitHubStore', 'auth'));
      if (!await authDir.exists()) await authDir.create(recursive: true);
      return authDir;
    } else if (Platform.isMacOS) {
      final appSupportDir = await getApplicationSupportDirectory();
      final authDir =
          Directory(p.join(appSupportDir.path, 'GitHubStore', 'auth'));
      if (!await authDir.exists()) await authDir.create(recursive: true);
      return authDir;
    } else if (Platform.isLinux) {
      final configDir = Directory(
        Platform.environment['XDG_CONFIG_HOME'] ??
            '${Platform.environment['HOME']}/.config',
      );
      final authDir =
          Directory(p.join(configDir.path, 'github-store', 'auth'));
      if (!await authDir.exists()) await authDir.create(recursive: true);
      return authDir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final authDir =
        Directory(p.join(appDir.path, 'GitHubStore', 'auth'));
    if (!await authDir.exists()) await authDir.create(recursive: true);
    return authDir;
  }

  /// Derive a device-specific encryption key from the app's storage path.
  Future<List<int>> _deriveKey() async {
    final dir = await _getAuthDirectory();
    final pathSeed = dir.path;
    final appIdentifier = 'github_store_desktop_v1_$pathSeed';
    return sha256.convert(utf8.encode(appIdentifier)).bytes.toList();
  }

  /// Simple XOR encryption for the token.
  String _xorEncrypt(String plainText, List<int> key) {
    final bytes = utf8.encode(plainText);
    final encrypted = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ key[i % key.length]);
    }
    return base64Encode(encrypted);
  }

  /// Simple XOR decryption.
  String _xorDecrypt(String cipherText, List<int> key) {
    final bytes = base64Decode(cipherText);
    final decrypted = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      decrypted.add(bytes[i] ^ key[i % key.length]);
    }
    return utf8.decode(decrypted);
  }

  /// Parse an error response from the OAuth endpoints.
  String _parseErrorResponse(DioException e) {
    try {
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response!.data as Map<String, dynamic>;
        return data['error_description'] as String? ??
            data['error'] as String? ??
            e.message ??
            'Unknown OAuth error';
      }
      if (e.response?.data is String) {
        final body = e.response!.data as String;
        if (body.isNotEmpty) return body;
      }
    } catch (_) {}

    return e.message ?? 'Unknown OAuth error';
  }
}

/// Custom Dio options that force form URL-encoded content type.
///
/// GitHub's OAuth endpoints require application/x-www-form-urlencoded.
class _FormUrlEncodedOptions extends Options {
  const _FormUrlEncodedOptions()
      : super(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Accept': 'application/json',
          },
        );
}
