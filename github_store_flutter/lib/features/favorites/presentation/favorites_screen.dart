import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/repository_model.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/repository_card.dart';
import 'providers/favorites_provider.dart';

/// Favorites screen showing bookmarked repositories with sort, search,
/// and unfavorite functionality.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _lastQuery = query;
    // Debounce the search
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text == query && mounted) {
        ref.read(favoritesSearchQueryProvider.notifier).state = query;
      }
    });
  }

  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: const Text(
          'Are you sure you want to remove all favorites? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(favoritesProvider.notifier).clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All favorites cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showUnfavoriteDialog(RepositoryModel repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Favorites'),
        content: Text('Remove ${repo.fullName} from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(favoritesProvider.notifier).removeFavorite(
            repo.ownerLogin,
            repo.name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${repo.fullName} removed from favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  void _showSortOptions() {
    final currentSort = ref.read(favoritesSortModeProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sort Favorites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ...FavoritesSortMode.values.map((mode) {
                final isSelected = mode == currentSort;
                return ListTile(
                  leading: Icon(
                    _getSortIcon(mode),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(mode.displayName),
                  trailing:
                      isSelected ? const Icon(Icons.check, size: 20) : null,
                  onTap: () {
                    ref.read(favoritesSortModeProvider.notifier).state = mode;
                    Navigator.of(context).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _getSortIcon(FavoritesSortMode mode) {
    return switch (mode) {
      FavoritesSortMode.name => Icons.sort_by_alpha,
      FavoritesSortMode.stars => Icons.star_outline,
      FavoritesSortMode.recentlyAdded => Icons.access_time,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoritesAsync = ref.watch(favoritesProvider);
    final showSearch = _showSearch;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            title: showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search favorites...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    onChanged: _onSearchChanged,
                  )
                : const Text('Favorites'),
            actions: [
              // Search toggle
              IconButton(
                icon: Icon(showSearch ? Icons.search_off : Icons.search),
                tooltip: showSearch ? 'Close search' : 'Search favorites',
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      ref.read(favoritesSearchQueryProvider.notifier).state = '';
                    }
                  });
                },
              ),
              // Sort
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onPressed: _showSortOptions,
              ),
              // Clear all
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _showClearAllDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Clear All', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Content ────────────────────────────────────────────────────
          favoritesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => SliverFillRemaining(
              child: _ErrorState(
                message: 'Failed to load favorites',
                error: error.toString(),
                onRetry: () => ref.invalidate(favoritesProvider),
              ),
            ),
            data: (favorites) {
              if (favorites.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    showSearch: showSearch || _lastQuery.isNotEmpty,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    childAspectRatio: 1.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final repo = favorites[index];
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
                        isFavorite: true,
                        isStarred: repo.isStarred,
                        latestVersion: repo.latestReleaseTag,
                        updatedAt: repo.updatedAt,
                        isArchived: repo.isArchived,
                        density: CardDensity.compact,
                        showTopics: false,
                        onTap: () => _navigateToDetails(repo),
                        onFavoriteToggle: () => _showUnfavoriteDialog(repo),
                        onStarToggle: null,
                        onOwnerTap: () => context.push(
                          AppRoute.devProfile.path
                              .replaceAll(':username', repo.ownerLogin),
                        ),
                      );
                    },
                    childCount: favorites.length,
                  ),
                ),
              );
            },
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.showSearch});

  final bool showSearch;

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
              showSearch ? Icons.search_off : Icons.bookmark_border_rounded,
              size: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              showSearch
                  ? 'No matching favorites'
                  : 'No favorites yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showSearch
                  ? 'Try a different search term'
                  : 'Browse repos and tap the bookmark icon to save favorites',
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
