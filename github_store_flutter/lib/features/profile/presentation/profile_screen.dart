import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// User profile screen showing auth status, stats, and navigation menu.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(profileStatsProvider);

    final isAuthenticated = authState == AuthState.authenticated;
    final stats = statsAsync.valueOrNull ?? const ProfileStats();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Profile'),
            actions: [
              if (isAuthenticated)
                IconButton(
                  icon: const Icon(Icons.logout_outlined),
                  tooltip: 'Sign Out',
                  onPressed: () => _confirmSignOut(context, ref),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ── Avatar & Info ─────────────────────────────────────
                  if (isAuthenticated && user != null)
                    _AuthenticatedHeader(
                      theme: theme,
                      user: user,
                      onSignOut: () => _confirmSignOut(context, ref),
                    )
                  else
                    _GuestHeader(
                      theme: theme,
                      onSignIn: () => context.go('/profile/auth'),
                    ),

                  const SizedBox(height: 28),

                  // ── Stats Grid ────────────────────────────────────────
                  _StatsGrid(stats: stats, theme: theme),

                  const SizedBox(height: 32),

                  // ── Menu Items ────────────────────────────────────────
                  _ProfileMenuItem(
                    icon: Icons.favorite_outline,
                    title: 'My Favorites',
                    subtitle: '${stats.favoritesCount} saved repos',
                    onTap: () => context.go('/favorites'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.star_outline,
                    title: 'Starred Repos',
                    subtitle: 'Your GitHub stars',
                    onTap: () => context.go('/starred'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.history,
                    title: 'Recently Viewed',
                    subtitle: '${stats.viewedCount} repos viewed',
                    onTap: () => context.go('/recently-viewed'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.apps_outlined,
                    title: 'My Apps',
                    subtitle: 'Installed applications',
                    onTap: () => context.go('/apps'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.download_outlined,
                    title: 'Downloads',
                    subtitle: '${stats.downloadedCount} downloads',
                    onTap: () => context.go('/download/_placeholder'),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'App preferences & configuration',
                    onTap: () => context.go('/settings'),
                  ),
                  const SizedBox(height: 8),
                  _ProfileMenuItem(
                    icon: Icons.favorite_outlined,
                    title: 'Sponsor',
                    subtitle: 'Support the project',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sponsor page coming soon!'),
                        ),
                      );
                    },
                  ),
                  _ProfileMenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Version 1.0.0+1',
                    onTap: () => _showAboutDialog(context),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? '
          'Your local data will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'GitHub Store',
      applicationVersion: '1.0.0+1',
      applicationIcon: const Icon(
        Icons.code,
        size: 48,
        color: Color(0xFF238636),
      ),
      children: [
        const Text(
          'A feature-rich GitHub desktop application for discovering, '
          'browsing, and managing GitHub repositories.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Open Source under the MIT License.',
        ),
      ],
    );
  }
}

// ── Authenticated User Header ──────────────────────────────────────────────

class _AuthenticatedHeader extends StatelessWidget {
  const _AuthenticatedHeader({
    required this.theme,
    required this.user,
    required this.onSignOut,
  });

  final ThemeData theme;
  final dynamic user; // UserModel
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 48,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: user.avatarUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(
                      Icons.person,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : Icon(
                  Icons.person,
                  size: 48,
                  color: theme.colorScheme.primary,
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

        // Login handle
        Text(
          '@${user.login}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Bio (if available)
        if (user.hasBio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              user.bio!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 20),

        // Sign out button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_outlined, size: 18),
            label: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }
}

// ── Guest Header ───────────────────────────────────────────────────────────

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({
    required this.theme,
    required this.onSignIn,
  });

  final ThemeData theme;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person_outline,
            size: 48,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Guest User',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to sync your data across devices',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Sign in button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSignIn,
            icon: Image.asset(
              'assets/icons/github_mark.png',
              width: 20,
              errorBuilder: (_, __, ___) => const Icon(Icons.code, size: 20),
            ),
            label: const Text('Sign in with GitHub'),
          ),
        ),
      ],
    );
  }
}

// ── Stats Grid ─────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.theme});

  final ProfileStats stats;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.download,
            label: 'Downloads',
            value: stats.downloadedCount,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.install_desktop_outlined,
            label: 'Installed',
            value: stats.installedCount,
            color: theme.colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.visibility_outlined,
            label: 'Viewed',
            value: stats.viewedCount,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite,
            label: 'Favorites',
            value: stats.favoritesCount,
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              _formatCount(value),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }
}

// ── Profile Menu Item ──────────────────────────────────────────────────────

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}
