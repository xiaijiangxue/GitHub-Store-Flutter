import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

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
  String _selectedType = 'repositories';
  String _selectedLanguage = '';
  bool _isSearching = false;

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _query = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            },
            itemBuilder: (_) => _languages
                .map((lang) => PopupMenuItem(
                      value: lang,
                      child: Text(lang),
                    ))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTypeChips(theme),
        ),
      ),
      body: _query.isEmpty
          ? _buildEmptyState(theme)
          : _isSearching
              ? _buildLoadingState()
              : _buildResults(theme),
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
      onSubmitted: _performSearch,
      onChanged: (value) => _query = value,
    );
  }

  Widget _buildTypeChips(ThemeData theme) {
    final types = ['repositories', 'users', 'code', 'issues'];
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final type = types[index];
            final isSelected = type == _selectedType;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedType = type),
            );
          },
        ),
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
            color: theme.colorScheme.outline.withOpacity( 0.4),
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

  Widget _buildResults(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return _buildResultCard(theme, index);
      },
    );
  }

  Widget _buildResultCard(ThemeData theme, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            _query.isNotEmpty ? _query[0].toUpperCase() : '?',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          '$_query/result-$index',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          'Sample result for "$_query" in $_selectedType',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        onTap: () => context.go(
          AppRoute.details.withParams({
            'owner': 'sample',
            'repo': 'result-$index',
          }),
        ),
      ),
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _query = query.trim();
      _isSearching = true;
    });
    // Simulate network delay then show results
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    });
  }
}
