import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/search_provider.dart';
import 'language_filter_sheet.dart';

/// A row of filter controls for the search screen: platform filter,
/// language filter button, and sort dropdown with order toggle.
class SearchFilters extends ConsumerWidget {
  const SearchFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedPlatform = ref.watch(searchPlatformFilterProvider);
    final selectedLanguage = ref.watch(searchLanguageFilterProvider);
    final selectedSort = ref.watch(searchSortProvider);
    final sortOrder = ref.watch(searchSortOrderProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Platform Filter ───────────────────────────────────────────
          _FilterChip(
            label: selectedPlatform.isEmpty ? 'Platform' : selectedPlatform,
            icon: Icons.devices,
            isSelected: selectedPlatform.isNotEmpty,
            onTap: () => _showPlatformMenu(context, ref, selectedPlatform),
          ),

          const SizedBox(width: 8),

          // ── Language Filter ───────────────────────────────────────────
          _FilterChip(
            label: selectedLanguage.isEmpty ? 'Language' : selectedLanguage,
            icon: Icons.code,
            isSelected: selectedLanguage.isNotEmpty,
            onTap: () => _showLanguageSheet(context, ref, selectedLanguage),
          ),

          const SizedBox(width: 8),

          // ── Sort Dropdown ─────────────────────────────────────────────
          _FilterChip(
            label: _getSortLabel(selectedSort),
            icon: Icons.sort,
            isSelected: selectedSort != 'best_match',
            trailing: Icon(
              sortOrder == 'desc'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 14,
              color: selectedSort != 'best_match'
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showSortMenu(context, ref, selectedSort),
          ),

          // ── Sort Order Toggle ─────────────────────────────────────────
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              final newOrder = sortOrder == 'desc' ? 'asc' : 'desc';
              ref.read(searchSortOrderProvider.notifier).state = newOrder;
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sortOrder == 'desc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortOrder == 'desc' ? 'DESC' : 'ASC',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String sort) {
    return switch (sort) {
      'best_match' => 'Best Match',
      'stars' => 'Stars',
      'forks' => 'Forks',
      'updated' => 'Updated',
      _ => 'Sort',
    };
  }

  void _showPlatformMenu(
    BuildContext context,
    WidgetRef ref,
    String currentPlatform,
  ) {
    final platforms = ['', 'android', 'macos', 'windows', 'linux'];
    final labels = ['All', 'Android', 'macOS', 'Windows', 'Linux'];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filter by Platform',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            ...labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final value = platforms[index];
              final isSelected = value == currentPlatform;

              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check, size: 20)
                    : const SizedBox(width: 20),
                title: Text(label),
                onTap: () {
                  ref.read(searchPlatformFilterProvider.notifier).state =
                      value;
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    String currentLanguage,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => LanguageFilterSheet(
        selectedLanguage: currentLanguage,
        onLanguageSelected: (language) {
          ref.read(searchLanguageFilterProvider.notifier).state = language;
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showSortMenu(
    BuildContext context,
    WidgetRef ref,
    String currentSort,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            ...searchSortOptions.map((option) {
              final (label, value) = option;
              final isSelected = value == currentSort;

              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check, size: 20)
                    : const SizedBox(width: 20),
                title: Text(label),
                onTap: () {
                  ref.read(searchSortProvider.notifier).state = value;
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A single filter chip with icon, label, and optional trailing widget.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
