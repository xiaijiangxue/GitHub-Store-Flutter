import 'package:flutter/material.dart';

/// A bottom sheet displaying a searchable list of programming languages
/// for filtering search results.
///
/// Includes 25+ common languages with colored indicators.
class LanguageFilterSheet extends StatefulWidget {
  const LanguageFilterSheet({
    required this.selectedLanguage,
    required this.onLanguageSelected,
    super.key,
  });

  /// Currently selected language (empty string means "All Languages").
  final String selectedLanguage;

  /// Callback when a language is selected.
  final void Function(String language) onLanguageSelected;

  @override
  State<LanguageFilterSheet> createState() => _LanguageFilterSheetState();
}

class _LanguageFilterSheetState extends State<LanguageFilterSheet> {
  final _searchController = TextEditingController();
  String _filterText = '';
  bool _showAll = false;

  static const _allLanguages = [
    ('All Languages', '', null),
    ('Dart', 'Dart', '#00B4AB'),
    ('TypeScript', 'TypeScript', '#3178C6'),
    ('JavaScript', 'JavaScript', '#F7DF1E'),
    ('Python', 'Python', '#3572A5'),
    ('Rust', 'Rust', '#DEA584'),
    ('Go', 'Go', '#00ADD8'),
    ('Java', 'Java', '#B07219'),
    ('Kotlin', 'Kotlin', '#A97BFF'),
    ('Swift', 'Swift', '#F05138'),
    ('C++', 'C++', '#F34B7D'),
    ('C', 'C', '#555555'),
    ('C#', 'C#', '#178600'),
    ('Ruby', 'Ruby', '#701516'),
    ('PHP', 'PHP', '#4F5D95'),
    ('Shell', 'Shell', '#89E051'),
    ('Objective-C', 'Objective-C', '#438EFF'),
    ('Scala', 'Scala', '#C22D40'),
    ('Lua', 'Lua', '#000080'),
    ('R', 'R', '#198CE7'),
    ('Perl', 'Perl', '#0298C3'),
    ('Haskell', 'Haskell', '#5E5086'),
    ('Elixir', 'Elixir', '#6E4A7E'),
    ('Zig', 'Zig', '#EC915C'),
    ('V', 'V', '#4B5C6F'),
    ('Nim', 'Nim', '#FFE953'),
    ('Julia', 'Julia', '#A270BA'),
    ('Crystal', 'Crystal', '#000100'),
    ('Assembly', 'Assembly', '#6E4C93'),
    ('Vue', 'Vue', '#41B883'),
  ];

  /// Initially visible languages (before "Show More" is pressed).
  static const _visibleCount = 12;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filterText = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _getFilteredLanguages();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Filter by Language',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.selectedLanguage.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      widget.onLanguageSelected('');
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // ── Search field ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search languages...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filterText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Language list ─────────────────────────────────────────────
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount:
                  _showAll || _filterText.isNotEmpty ? filtered.length : filtered.length.clamp(0, _visibleCount) + 1,
              itemBuilder: (context, index) {
                // Show "Show More" button if applicable
                if (!_showAll &&
                    _filterText.isEmpty &&
                    index == filtered.length.clamp(0, _visibleCount)) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: const Text('Show all languages...'),
                    ),
                  );
                }

                final (label, value, color) = filtered[index];
                final isSelected = value == widget.selectedLanguage;

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dense: true,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check_circle, size: 20)
                      else if (color != null)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _parseColor(color),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 20),
                      if (color != null && !isSelected)
                        const SizedBox(width: 6),
                    ],
                  ),
                  title: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                  onTap: () => widget.onLanguageSelected(value),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<(String, String, String?)> _getFilteredLanguages() {
    if (_filterText.isEmpty) return _allLanguages;
    return _allLanguages
        .where((lang) => lang.$1.toLowerCase().contains(_filterText))
        .toList();
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }
}
