import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/repository_model.dart';
import '../../../../shared/widgets/repository_card.dart' hide AnimatedBuilder;
import '../../../../core/router/app_router.dart';

/// A section displaying a list of repositories in a grid.
///
/// Handles loading, error, and empty states with shimmer skeletons.
/// Each section has a title, optional subtitle, and a "See All" button.
class RepoSection extends ConsumerWidget {
  const RepoSection({
    required this.title,
    required this.reposAsync,
    this.icon,
    this.subtitle,
    this.onSeeAll,
    this.maxItems = 6,
    this.errorMessage,
    super.key,
  });

  /// Section title (e.g. "🔥 Trending").
  final String title;

  /// Section icon.
  final IconData? icon;

  /// Section subtitle.
  final String? subtitle;

  /// Async value of repository list.
  final AsyncValue<List<RepositoryModel>> reposAsync;

  /// Callback when "See All" is tapped.
  final VoidCallback? onSeeAll;

  /// Maximum number of items to display.
  final int maxItems;

  /// Optional custom error message.
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        _buildHeader(theme),

        // ── Content ───────────────────────────────────────────────────────
        reposAsync.when(
          data: (repos) {
            if (repos.isEmpty) {
              return _buildEmptyState(theme);
            }
            final displayRepos = repos.take(maxItems).toList();
            return _buildGrid(context, displayRepos, theme);
          },
          loading: () => _buildShimmerGrid(theme),
          error: (error, stack) => _buildErrorState(theme, error),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton.icon(
              onPressed: onSeeAll,
              icon: Text(
                'See All',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              label: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<RepositoryModel> repos,
    ThemeData theme,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        childAspectRatio: 1.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: repos.length,
      itemBuilder: (context, index) {
        final repo = repos[index];
        return RepositoryCard(
          fullName: repo.fullName,
          description: repo.description ?? '',
          owner: repo.ownerLogin,
          repoName: repo.name,
          avatarUrl: repo.ownerAvatarUrl,
          language: repo.language,
          languageColor: repo.languageColor,
          stargazersCount: repo.stars,
          forksCount: repo.forks,
          topics: repo.topics,
          latestVersion: repo.latestReleaseTag,
          updatedAt: repo.pushedAt,
          isArchived: repo.isArchived,
          isFavorite: repo.isFavorited,
          isStarred: repo.isStarred,
          density: CardDensity.normal,
          showTopics: true,
          onTap: () {
            final parts = repo.fullName.split('/');
            if (parts.length == 2) {
              context.go(
                AppRoute.details.withParams({
                  'owner': parts[0],
                  'repo': parts[1],
                }),
              );
            }
          },
          onOwnerTap: () {
            context.go(
              AppRoute.devProfile.withParams({'username': repo.ownerLogin}),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerGrid(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          childAspectRatio: 1.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 3,
        itemBuilder: (context, index) {
          return _ShimmerCard(theme: theme);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No repositories found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Object error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Failed to load repositories',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                // Retry by invalidating
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder card for loading states.
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.theme});

  final ThemeData theme;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shimmer
            Row(
              children: [
                _shimmerCircle(16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerLine(width: 80, height: 12),
                      const SizedBox(height: 4),
                      _shimmerLine(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description shimmer
            _shimmerLine(height: 10),
            const SizedBox(height: 6),
            _shimmerLine(width: 200, height: 10),
            const SizedBox(height: 6),
            _shimmerLine(width: 160, height: 10),
            const Spacer(),
            // Footer shimmer
            Row(
              children: [
                _shimmerCircle(5),
                const SizedBox(width: 4),
                _shimmerLine(width: 40, height: 10),
                const SizedBox(width: 12),
                _shimmerLine(width: 30, height: 10),
                const SizedBox(width: 12),
                _shimmerLine(width: 30, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerLine({double? width, required double height}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  Widget _shimmerCircle(double radius) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}


