import 'dart:convert';

import 'repository_model.dart';

/// Represents paginated search results from the GitHub API or Store API.
class SearchResultModel {
  SearchResultModel({
    required this.items,
    required this.totalCount,
    this.currentPage = 1,
    this.perPage = 30,
    this.hasMore = false,
    this.incompleteResults = false,
    this.query,
  });

  /// List of repository items in this page of results.
  final List<RepositoryModel> items;

  /// Total number of results matching the query across all pages.
  final int totalCount;

  /// Current page number (1-indexed).
  final int currentPage;

  /// Number of items per page.
  final int perPage;

  /// Whether there are more pages of results available.
  bool get hasMore {
    return items.length >= perPage ||
        currentPage * perPage < totalCount;
  }

  /// Whether the search results may be incomplete.
  final bool incompleteResults;

  /// The original search query string.
  final String? query;

  /// Formatted total count string.
  String get formattedTotalCount => _formatCount(totalCount);

  SearchResultModel copyWith({
    List<RepositoryModel>? items,
    int? totalCount,
    int? currentPage,
    int? perPage,
    bool? hasMore,
    bool? incompleteResults,
    String? query,
  }) {
    return SearchResultModel(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      perPage: perPage ?? this.perPage,
      hasMore: hasMore ?? this.hasMore,
      incompleteResults: incompleteResults ?? this.incompleteResults,
      query: query ?? this.query,
    );
  }

  /// Create an empty search result.
  factory SearchResultModel.empty() {
    return SearchResultModel(
      items: const [],
      totalCount: 0,
      currentPage: 1,
      perPage: 30,
      hasMore: false,
    );
  }

  /// Parse from GitHub's search/repositories API response format.
  ///
  /// Expected JSON:
  /// ```json
  /// {
  ///   "total_count": 123,
  ///   "incomplete_results": false,
  ///   "items": [...]
  /// }
  /// ```
  factory SearchResultModel.fromJson(
    Map<String, dynamic> json, {
    int page = 1,
    int perPage = 30,
  }) {
    return SearchResultModel(
      totalCount: json['total_count'] as int? ?? 0,
      incompleteResults: json['incomplete_results'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  RepositoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      currentPage: page,
      perPage: perPage,
      query: json['query'] as String?,
    );
  }

  /// Parse from GitHub Store API response format.
  ///
  /// Expected JSON:
  /// ```json
  /// {
  ///   "data": [...],
  ///   "total": 123,
  ///   "page": 1,
  ///   "per_page": 30
  /// }
  /// ```
  factory SearchResultModel.fromStoreJson(
    Map<String, dynamic> json, {
    int page = 1,
    int perPage = 30,
  }) {
    return SearchResultModel(
      totalCount: json['total'] as int? ??
          json['total_count'] as int? ??
          0,
      items: (json['data'] as List<dynamic>? ??
              json['items'] as List<dynamic>?)
          .map((e) =>
              RepositoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: json['page'] as int? ?? page,
      perPage: json['per_page'] as int? ?? perPage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_count': totalCount,
      'incomplete_results': incompleteResults,
      'items': items.map((r) => r.toJson()).toList(),
      'page': currentPage,
      'per_page': perPage,
      if (query != null) 'query': query,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory SearchResultModel.fromJsonString(String source) =>
      SearchResultModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResultModel &&
          runtimeType == other.runtimeType &&
          totalCount == other.totalCount &&
          currentPage == other.currentPage;

  @override
  int get hashCode => Object.hash(totalCount, currentPage);

  @override
  String toString() =>
      'SearchResultModel(total: $totalCount, page: $currentPage, items: ${items.length})';
}
