import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/repository_model.dart';
import '../../../core/router/app_router.dart';
import 'providers/search_provider.dart';

/// Search screen with real GitHub Search API integration.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-filled query from deep link or navigation.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  bool _initialSearchDone = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _scrollController = ScrollController()..addListener(_onScroll);

    // If we have an initial query from navigation, perform search immediately
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      Future.microtask(() => _submitQuery(widget.initialQuery!));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _submitQuery(String query) {
    if (query.trim().isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = query.trim();
  }

  void _loadMore() {
    if (ref.read(searchHasMoreProvider) && !ref.read(searchLoadingMoreProvider)) {
      ref.read(searchResultsNotifierProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = ref.watch(searchIsSearchingProvider);
    final items = ref.watch(searchResultsItemsProvider);
    final totalCount = ref.watch(searchTotalCountProvider);
    final hasMore = ref.watch(searchHasMoreProvider);
    final loadingMore = ref.watch(searchLoadingMoreProvider);
    final error = ref.watch(searchErrorProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedLanguage = ref.watch(searchLanguageFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(theme),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Language Filter',
            onSelected: (value) {
              ref.read(searchLanguageFilterProvider.notifier).state =
                  value == 'All' ? '' : value;
              // Re-trigger search with new filter
              if (query.isNotEmpty) {
                _submitQuery(query);
              }
            },
            itemBuilder: (_) => [
              'All', 'Dart', 'Python', 'JavaScript', 'TypeScript',
              'Java', 'Kotlin', 'Go', 'Rust', 'C++', 'Swift', 'Ruby', 'PHP',
            ]
                .map((lang) => PopupMenuItem(
                      value: lang,
                      child: Row(
                        children: [
                          if (selectedLanguage == (lang == 'All' ? '' : lang))
                            const Icon(Icons.check, size: 16)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(lang),
                        ],
                      ),
                    ))
                .toList(),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _searchController.clear();
                ref.read(searchResultsNotifierProvider.notifier).clearSearch();
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _buildSortChips(theme),
        ),
      ),
      body: query.isEmpty
          ? _buildEmptyState(theme)
          : isSearching
              ? _buildLoadingState()
              : error != null
                  ? _buildErrorState(theme, error)
                  : items.isEmpty
                      ? _buildNoResults(theme)
                      : _buildResultsList(theme, items, totalCount, hasMore, loadingMore),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
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
      onSubmitted: _submitQuery,
    );
  }

  Widget _buildSortChips(ThemeData theme) {
    final currentSort = ref.watch(searchSortProvider);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: searchSortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, value) = searchSortOptions[index];
          final isSelected = currentSort == value;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) {
              ref.read(searchSortProvider.notifier).state = value;
              final query = ref.read(searchQueryProvider);
              if (query.isNotEmpty) _submitQuery(query);
            },
          );
        },
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
            color: theme.colorScheme.outline.withOpacity(0.4),
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
            'Find repositories, users, code, and more',
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
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.error.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
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
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                final query = ref.read(searchQueryProvider);
                if (query.isNotEmpty) _submitQuery(query);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 48, color: theme.colorScheme.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or remove filters',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    ThemeData theme,
    List<RepositoryModel> items,
    int totalCount,
    bool hasMore,
    bool loadingMore,
  ) {
    return Column(
      children: [
        // Result count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '$totalCount results',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length + (loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildResultCard(theme, items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ThemeData theme, RepositoryModel repo) {
    final parts = repo.fullName.split('/');
    final owner = parts.length >= 2 ? parts[0] : '';
    final name = parts.length >= 2 ? parts[1] : repo.fullName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (parts.length == 2) {
            context.push(
              AppRoute.details.withParams({
                'owner': parts[0],
                'repo': parts[1],
              }),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + stars
              Row(
                children: [
                  // Owner avatar
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: repo.ownerAvatarUrl != null
                        ? NetworkImage(repo.ownerAvatarUrl!)
                        : null,
                    child: repo.ownerAvatarUrl == null
                        ? Text(
                            owner.isNotEmpty ? owner[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Full name
                  Expanded(
                    child: Text(
                      repo.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Stars
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline,
                            size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          repo.formattedStars,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Description
              if (repo.description != null && repo.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  repo.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Footer: language + forks + updated
              const SizedBox(height: 8),
              Row(
                children: [
                  // Language
                  if (repo.language != null && repo.language!.isNotEmpty) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _parseColor(repo.languageColor) ??
                            theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      repo.language!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Forks
                  Icon(Icons.fork_right,
                      size: 12, color: theme.colorScheme.outline),
                  const SizedBox(width: 2),
                  Text(
                    repo.formattedForks,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  // Updated time
                  if (repo.pushedAt != null) ...[
                    Icon(Icons.access_time,
                        size: 12, color: theme.colorScheme.outline),
                    const SizedBox(width: 2),
                    Text(
                      _timeAgo(repo.pushedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      final hex = colorStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }
}
