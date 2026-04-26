import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import 'providers/recently_viewed_provider.dart';

/// Recently viewed repositories screen.
///
/// Displays a list of repositories ordered by most recently viewed, with
/// relative timestamps ("2 hours ago"), swipe-to-delete, and clear history.
class RecentlyViewedScreen extends ConsumerStatefulWidget {
  const RecentlyViewedScreen({super.key});

  @override
  ConsumerState<RecentlyViewedScreen> createState() =>
      _RecentlyViewedScreenState();
}

class _RecentlyViewedScreenState extends ConsumerState<RecentlyViewedScreen> {
  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear your viewing history? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(recentlyViewedProvider.notifier).clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viewing history cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeItem(RecentlyViewedItem item) async {
    final parts = item.repository.fullName.split('/');
    if (parts.length < 2) return;

    await ref.read(recentlyViewedProvider.notifier).remove(parts[0], parts[1]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.repository.fullName} removed from history'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToDetails(RecentlyViewedItem item) {
    final repo = item.repository;
    context.push(
      AppRoute.details.path
          .replaceAll(':owner', repo.ownerLogin)
          .replaceAll(':repo', repo.name),
    );
  }

  void _navigateToOwner(RecentlyViewedItem item) {
    context.push(
      AppRoute.devProfile.path
          .replaceAll(':username', item.repository.ownerLogin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentlyViewedAsync = ref.watch(recentlyViewedProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Recently Viewed'),
        actions: [
          TextButton(
            onPressed: _showClearAllDialog,
            child: const Text('Clear History'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: recentlyViewedAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _ErrorState(
          message: 'Failed to load viewing history',
          error: error.toString(),
          onRetry: () => ref.invalidate(recentlyViewedProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 72,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No viewing history',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Repositories you view will appear here, '
                      'ordered by most recent.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _RecentlyViewedListItem(
                item: item,
                onTap: () => _navigateToDetails(item),
                onOwnerTap: () => _navigateToOwner(item),
                onDismissed: () => _removeItem(item),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Recently Viewed List Item ──────────────────────────────────────────────

class _RecentlyViewedListItem extends StatelessWidget {
  const _RecentlyViewedListItem({
    required this.item,
    required this.onTap,
    required this.onOwnerTap,
    required this.onDismissed,
  });

  final RecentlyViewedItem item;
  final VoidCallback onTap;
  final VoidCallback onOwnerTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = item.repository;
    final timeAgo = _formatTimeAgo(item.viewedAt);

    return Dismissible(
      key: Key('recently_viewed_${repo.fullName}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from History'),
            content: Text('Remove ${repo.fullName} from your viewing history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDismissed(),
      child: Card(
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
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: repo.ownerAvatarUrl == null
                        ? Text(
                            repo.ownerLogin.isNotEmpty
                                ? repo.ownerLogin[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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

                      // Timestamp + stats row
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            timeAgo,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),

                          if (item.viewCount > 1) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.visibility,
                              size: 13,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${item.viewCount} views',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],

                          const Spacer(),

                          // Stars (if available)
                          if (repo.stars > 0) ...[
                            const Icon(
                              Icons.star_outline,
                              size: 13,
                              color: Color(0xFFE3B341),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatCount(repo.stars),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Delete icon (for desktop / right-click alternative)
                const SizedBox(width: 4),
                Column(
                  children: [
                    const SizedBox(height: 2),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                      tooltip: 'Remove from history',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove from History'),
                            content: Text(
                              'Remove ${repo.fullName} from your viewing history?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          onDismissed();
                        }
                      },
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format a [DateTime] as a relative time string (e.g. "2 hours ago").
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins minute${mins == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = difference.inDays ~/ 365;
      return '$years year${years == 1 ? '' : 's'} ago';
    }
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

// ── Error State ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleLarge,
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
