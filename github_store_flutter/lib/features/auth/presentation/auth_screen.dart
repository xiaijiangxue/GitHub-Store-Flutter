import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/models/user_model.dart';
import '../providers/auth_provider.dart';

/// GitHub authentication screen.
///
/// Handles the complete OAuth Device Flow:
/// 1. Display instructions and a user code
/// 2. Poll for authorization with a countdown timer
/// 3. Show success/error states
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  Timer? _countdownDisplayTimer;
  int _displayedSeconds = 0;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      if (authState == AuthState.authenticated) {
        ref.read(currentUserProvider);
      }
    });
  }

  @override
  void dispose() {
    _countdownDisplayTimer?.cancel();
    super.dispose();
  }

  /// Starts a 1-second UI timer that reads [remainingSeconds] from the
  /// notifier so the countdown is visible without rebuilding the notifier.
  void _startCountdownDisplay() {
    _countdownDisplayTimer?.cancel();
    final notifier = ref.read(authStateProvider.notifier);
    _displayedSeconds = notifier.remainingSeconds;

    _countdownDisplayTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          _countdownDisplayTimer?.cancel();
          return;
        }
        final authState = ref.read(authStateProvider);
        if (authState != AuthState.authenticating) {
          _countdownDisplayTimer?.cancel();
          return;
        }
        setState(() {
          _displayedSeconds =
              ref.read(authStateProvider.notifier).remainingSeconds;
        });
      },
    );
  }

  Future<void> _copyCode() async {
    final notifier = ref.read(authStateProvider.notifier);
    final code = notifier.userCode;
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startLogin() async {
    await ref.read(authStateProvider.notifier).login();
    if (mounted) {
      _startCountdownDisplay();
    }
  }

  Future<void> _cancelLogin() async {
    _countdownDisplayTimer?.cancel();
    ref.read(authStateProvider.notifier).cancelAuth();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? '
          'Your starred repos sync and higher API rate limits will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _countdownDisplayTimer?.cancel();
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  String _formatCountdown(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final userAsync = ref.watch(currentUserProvider);
    final notifier = ref.read(authStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Account'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── GitHub Logo ───────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    Icons.code,
                    size: 40,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // ── State-based content ───────────────────────────────────
                switch (authState) {
                  AuthState.unauthenticated =>
                    _buildUnauthenticated(theme),
                  AuthState.authenticating =>
                    _buildAuthenticating(theme, notifier),
                  AuthState.authenticated =>
                    _buildAuthenticated(theme, userAsync),
                  AuthState.error => _buildError(theme, notifier),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Unauthenticated ─────────────────────────────────────────────────────

  Widget _buildUnauthenticated(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Sign in to GitHub',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Connect your GitHub account to sync starred repos '
          'and get higher API rate limits (5000 req/hour instead of 60).',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Benefits list
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BenefitItem(
                icon: Icons.star_outline,
                title: 'Sync Starred Repos',
                subtitle: 'Access your GitHub stars directly in the app',
                theme: theme,
              ),
              const SizedBox(height: 12),
              _BenefitItem(
                icon: Icons.speed_outlined,
                title: 'Higher Rate Limits',
                subtitle: '5,000 API requests/hour vs 60 unauthenticated',
                theme: theme,
              ),
              const SizedBox(height: 12),
              _BenefitItem(
                icon: Icons.visibility_off_outlined,
                title: 'Private Repos',
                subtitle: 'Browse and install from your private repositories',
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Sign in button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startLogin,
            icon: const Icon(Icons.login),
            label: const Text('Sign in with GitHub'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Authenticating ──────────────────────────────────────────────────────

  Widget _buildAuthenticating(ThemeData theme, AuthStateNotifier notifier) {
    final userCode = notifier.userCode;
    final verificationUri = notifier.verificationUri;

    return Column(
      children: [
        Text(
          'Verify Your Account',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the code below at GitHub to authorize this app.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Step 1
        _StepCard(
          stepNumber: 1,
          title: 'Go to github.com/login/device',
          theme: theme,
        ),
        const SizedBox(height: 12),

        // Step 2: User code
        _StepCard(
          stepNumber: 2,
          title: 'Enter this code:',
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Large code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userCode ?? '',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      onPressed: _codeCopied ? null : _copyCode,
                      icon: Icon(
                        _codeCopied ? Icons.check : Icons.copy,
                        size: 18,
                      ),
                      tooltip: 'Copy code',
                    ),
                  ],
                ),
              ),
            ],
          ),
          theme: theme,
        ),
        const SizedBox(height: 12),

        // Step 3: Wait
        _StepCard(
          stepNumber: 3,
          title: 'Authorize and wait for confirmation',
          theme: theme,
        ),
        const SizedBox(height: 24),

        // Countdown timer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: _displayedSeconds < 120
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              'Expires in ${_formatCountdown(_displayedSeconds)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _displayedSeconds < 120
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Polling indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Waiting for authorization...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Cancel button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancelLogin,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Authenticated ───────────────────────────────────────────────────────

  Widget _buildAuthenticated(
      ThemeData theme, AsyncValue<UserModel?> userAsync) {
    return userAsync.when(
      loading: () => const Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(),
          ),
          SizedBox(height: 24),
          Text('Loading profile...'),
        ],
      ),
      error: (error, _) => Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                ref.read(authStateProvider.notifier).refreshUser(),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (user) {
        if (user == null) {
          return Column(
            children: [
              Text(
                'Authenticated',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're signed in!",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Avatar
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              CircleAvatar(
                radius: 48,
                backgroundImage:
                    CachedNetworkImageProvider(user.avatarUrl!),
              )
            else
              CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.login[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Name
            Text(
              user.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.login}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (user.hasBio) ...[
              const SizedBox(height: 8),
              Text(
                user.bio!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 24),

            // Success message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "You're signed in! You now have access to higher "
                      "API rate limits and can sync your starred repositories.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────

  Widget _buildError(ThemeData theme, AuthStateNotifier notifier) {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Authentication Failed',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          notifier.errorMessage ?? 'An unknown error occurred',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(authStateProvider.notifier).cancelAuth(),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _startLogin,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.title,
    this.child,
    required this.theme,
  });

  final int stepNumber;
  final String title;
  final Widget? child;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
