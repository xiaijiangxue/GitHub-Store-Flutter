import 'dart:convert';

/// Category model for organizing repositories on the home feed.
class CategoryModel {
  CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    this.topicKeywords = const [],
    this.color,
    this.sortOrder = 0,
    this.isFeatured = false,
  });

  /// Unique identifier for this category.
  final String id;

  /// Human-readable category name (e.g. "Developer Tools").
  final String name;

  /// Icon identifier or asset path (e.g. "code", "category_tools.png").
  final String? icon;

  /// Category description.
  final String? description;

  /// List of GitHub topic keywords used to fetch repos for this category.
  final List<String> topicKeywords;

  /// Accent color for the category (hex code, e.g. "#FF6B6B").
  final String? color;

  /// Sort order for display (lower = higher priority).
  final int sortOrder;

  /// Whether this category is featured/promoted.
  final bool isFeatured;

  /// Whether this category has a description.
  bool get hasDescription => description != null && description!.isNotEmpty;

  /// Whether this category has keywords.
  bool get hasKeywords => topicKeywords.isNotEmpty;

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? description,
    List<String>? topicKeywords,
    String? color,
    int? sortOrder,
    bool? isFeatured,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      topicKeywords: topicKeywords ?? this.topicKeywords,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String? ?? json['name'] as String ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      description: json['description'] as String?,
      topicKeywords: (json['topic_keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (icon != null) 'icon': icon,
      if (description != null) 'description': description,
      'topic_keywords': topicKeywords,
      if (color != null) 'color': color,
      'sort_order': sortOrder,
      'is_featured': isFeatured,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory CategoryModel.fromJsonString(String source) =>
      CategoryModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CategoryModel(id: $id, name: $name, keywords: $topicKeywords)';
}
