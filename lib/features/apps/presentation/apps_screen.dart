import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/installed_app_model.dart';
import '../../../../core/models/release_asset_model.dart';
import '../../../../core/router/app_router.dart';
import 'providers/apps_provider.dart';
import 'widgets/link_app_dialog.dart';

/// Installed apps management screen.
///
/// Displays all tracked installed applications with update checking,
/// sorting, filtering, and export/import capabilities.
class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  bool _isGridView = false;
  bool _showUpdateSection = true;

  @override
  void initState() {
    super.initState();
    // Check for updates on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(installedAppsProvider.notifier).checkUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appsAsync = ref.watch(installedAppsProvider);
    final updateCount = ref.watch(updateCountProvider);
    final isChecking = ref.watch(isCheckingUpdatesProvider);
    final searchQuery = ref.watch(appsSearchQueryProvider);
    final sortMode = ref.watch(sortModeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('My Apps'),
                if (updateCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(minWidth: 24),
                    child: Text(
                      '$updateCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // Check for updates
              IconButton(
                icon: isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_outlined),
                tooltip: 'Check for Updates',
                onPressed: isChecking
                    ? null
                    : () {
                        ref.read(installedAppsProvider.notifier).checkUpdates();
                      },
              ),
              // Export
              IconButton(
                icon: const Icon(Icons.upload_outlined),
                tooltip: 'Export Apps',
                onPressed: () => _handleExport(context),
              ),
              // Import
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Import Apps',
                onPressed: () => _handleImport(context),
              ),
              // Sort dropdown
              PopupMenuButton<AppsSortMode>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onSelected: (mode) {
                  ref.read(sortModeProvider.notifier).state = mode;
                },
                itemBuilder: (context) => AppsSortMode.values
                    .map((m) => PopupMenuItem(
                          value: m,
                          child: Row(
                            children: [
                              if (m == sortMode)
                                const Icon(Icons.check, size: 16)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(m.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              // Toggle grid/list
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                tooltip: _isGridView ? 'List view' : 'Grid view',
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              // Link app
              IconButton(
                icon: const Icon(Icons.link),
                tooltip: 'Link Installed App',
                onPressed: () => _showLinkAppDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Search Bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search installed apps...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            ref.read(appsSearchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onChanged: (value) {
                  ref.read(appsSearchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          appsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: _ErrorView(
                message: 'Failed to load apps',
                error: error,
                onRetry: () =>
                    ref.read(installedAppsProvider.notifier).refresh(),
              ),
            ),
            data: (apps) {
              // Filter by search
              final filtered = _filterApps(apps, searchQuery);

              // Sort
              final sorted = _sortApps(filtered, sortMode);

              // Split into updates and installed
              final updatable =
                  sorted.where((a) => a.isUpdateAvailable).toList();
              final nonUpdatable =
                  sorted.where((a) => !a.isUpdateAvailable).toList();

              if (sorted.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(searchQuery: searchQuery),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // Stats summary
                  _StatsSummaryCard(
                    totalApps: apps.length,
                    updateCount: updateCount,
                  ),

                  // Updates available section
                  if (updatable.isNotEmpty)
                    _UpdatesSection(
                      apps: updatable,
                      isExpanded: _showUpdateSection,
                      onToggle: () => setState(
                        () => _showUpdateSection = !_showUpdateSection,
                      ),
                    ),

                  // All apps header
                  if (nonUpdatable.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Installed',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${nonUpdatable.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // App list / grid
                  if (_isGridView)
                    _AppsGridView(apps: nonUpdatable)
                  else
                    ...nonUpdatable.map(
                      (app) => _AppListTile(
                        app: app,
                        onTap: () => _navigateToDetails(app),
                        onUpdate: () => ref
                            .read(installedAppsProvider.notifier)
                            .updateApp(app),
                        onUninstall: () =>
                            _confirmUninstall(context, app),
                      ),
                    ),

                  const SizedBox(height: 32),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Filtering & Sorting ─────────────────────────────────────────────────

  List<InstalledAppModel> _filterApps(
    List<InstalledAppModel> apps,
    String query,
  ) {
    if (query.isEmpty) return apps;
    final lower = query.toLowerCase();
    return apps.where((app) {
      return app.name.toLowerCase().contains(lower) ||
          app.owner.toLowerCase().contains(lower) ||
          app.effectiveFullName.toLowerCase().contains(lower) ||
          (app.installedVersion?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  List<InstalledAppModel> _sortApps(
    List<InstalledAppModel> apps,
    AppsSortMode mode,
  ) {
    final sorted = List<InstalledAppModel>.from(apps);
    switch (mode) {
      case AppsSortMode.updatesFirst:
        sorted.sort((a, b) {
          final aUpdate = a.isUpdateAvailable ? 0 : 1;
          final bUpdate = b.isUpdateAvailable ? 0 : 1;
          if (aUpdate != bUpdate) return aUpdate - bUpdate;
          return (b.lastUpdateCheck ?? DateTime(2000))
              .compareTo(a.lastUpdateCheck ?? DateTime(2000));
        });
      case AppsSortMode.recentlyUpdated:
        sorted.sort((a, b) => (b.lastUpdateCheck ?? DateTime(2000))
            .compareTo(a.lastUpdateCheck ?? DateTime(2000)));
      case AppsSortMode.name:
        sorted.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return sorted;
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _navigateToDetails(InstalledAppModel app) {
    context.push(
      AppRoute.details.withParams({
        'owner': app.owner,
        'repo': app.name,
      }),
    );
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    InstalledAppModel app,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall App'),
        content: Text(
          'Remove ${app.name} from your tracked apps?\n\n'
          'This only removes it from tracking — it does not uninstall '
          'the actual application from your system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(installedAppsProvider.notifier).uninstall(app);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.name} removed from tracking'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                ref.read(installedAppsProvider.notifier).checkUpdates();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    final isOp = ref.read(isOperationProvider);
    if (isOp) return;

    final success =
        await ref.read(installedAppsProvider.notifier).exportApps();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Apps exported to clipboard'
                : 'Export failed. No apps to export.',
          ),
        ),
      );
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    final isOp = ref.read(isOperationProvider);
    if (isOp) return;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Apps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the exported JSON to import apps.\n'
              'Duplicates will be skipped.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Paste JSON here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final count =
          await ref.read(installedAppsProvider.notifier).importApps(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count >= 0
                  ? 'Imported $count app(s)'
                  : 'Import failed. Check the JSON format.',
            ),
          ),
        );
      }
    }
  }

  void _showLinkAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const LinkAppDialog(),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────

class _StatsSummaryCard extends ConsumerWidget {
  const _StatsSummaryCard({
    required this.totalApps,
    required this.updateCount,
  });

  final int totalApps;
  final int updateCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.apps,
                size: 28,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalApps app${totalApps != 1 ? 's' : ''} installed',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (updateCount > 0)
                      Text(
                        '$updateCount update${updateCount != 1 ? 's' : ''} available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    else
                      Text(
                        'All apps are up to date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              if (updateCount > 0)
                FilledButton.tonalIcon(
                  onPressed: () {
                    ref
                        .read(installedAppsProvider.notifier)
                        .updateAll();
                  },
                  icon: const Icon(Icons.system_update, size: 18),
                  label: const Text('Update All'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdatesSection extends ConsumerWidget {
  const _UpdatesSection({
    required this.apps,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<InstalledAppModel> apps;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.new_releases_outlined,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updates Available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${apps.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Update All',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),

          // Update items
          if (isExpanded)
            ...apps.map(
              (app) => _UpdateListTile(
                app: app,
                onUpdate: () => ref
                    .read(installedAppsProvider.notifier)
                    .updateApp(app),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpdateListTile extends ConsumerWidget {
  const _UpdateListTile({
    required this.app,
    required this.onUpdate,
  });

  final InstalledAppModel app;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // App icon
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        app.installedVersion ?? '?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        app.latestVersion ?? '?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Update button
            FilledButton.tonal(
              onPressed: onUpdate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppListTile extends ConsumerWidget {
  const _AppListTile({
    required this.app,
    required this.onTap,
    required this.onUpdate,
    required this.onUninstall,
  });

  final InstalledAppModel app;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.owner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (app.installedVersion != null) ...[
                          Icon(
                            Icons.tag,
                            size: 12,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            app.installedVersion!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (app.platform !=
                            ReleaseAssetPlatform.unknown) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            app.platformDisplayName,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (app.isUpdateAvailable)
                    SizedBox(
                      width: 80,
                      child: FilledButton.tonal(
                        onPressed: onUpdate,
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Update'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    child: OutlinedButton(
                      onPressed: onUninstall,
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppsGridView extends ConsumerWidget {
  const _AppsGridView({required this.apps});

  final List<InstalledAppModel> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                context.push(
                  AppRoute.details.withParams({
                    'owner': app.owner,
                    'repo': app.name,
                  }),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      child: Text(
                        app.name.isNotEmpty
                            ? app.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color:
                              theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      app.owner,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (app.installedVersion != null)
                          Expanded(
                            child: Text(
                              app.installedVersion!,
                              style:
                                  theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (app.isUpdateAvailable)
                          Icon(
                            Icons.new_releases,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.apps_outlined,
              size: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No apps match "${searchQuery}"'
                  : 'No apps installed yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Browse the store to discover and install apps, '
                      'or link an existing app on your system.',
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
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
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
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
