import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_provider.dart';

/// Horizontal scrollable programming language filter chips.
///
/// Filters trending, hot releases, and popular repos by language.
class LanguageFilterBar extends ConsumerWidget {
  const LanguageFilterBar({super.key});

  static const _languages = [
    ('All', ''),
    ('Dart', 'Dart'),
    ('Python', 'Python'),
    ('JavaScript', 'JavaScript'),
    ('TypeScript', 'TypeScript'),
    ('Java', 'Java'),
    ('Kotlin', 'Kotlin'),
    ('Go', 'Go'),
    ('Rust', 'Rust'),
    ('C++', 'C++'),
    ('Swift', 'Swift'),
    ('Ruby', 'Ruby'),
    ('PHP', 'PHP'),
    ('C', 'C'),
    ('Shell', 'Shell'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedLanguage = ref.watch(homeLanguageFilterProvider);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (label, value) = _languages[index];
          final isSelected = selectedLanguage == value;

          return _LanguageChip(
            label: label,
            isSelected: isSelected,
            onTap: () {
              ref.read(homeLanguageFilterProvider.notifier).state = value;
            },
          );
        },
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.tertiary
            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? colorScheme.onTertiary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
