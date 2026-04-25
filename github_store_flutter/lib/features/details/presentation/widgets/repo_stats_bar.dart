import 'package:flutter/material.dart';

import '../../../../core/models/repository_model.dart';

/// A horizontal stats bar showing Stars, Forks, Watchers, and Open Issues
/// with icons and formatted counts.
class RepoStatsBar extends StatelessWidget {
  const RepoStatsBar({
    required this.repository,
    this.showLanguage = true,
    super.key,
  });

  final RepositoryModel repository;
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        // Stars
        _StatItem(
          icon: Icons.star_outline,
          iconColor: const Color(0xFFE3B341),
          label: repository.formattedStars,
          tooltip: '${repository.stars} stars',
        ),

        // Forks
        _StatItem(
          icon: Icons.fork_right,
          iconColor: theme.colorScheme.onSurfaceVariant,
          label: repository.formattedForks,
          tooltip: '${repository.forks} forks',
        ),

        // Watchers
        _StatItem(
          icon: Icons.visibility_outlined,
          iconColor: theme.colorScheme.onSurfaceVariant,
          label: _formatCount(repository.watchers),
          tooltip: '${repository.watchers} watchers',
        ),

        // Open Issues
        _StatItem(
          icon: Icons.circle_outlined,
          iconColor: theme.colorScheme.onSurfaceVariant,
          label: '${repository.openIssues}',
          tooltip: '${repository.openIssues} open issues',
        ),

        // Language
        if (showLanguage && repository.language != null) ...[
          _StatItem(
            icon: Icons.circle,
            iconColor: _parseColor(
              repository.languageColor,
              fallback: theme.colorScheme.primary,
            ),
            iconSize: 10,
            label: repository.language!,
            tooltip: 'Primary language: ${repository.language}',
          ),
        ],
      ],
    );
  }

  Color _parseColor(String? hexColor, {required Color fallback}) {
    if (hexColor == null || hexColor.isEmpty) return fallback;
    try {
      final hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.tooltip,
    this.iconSize = 16,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String tooltip;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
