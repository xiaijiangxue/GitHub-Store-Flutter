import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/repository_model.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/repository_card.dart';
import 'providers/starred_provider.dart';

/// Starred repositories screen.
///
/// Displays the authenticated user's starred repos from GitHub with
/// infinite scroll pagination, unstar functionality, and auth gating.
class StarredScreen extends ConsumerStatefulWidget {
  const StarredScreen({super.key});

  @override
  ConsumerState<StarredScreen> createState() => _StarredScreenState();
}

class _StarredScreenState extends ConsumerState<StarredScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        ref.read(starredHasMoreProvider) &&
        !ref.read(starredLoadingMoreProvider)) {
      ref.read(starredReposProvider.notifier).loadMore();
    }
  }

  Future<void> _showUnstarDialog(RepositoryModel repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unstar Repository'),
        content: Text('Unstar ${repo.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unstar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(starredReposProvider.notifier).unstar(
              repo.ownerLogin,
              repo.name,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unstarred ${repo.fullName}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unstar: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _navigateToDetails(RepositoryModel repo) {
    context.push(
      AppRoute.details.path
          .replaceAll(':owner', repo.ownerLogin)
          .replaceAll(':repo', repo.name),
    );
  }

  void _navigateToProfile() {
    context.push(AppRoute.profile.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starredRepo = ref.watch(starredRepositoryProvider);

    // Check authentication
    if (!starredRepo.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Starred Repos'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to see your starred repos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your GitHub account to view and manage '
                  'your starred repositories.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _navigateToProfile,
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign In with GitHub'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Authenticated — show starred repos
    final starredAsync = ref.watch(starredReposProvider);
    final isLoading = ref.watch(starredLoadingProvider);
    final isLoadingMore = ref.watch(starredLoadingMoreProvider);
    final hasMore = ref.watch(starredHasMoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred Repos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () => ref.invalidate(starredReposProvider),
          ),
        ],
      ),
      body: starredAsync.when(
        loading: () => _buildLoadingShimmer(theme),
        error: (error, stackTrace) => _ErrorState(
          message: 'Failed to load starred repos',
          error: error.toString(),
          onRetry: () => ref.invalidate(starredReposProvider),
        ),
        data: (repos) {
          if (repos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 72,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No starred repos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Repositories you star on GitHub will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(starredReposProvider);
              // Wait for the refresh to complete
              await ref.read(starredReposProvider.future);
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              itemCount: repos.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= repos.length) {
                  // Loading more indicator
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: isLoadingMore
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }

                final repo = repos[index];
                return _StarredListItem(
                  repo: repo,
                  onTap: () => _navigateToDetails(repo),
                  onUnstar: () => _showUnstarDialog(repo),
                  onOwnerTap: () => context.push(
                    AppRoute.devProfile.path
                        .replaceAll(':username', repo.ownerLogin),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 10,
      itemBuilder: (context, index) {
        return _ShimmerListItem(theme: theme);
      },
    );
  }
}

// ── Starred List Item ──────────────────────────────────────────────────────

class _StarredListItem extends StatelessWidget {
  const _StarredListItem({
    required this.repo,
    required this.onTap,
    required this.onUnstar,
    required this.onOwnerTap,
  });

  final RepositoryModel repo;
  final VoidCallback onTap;
  final VoidCallback onUnstar;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: onOwnerTap,
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: repo.ownerAvatarUrl != null
                      ? NetworkImage(repo.ownerAvatarUrl!)
                      : null,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: repo.ownerAvatarUrl == null
                      ? Text(
                          repo.ownerLogin.isNotEmpty
                              ? repo.ownerLogin[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Owner / Name
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onOwnerTap,
                          child: Text(
                            repo.ownerLogin,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          ' / ',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            repo.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Description
                    if (repo.description != null &&
                        repo.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        repo.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Stats row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Language
                        if (repo.language != null &&
                            repo.language!.isNotEmpty) ...[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _parseColor(repo.languageColor),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            repo.language!,
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Stars
                        const Icon(
                          Icons.star_outline,
                          size: 14,
                          color: Color(0xFFE3B341),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(repo.stars),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Unstar button
              const SizedBox(width: 8),
              Column(
                children: [
                  const SizedBox(height: 2),
                  IconButton(
                    icon: const Icon(Icons.star, color: Color(0xFFE3B341)),
                    tooltip: 'Unstar',
                    onPressed: onUnstar,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

// ── Shimmer Loading Item ───────────────────────────────────────────────────

class _ShimmerListItem extends StatefulWidget {
  const _ShimmerListItem({required this.theme});

  final ThemeData theme;

  @override
  State<_ShimmerListItem> createState() => _ShimmerListItemState();
}

class _ShimmerListItemState extends State<_ShimmerListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.theme.colorScheme.surfaceContainerHighest;
    final highlightColor = widget.theme.colorScheme.surface;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shimmer avatar
            _ShimmerBox(
              controller: _controller,
              width: 40,
              height: 40,
              borderRadius: 20,
              baseColor: baseColor,
              highlightColor: highlightColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title line
                  _ShimmerBox(
                    controller: _controller,
                    width: double.infinity,
                    height: 14,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                  const SizedBox(height: 6),
                  // Description line 1
                  _ShimmerBox(
                    controller: _controller,
                    width: double.infinity,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                  const SizedBox(height: 4),
                  // Description line 2
                  _ShimmerBox(
                    controller: _controller,
                    width: 180,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                  const SizedBox(height: 8),
                  // Stats
                  _ShimmerBox(
                    controller: _controller,
                    width: 100,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.controller,
    required this.width,
    required this.height,
    required this.baseColor,
    required this.highlightColor,
    this.borderRadius = 4,
  });

  final AnimationController controller;
  final double width;
  final double height;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final offset = controller.value * width * 1.5;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (offset - 0.3 * width).clamp(0.0, 1.0),
                offset.clamp(0.0, 1.0),
                (offset + 0.3 * width).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
