import '../../../core/auth/auth_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/github_api.dart';

/// Repository for managing GitHub authentication.
///
/// Wraps the core [AuthService] and [GitHubApi] to provide a clean API
/// for authentication flows, user data fetching, and token management.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required ApiClient apiClient,
  })  : _authService = authService,
        _gitHubApi = GitHubApi(apiClient);

  final AuthService _authService;
  final GitHubApi _gitHubApi;

  // ── Device Flow ─────────────────────────────────────────────────────────

  /// Start the GitHub OAuth Device Flow.
  ///
  /// Returns a [DeviceFlowResult] containing the user code and verification
  /// URI. The user must visit the URI and enter the code to authorize.
  Future<DeviceFlowResult> startDeviceFlow() async {
    return _authService.startDeviceFlow();
  }

  /// Poll the token endpoint until the user authorizes or an error occurs.
  ///
  /// [deviceCode] - The device code from [startDeviceFlow].
  /// [initialInterval] - Initial polling interval in seconds.
  /// [onPoll] - Optional callback invoked on each poll attempt.
  ///
  /// Returns the access token string when the user authorizes.
  Future<String> pollForToken(
    String deviceCode, {
    int? initialInterval,
    void Function(int attempt)? onPoll,
  }) async {
    final token = await _authService.pollForToken(
      deviceCode,
      initialInterval: initialInterval,
      onPoll: onPoll,
    );

    // Set the token on the GitHub API client
    _gitHubApi.setAuthToken(token);

    return token;
  }

  /// Start the device flow and poll for a token in a single call.
  ///
  /// [onUserCodeReady] - Called with the user code and verification URI.
  /// [onPoll] - Optional callback invoked on each poll attempt.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> authenticate({
    required void Function(String userCode, String verificationUri)
        onUserCodeReady,
    void Function(int attempt)? onPoll,
  }) async {
    try {
      final token = await _authService.authenticate(
        onUserCodeReady: onUserCodeReady,
        onPoll: onPoll,
      );

      _gitHubApi.setAuthToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Token Management ────────────────────────────────────────────────────

  /// Check whether the user is currently authenticated.
  Future<bool> isAuthenticated() async {
    return _authService.isAuthenticated();
  }

  /// Initialize the auth service by loading any stored token.
  ///
  /// Returns true if a valid stored token was loaded.
  Future<bool> initialize() async {
    return _authService.initialize();
  }

  /// Get the current stored auth token.
  Future<String?> getToken() async {
    return _authService.getToken();
  }

  // ── User Data ───────────────────────────────────────────────────────────

  /// Get the authenticated user's profile from the GitHub API.
  Future<UserModel> getCurrentUser() async {
    return _gitHubApi.getCurrentUser();
  }

  // ── Logout ──────────────────────────────────────────────────────────────

  /// Log out by clearing the stored token and the API client token.
  Future<void> logout() async {
    await _authService.clearToken();
    _gitHubApi.clearAuthToken();
  }
}
