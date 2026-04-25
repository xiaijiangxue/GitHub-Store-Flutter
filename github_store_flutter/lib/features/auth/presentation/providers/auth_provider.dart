import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/auth_repository.dart';

// Re-export shared providers
export '../../home/presentation/providers/home_provider.dart' show apiClientProvider;

// ── Auth State ────────────────────────────────────────────────────────────

/// States for the authentication flow.
enum AuthState {
  /// User is not authenticated.
  unauthenticated,

  /// Device flow is in progress (waiting for user to enter code).
  authenticating,

  /// User is authenticated.
  authenticated,

  /// An error occurred during authentication.
  error,
}

// ── Infrastructure Providers ──────────────────────────────────────────────

/// Provider for the auth service.
final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

/// Provider for the auth repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(
    authService: authService,
    apiClient: apiClient,
  );
});

// ── State Providers ───────────────────────────────────────────────────────

/// Current authentication state.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo, ref);
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._repo, this._ref)
      : super(AuthState.unauthenticated) {
    _checkExistingAuth();
  }

  final AuthRepository _repo;
  final Ref _ref;

  String? _deviceCode;
  String? _userCode;
  String? _verificationUri;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _pollingActive = false;

  /// The user code to display (set during device flow).
  String? get userCode => _userCode;

  /// The verification URI for the user to visit.
  String? get verificationUri => _verificationUri;

  /// Remaining seconds until the device code expires.
  int get remainingSeconds => _remainingSeconds;

  /// The last error message (set when state is AuthState.error).
  String? errorMessage;

  /// Check if there's an existing stored token.
  Future<void> _checkExistingAuth() async {
    try {
      final isAuth = await _repo.isAuthenticated();
      if (isAuth) {
        state = AuthState.authenticated;
        _ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      debugPrint('[AuthStateNotifier] Failed to check existing auth: $e');
    }
  }

  /// Start the authentication device flow.
  Future<void> login() async {
    try {
      state = AuthState.authenticating;
      errorMessage = null;

      final flowResult = await _repo.startDeviceFlow();

      _deviceCode = flowResult.deviceCode;
      _userCode = flowResult.userCode;
      _verificationUri = flowResult.verificationUri;
      _remainingSeconds = flowResult.expiresIn;

      // Start countdown timer
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _countdownTimer?.cancel();
            if (state == AuthState.authenticating) {
              errorMessage = 'Verification code expired. Please try again.';
              state = AuthState.error;
              _cleanup();
            }
          }
        },
      );

      // Start polling in a separate zone so it doesn't block
      _pollingActive = true;
      _startPolling(flowResult.deviceCode, flowResult.interval);
    } on AuthException catch (e) {
      errorMessage = e.message;
      state = AuthState.error;
      _cleanup();
    } catch (e) {
      errorMessage = 'Failed to start authentication: ${e.toString()}';
      state = AuthState.error;
      _cleanup();
    }
  }

  /// Poll the token endpoint until authorization completes or fails.
  Future<void> _startPolling(String deviceCode, int interval) async {
    while (_pollingActive) {
      // Wait before polling
      await Future.delayed(Duration(seconds: interval));

      if (!_pollingActive) break;

      try {
        final token = await _repo.pollForToken(
          deviceCode,
          onPoll: (_) {},
        );

        // Success!
        _pollingActive = false;
        _countdownTimer?.cancel();
        state = AuthState.authenticated;
        _ref.invalidate(currentUserProvider);
        _cleanup();
        return;
      } on AuthException catch (e) {
        if (e.isExpiredToken) {
          errorMessage = 'Verification code expired. Please try again.';
          state = AuthState.error;
          _cleanup();
          return;
        }
        if (e.isAccessDenied) {
          errorMessage = 'Authorization was denied.';
          state = AuthState.error;
          _cleanup();
          return;
        }
        if (e.isSlowDown) {
          interval += 5;
          continue;
        }
        if (e.isAuthorizationPending) {
          continue;
        }
        // Other errors
        errorMessage = e.message;
        state = AuthState.error;
        _cleanup();
        return;
      } catch (e) {
        // If no longer in authenticating state, stop
        if (state != AuthState.authenticating) {
          errorMessage = 'Authentication failed: ${e.toString()}';
          state = AuthState.error;
          _cleanup();
          return;
        }
        // Network error — wait and retry
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  /// Cancel the authentication flow.
  void cancelAuth() {
    _pollingActive = false;
    _countdownTimer?.cancel();
    state = AuthState.unauthenticated;
    errorMessage = null;
    _cleanup();
  }

  /// Log out the current user.
  Future<void> logout() async {
    await _repo.logout();
    state = AuthState.unauthenticated;
    errorMessage = null;
    _ref.invalidate(currentUserProvider);
  }

  /// Refresh the current user's profile data.
  Future<void> refreshUser() async {
    _ref.invalidate(currentUserProvider);
  }

  void _cleanup() {
    _deviceCode = null;
    _userCode = null;
    _verificationUri = null;
    _pollingActive = false;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingActive = false;
    super.dispose();
  }
}

// ── User Data Provider ────────────────────────────────────────────────────

/// Provider for the currently authenticated user's profile.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState != AuthState.authenticated) return null;

  try {
    final repo = ref.read(authRepositoryProvider);
    return repo.getCurrentUser();
  } catch (e) {
    debugPrint('[currentUserProvider] Failed to fetch user: $e');
    return null;
  }
});

/// Provider for the current auth token.
final authTokenProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState != AuthState.authenticated) return null;

  try {
    final repo = ref.read(authRepositoryProvider);
    return repo.getToken();
  } catch (_) {
    return null;
  }
});
