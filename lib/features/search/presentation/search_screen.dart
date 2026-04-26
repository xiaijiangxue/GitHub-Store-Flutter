import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/repository_model.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/repository_card.dart';
import 'providers/search_provider.dart';

/// Search screen with search input, filters, and results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-filled query from deep link or navigation.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  String _selectedLanguage = '';
  String _selectedSort = 'best_match';

  final _languages = [
    'All Languages',
    'Dart',
    'TypeScript',
    'JavaScript',
    'Python',
    'Rust',
    'Go',
    'Java',
    'C++',
    'C',
    'Swift',
    'Kotlin',
    'Ruby',
  ];

  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _query = widget.initialQuery ?? '';
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      // Auto-search when navigated with a query
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!.trim());
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = ref.watch(searchIsSearchingProvider);
    final searchResults = ref.watch(searchResultsNotifierProvider);
    final resultItems = ref.watch(searchResultsItemsProvider);
    final totalCount = ref.watch(searchTotalCountProvider);
    final hasMore = ref.watch(searchHasMoreProvider);
    final isLoadingMore = ref.watch(searchLoadingMoreProvider);
    final searchError = ref.watch(searchErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(theme),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onSelected: (value) {
              setState(() {
                _selectedLanguage = value == 'All Languages' ? '' : value;
              });
              // Re-search with new language filter
              ref.read(searchLanguageFilterProvider.notifier).state =
                  _selectedLanguage;
            },
            itemBuilder: (_) => _languages
                .map((lang) => PopupMenuItem(
                      value: lang,
                      child: Row(
                        children: [
                          if (_selectedLanguage == (lang == 'All Languages' ? '' : lang))
                            const Icon(Icons.check, size: 16),
                          if (_selectedLanguage == (lang == 'All Languages' ? '' : lang))
                            const SizedBox(width: 8),
                          Text(lang),
                        ],
                      ),
                    ))
                .toList(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (value) {
              setState(() => _selectedSort = value);
              ref.read(searchSortProvider.notifier).state = value;
            },
            itemBuilder: (_) => searchSortOptions
                .map((option) => PopupMenuItem(
                      value: option.$2,
                      child: Row(
                        children: [
                          if (_selectedSort == option.$2)
                            const Icon(Icons.check, size: 16),
                          if (_selectedSort == option.$2)
                            const SizedBox(width: 8),
                          Text(option.$1),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: !_hasSearched
          ? _buildEmptyState(theme)
          : isSearching && resultItems.isEmpty
              ? _buildLoadingState()
              : searchError != null && resultItems.isEmpty
                  ? _buildErrorState(theme, searchError)
                  : _buildResults(
                      theme,
                      resultItems,
                      totalCount,
                      isLoadingMore,
                      hasMore,
                    ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return SizedBox(
      width: 400,
      child: TextField(
        controller: _searchController,
        autofocus: widget.initialQuery == null,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search GitHub...',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: _performSearch,
        onChanged: (value) => _query = value,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Search GitHub',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find repositories, users, and more',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _performSearch(_query),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    ThemeData theme,
    List<RepositoryModel> items,
    int totalCount,
    bool isLoadingMore,
    bool hasMore,
  ) {
    final _scrollController = ScrollController();

    // Listen for scroll to bottom for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          hasMore &&
          !isLoadingMore) {
        ref.read(searchResultsNotifierProvider.notifier).loadNextPage();
      }
    });

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Result count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                '$totalCount results',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedLanguage.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedLanguage,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: items.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final repo = items[index];
              return _SearchResultCard(
                repo: repo,
                onTap: () {
                  final parts = repo.fullName.split('/');
                  if (parts.length == 2) {
                    context.push(
                      AppRoute.details.withParams({
                        'owner': parts[0],
                        'repo': parts[1],
                      }),
                    );
                  }
                },
                onOwnerTap: () {
                  context.push(
                    AppRoute.devProfile
                        .withParams({'username': repo.ownerLogin}),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _query = query.trim();
      _hasSearched = true;
    });

    // Update providers and trigger search
    ref.read(searchQueryProvider.notifier).state = query.trim();
    ref.read(searchLanguageFilterProvider.notifier).state = _selectedLanguage;
    ref.read(searchSortProvider.notifier).state = _selectedSort;
  }
}

/// Search result card displaying a repository.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.repo,
    required this.onTap,
    required this.onOwnerTap,
  });

  final RepositoryModel repo;
  final VoidCallback onTap;
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

                    // Stats
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
                        const SizedBox(width: 12),
                        // Forks
                        Icon(
                          Icons.fork_right,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatCount(repo.forks),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                ),
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
