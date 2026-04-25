import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/models/search_result_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/github_store_api.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../data/search_repository.dart';

// ── Search Repository Provider ────────────────────────────────────────────

/// Provider for the search repository.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final storeApi = ref.watch(githubStoreApiProvider);
  final cache = ref.watch(cacheManagerProvider);
  final db = ref.watch(databaseProvider);
  return SearchRepository(
    storeApi: storeApi,
    cache: cache,
    database: db,
  );
});

// ── Search State Providers ────────────────────────────────────────────────

/// Current search query text.
final searchQueryProvider = StateProvider<String>((ref) {
  return '';
});

/// Whether a search is currently in progress.
final searchIsSearchingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Platform filter for search.
final searchPlatformFilterProvider = StateProvider<String>((ref) {
  return '';
});

/// Language filter for search.
final searchLanguageFilterProvider = StateProvider<String>((ref) {
  return '';
});

/// Sort field for search results.
final searchSortProvider = StateProvider<String>((ref) {
  return 'best_match';
});

/// Sort order (asc/desc) for search results.
final searchSortOrderProvider = StateProvider<String>((ref) {
  return 'desc';
});

/// Current page for pagination.
final searchCurrentPageProvider = StateProvider<int>((ref) {
  return 1;
});

/// Whether there are more pages to load.
final searchHasMoreProvider = StateProvider<bool>((ref) {
  return false;
});

/// Total result count from the last search.
final searchTotalCountProvider = StateProvider<int>((ref) {
  return 0;
});

/// Error message from the last search (null if no error).
final searchErrorProvider = StateProvider<String?>((ref) {
  return null;
});

// ── Search Results Provider ───────────────────────────────────────────────

/// Accumulated search result items (all pages combined).
final searchResultsItemsProvider =
    StateProvider<List<RepositoryModel>>((ref) {
  return [];
});

/// Whether more pages are being loaded.
final searchLoadingMoreProvider = StateProvider<bool>((ref) {
  return false;
});

// ── Debounce Logic ────────────────────────────────────────────────────────

/// Provider that manages debounced search execution.
///
/// When the query changes, it waits 300ms before triggering the actual search.
final searchDebouncerProvider = Provider<AsyncNotifierProvider<
    SearchDebouncerNotifier, SearchResultModel>>(
  () => searchResultsNotifierProvider,
);

/// Main search results notifier with debounce support.
final searchResultsNotifierProvider =
    AsyncNotifierProvider<SearchResultsNotifier, SearchResultModel>(
  SearchResultsNotifier.new,
);

class SearchResultsNotifier extends AsyncNotifier<SearchResultModel> {
  Timer? _debounceTimer;
  CancelToken? _cancelToken;

  @override
  Future<SearchResultModel> build() async {
    // Watch for query changes and trigger debounced search
    ref.listen(searchQueryProvider, (previous, next) {
      _debouncedSearch();
    });

    // Watch filter changes and re-search
    ref.listen(searchPlatformFilterProvider, (_, __) => _debouncedSearch());
    ref.listen(searchLanguageFilterProvider, (_, __) => _debouncedSearch());
    ref.listen(searchSortProvider, (_, __) => _debouncedSearch());
    ref.listen(searchSortOrderProvider, (_, __) => _debouncedSearch());

    return SearchResultModel.empty();
  }

