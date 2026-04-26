import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../presentation/providers/home_provider.dart';
import '../presentation/widgets/platform_filter_bar.dart';
import '../presentation/widgets/trending_section.dart';

/// Home screen showing trending repos, hot releases, most popular,
/// and category browsing with platform filtering.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(homeRefreshProvider)();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              title: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GitHub Store',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              actions: [
                // Search icon
                IconButton(
                  icon: const Icon(Icons.search_outlined),
                  tooltip: 'Search',
                  onPressed: () => context.push(AppRoute.search.path),
                ),
                // Refresh button (for Desktop where pull-to-refresh isn't natural)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () async {
                    await ref.read(homeRefreshProvider)();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifications',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications coming soon!'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ── Search Bar (navigates to search screen) ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildSearchBar(theme),
              ),
            ),

            // ── Platform Filter Bar ─────────────────────────────────────
            const SliverToBoxAdapter(
              child: PlatformFilterBar(),
            ),

            // ── Category Chips Row ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildCategoryChips(theme),
            ),

            // ── Trending Section ────────────────────────────────────────
            SliverToBoxAdapter(
              child: RepoSection(
                title: '🔥 Trending',
                subtitle: 'Most starred repos this week',
                icon: Icons.trending_up,
                reposAsync: ref.watch(homeTrendingProvider),
                onSeeAll: () {
                  // Navigate to a full trending view
                  context.push(AppRoute.search.path);
                },
                onRetry: () => ref.invalidate(homeTrendingProvider),
                maxItems: 6,
                errorMessage: 'Failed to load trending repositories',
              ),
            ),

            // ── Hot Releases Section ────────────────────────────────────
            SliverToBoxAdapter(
              child: RepoSection(
                title: '⚡ Hot Releases',
                subtitle: 'Latest notable releases',
                icon: Icons.new_releases_outlined,
                reposAsync: ref.watch(homeHotReleasesProvider),
                onSeeAll: () {
                  context.push(AppRoute.search.path);
                },
                onRetry: () => ref.invalidate(homeHotReleasesProvider),
                maxItems: 6,
                errorMessage: 'Failed to load hot releases',
              ),
            ),

            // ── Most Popular Section ────────────────────────────────────
            SliverToBoxAdapter(
              child: RepoSection(
                title: '⭐ Most Popular',
                subtitle: 'All-time most starred repositories',
                icon: Icons.star_outline,
                reposAsync: ref.watch(homePopularProvider),
                onSeeAll: () {
                  context.push(AppRoute.search.path);
                },
                onRetry: () => ref.invalidate(homePopularProvider),
                maxItems: 6,
                errorMessage: 'Failed to load popular repositories',
              ),
            ),

            // ── Bottom spacing ──────────────────────────────────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  /// Tappable search bar that navigates to the search screen.
  Widget _buildSearchBar(ThemeData theme) {
    return InkWell(
      onTap: () => context.push(AppRoute.search.path),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor ??
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Search repositories, apps, developers...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Ctrl+K',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal scrolling topic category chips.
  Widget _buildCategoryChips(ThemeData theme) {
    final categoriesAsync = ref.watch(homeCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryChip(
                category: category,
                onTap: () {
                  // Navigate to search with topic query
                  if (category.topicKeywords.isNotEmpty) {
                    final topicQuery = category.topicKeywords.first;
                    context.go(
                      '${AppRoute.search.path}?q=topic:$topicQuery',
                    );
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => Container(
            width: 100,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// A single category chip widget.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.onTap,
  });

  final dynamic category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extract name and color from the category map or model
    final String name = category is Map
        ? (category['name'] as String? ?? '')
        : category.name as String;
    final String? color =
        category is Map ? category['color'] as String? : category.color as String?;

    Color chipColor;
    if (color != null && color.isNotEmpty) {
      try {
        final hex = color.replaceFirst('#', '');
        chipColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {
        chipColor = theme.colorScheme.primary;
      }
    } else {
      chipColor = theme.colorScheme.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chipColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: chipColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