  /// Debounce search by 300ms.
  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  /// Execute the search with current filters.
  Future<void> _performSearch() async {
    final query = ref.read(searchQueryProvider);
    if (query.trim().isEmpty) {
      ref.read(searchResultsItemsProvider.notifier).state = [];
      ref.read(searchTotalCountProvider.notifier).state = 0;
      ref.read(searchHasMoreProvider.notifier).state = false;
      ref.read(searchCurrentPageProvider.notifier).state = 1;
      ref.read(searchErrorProvider.notifier).state = null;
      state = AsyncData(SearchResultModel.empty());
      return;
    }

    ref.read(searchIsSearchingProvider.notifier).state = true;
    ref.read(searchErrorProvider.notifier).state = null;
    ref.read(searchCurrentPageProvider.notifier).state = 1;
    ref.read(searchResultsItemsProvider.notifier).state = [];

    _cancelToken = CancelToken();

    try {
      final repo = ref.read(searchRepositoryProvider);
      final sort = _mapSortField(ref.read(searchSortProvider));
      final platform = ref.read(searchPlatformFilterProvider);
      final language = ref.read(searchLanguageFilterProvider);
      final order = ref.read(searchSortOrderProvider);

      final result = await repo.search(
        query,
        platform: platform.isEmpty ? null : platform,
        language: language.isEmpty ? null : language,
        sort: sort,
        order: order,
        page: 1,
      );

      if (!_cancelToken!.isCancelled) {
        ref.read(searchResultsItemsProvider.notifier).state = result.items;
        ref.read(searchTotalCountProvider.notifier).state = result.totalCount;
        ref.read(searchHasMoreProvider.notifier).state = result.hasMore;
        state = AsyncData(result);

        // Add to search history
        await repo.addSearchHistory(query);
        // Refresh history provider
        ref.invalidate(searchHistoryProvider);
      }
    } catch (e) {
      if (!_cancelToken!.isCancelled) {
        ref.read(searchErrorProvider.notifier).state = e.toString();
        state = AsyncError(e, StackTrace.current);
      }
    } finally {
      if (!_cancelToken!.isCancelled) {
        ref.read(searchIsSearchingProvider.notifier).state = false;
      }
    }
  }

  /// Load the next page of results.
  Future<void> loadNextPage() async {
    if (ref.read(searchLoadingMoreProvider)) return;
    if (!ref.read(searchHasMoreProvider)) return;

    final query = ref.read(searchQueryProvider);
    if (query.trim().isEmpty) return;

    ref.read(searchLoadingMoreProvider.notifier).state = true;

    try {
      final nextPage = ref.read(searchCurrentPageProvider) + 1;
      final repo = ref.read(searchRepositoryProvider);
      final sort = _mapSortField(ref.read(searchSortProvider));
      final platform = ref.read(searchPlatformFilterProvider);
      final language = ref.read(searchLanguageFilterProvider);
      final order = ref.read(searchSortOrderProvider);

      final result = await repo.search(
        query,
        platform: platform.isEmpty ? null : platform,
        language: language.isEmpty ? null : language,
        sort: sort,
        order: order,
        page: nextPage,
      );

      final currentItems = ref.read(searchResultsItemsProvider);
      ref.read(searchResultsItemsProvider.notifier).state = [
        ...currentItems,
        ...result.items,
      ];
      ref.read(searchCurrentPageProvider.notifier).state = nextPage;
      ref.read(searchHasMoreProvider.notifier).state = result.hasMore;

      // Update the combined result
      state = AsyncData(SearchResultModel(
        items: ref.read(searchResultsItemsProvider),
        totalCount: result.totalCount,
        currentPage: nextPage,
        perPage: result.perPage,
        hasMore: result.hasMore,
        query: query,
      ));
    } catch (e) {
      ref.read(searchErrorProvider.notifier).state =
          'Failed to load more results: $e';
    } finally {
      ref.read(searchLoadingMoreProvider.notifier).state = false;
    }
  }

  /// Map the UI sort field to the API sort field.
  String _mapSortField(String sort) {
    return switch (sort) {
      'stars' => 'stars',
      'forks' => 'forks',
      _ => 'best_match',
    };
  }

  /// Clear search state.
  void clearSearch() {
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(searchResultsItemsProvider.notifier).state = [];
    ref.read(searchTotalCountProvider.notifier).state = 0;
    ref.read(searchHasMoreProvider.notifier).state = false;
    ref.read(searchCurrentPageProvider.notifier).state = 1;
    ref.read(searchErrorProvider.notifier).state = null;
    ref.read(searchIsSearchingProvider.notifier).state = false;
    state = AsyncData(SearchResultModel.empty());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}

// ── Search History Provider ───────────────────────────────────────────────

/// Provider for search history loaded from the database.
final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getSearchHistory();
});

// ── Helper ────────────────────────────────────────────────────────────────

/// Simple cancel token for aborting in-flight searches.
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

// ── Sort Options ──────────────────────────────────────────────────────────

/// Available sort options for search.
const searchSortOptions = [
  ('Best Match', 'best_match'),
  ('Stars', 'stars'),
  ('Forks', 'forks'),
  ('Recently Updated', 'updated'),
];

/// Available sort order options.
const searchSortOrderOptions = [
  ('Descending', 'desc'),
  ('Ascending', 'asc'),
];
