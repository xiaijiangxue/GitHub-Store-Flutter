import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/release_asset_model.dart';
import '../../../core/models/release_model.dart';
import '../../../core/models/repository_model.dart';
import '../../../core/router/app_router.dart';
import 'providers/details_provider.dart';
import 'widgets/asset_list_tile.dart';
import 'widgets/owner_card.dart';
import 'widgets/readme_viewer.dart';
import 'widgets/release_card.dart';
import 'widgets/repo_stats_bar.dart';

/// Repository details screen with README, releases, and metadata.
///
/// Receives [owner] and [repo] from route params and loads real data
/// via Riverpod providers. Features a tabbed layout (README, Releases, Info),
/// action buttons (Install/Download, Star, Favorite, Share, Open in Browser),
/// pull-to-refresh, loading skeletons, and error states.
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({
    required this.owner,
    required this.repo,
    super.key,
  });

  final String owner;
  final String repo;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Mark as recently viewed after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRecentlyViewed();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Optionally handle programmatic tab changes
    }
  }

  void _markRecentlyViewed() {
    final param = RepoParam(widget.owner, widget.repo);
    ref.read(markRecentlyViewedProvider(param).future);
  }

  RepoParam get _param => RepoParam(widget.owner, widget.repo);

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(repositoryProvider(_param));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: repoAsync.when(
        loading: () => _buildLoadingSkeleton(theme),
        error: (error, stack) => _buildErrorState(theme, error),
        data: (repo) => _buildContent(context, theme, colorScheme, repo),
      ),
    );
  }

  // ── Loading Skeleton ─────────────────────────────────────────────────

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          theme: theme,
          repo: null,
          avatarUrl: null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Owner/name skeleton
                _shimmerBox(theme, width: 180, height: 16),
                const SizedBox(height: 12),
                // Description skeleton
                _shimmerBox(theme, width: double.infinity, height: 14),
                const SizedBox(height: 6),
                _shimmerBox(theme, width: 300, height: 14),
                const SizedBox(height: 16),
                // Stats skeleton
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 3 ? 16 : 0),
                        child:
                            _shimmerBox(theme, width: double.infinity, height: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons skeleton
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                        child: _shimmerBox(
                          theme,
                          width: double.infinity,
                          height: 40,
                          radius: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Topics skeleton
                Row(
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      child: _shimmerBox(theme, width: 72, height: 28, radius: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          delegate: _StickyTabDelegate(
            tabController: _tabController,
            tabs: const [
              Tab(text: 'README'),
              Tab(text: 'Releases'),
              Tab(text: 'Info'),
            ],
          ),
          pinned: true,
        ),
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox(
    ThemeData theme, {
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Error State ──────────────────────────────────────────────────────

  Widget _buildErrorState(ThemeData theme, Object error) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text('${widget.owner}/${widget.repo}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load repository',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _refreshAll(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main Content ─────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    RepositoryModel repo,
  ) {
    return RefreshIndicator(
      onRefresh: () => _refreshAll(),
      color: colorScheme.primary,
      child: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          _buildSliverAppBar(
            theme: theme,
            repo: repo,
            avatarUrl: repo.ownerAvatarUrl,
          ),

          // ── Header Content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owner / Repo name
                  _buildRepoName(theme, repo),
                  const SizedBox(height: 10),

                  // Description
                  if (repo.description != null &&
                      repo.description!.isNotEmpty) ...[
                    Text(
                      repo.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Stats bar
                  RepoStatsBar(repository: repo),

                  // Language & License badges
                  if (repo.language != null ||
                      repo.license != null) ...[
                    const SizedBox(height: 12),
                    _buildBadges(theme, repo),
                  ],

                  // Topics
                  if (repo.topics.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildTopics(theme, repo.topics),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  _buildActionButtons(theme, colorScheme, repo),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── Sticky Tab Bar ─────────────────────────────────────────
          SliverPersistentHeader(
            delegate: _StickyTabDelegate(
              tabController: _tabController,
              tabs: const [
                Tab(text: 'README'),
                Tab(text: 'Releases'),
                Tab(text: 'Info'),
              ],
            ),
            pinned: true,
          ),

          // ── Tab Content ────────────────────────────────────────────
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReadmeTab(theme),
                _buildReleasesTab(theme, colorScheme),
                _buildInfoTab(theme, colorScheme, repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver AppBar ───────────────────────────────────────────────────

  Widget _buildSliverAppBar({
    required ThemeData theme,
    required RepositoryModel? repo,
    required String? avatarUrl,
  }) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
        tooltip: 'Back',
      ),
      actions: [
        // Share button
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: 'Copy link',
          onPressed: () => _copyGitHubUrl(),
        ),
        // Open in browser
        IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open in browser',
          onPressed: () => _openInBrowser(),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.repo,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 8)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withOpacity(0.12),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: Center(
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 36,
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  )
                : CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      widget.owner.isNotEmpty
                          ? widget.owner[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Repo Name ───────────────────────────────────────────────────────

  Widget _buildRepoName(ThemeData theme, RepositoryModel repo) {
    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: () {
              context.push(
                AppRoute.devProfile.withParams({'username': widget.owner}),
              );
            },
            child: Text(
              widget.owner,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Text(
          ' / ',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        Flexible(
          child: Text(
            repo.name,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (repo.isArchived) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Archived',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (repo.isFork) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Fork',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Badges ──────────────────────────────────────────────────────────

  Widget _buildBadges(ThemeData theme, RepositoryModel repo) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // License badge
        if (repo.license != null &&
            repo.license!.name != null &&
            repo.license!.name != 'NOASSERTION') ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.scale_outlined,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  repo.license!.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Topics ──────────────────────────────────────────────────────────

  Widget _buildTopics(ThemeData theme, List<String> topics) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final topic = topics[index];
          return GestureDetector(
            onTap: () {
              // Could navigate to a topic search screen
              context.push(
                AppRoute.search.path,
                extra: {'q': 'topic:$topic'},
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Text(
                topic,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────────

  Widget _buildActionButtons(
    ThemeData theme,
    ColorScheme colorScheme,
    RepositoryModel repo,
  ) {
    final starredAsync = ref.watch(starredProvider(_param));
    final favoritedAsync = ref.watch(favoritedProvider(_param));
    final isStarred = starredAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final isFavorited = favoritedAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary row: Install + Star + Favorite
        Row(
          children: [
            // Install/Download button
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _handleInstall(context, repo),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Install'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Star button
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(starredProvider(_param).notifier).toggle(),
                icon: Icon(
                  isStarred ? Icons.star : Icons.star_outline,
                  size: 18,
                  color: isStarred
                      ? const Color(0xFFE3B341)
                      : null,
                ),
                label: Text(repo.formattedStars),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: isStarred
                      ? const Color(0xFFE3B341)
                      : null,
                  side: BorderSide(
                    color: isStarred
                        ? const Color(0xFFE3B341).withOpacity(0.5)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Favorite button
            SizedBox(
              height: 44,
              width: 44,
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(favoritedProvider(_param).notifier).toggle(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: isFavorited
                      ? colorScheme.tertiary
                      : null,
                  side: BorderSide(
                    color: isFavorited
                        ? colorScheme.tertiary.withOpacity(0.5)
                        : null,
                  ),
                ),
                child: Icon(
                  isFavorited
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 20,
                  color: isFavorited
                      ? colorScheme.tertiary
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── README Tab ──────────────────────────────────────────────────────

  Widget _buildReadmeTab(ThemeData theme) {
    final readmeAsync = ref.watch(readmeProvider(_param));

    return readmeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load README',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(readmeProvider(_param).notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (readme) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ReadmeViewer(
          markdownContent: readme,
          owner: widget.owner,
          repo: widget.repo,
          defaultBranch: ref.read(repositoryProvider(_param)).maybeWhen(
            data: (r) => r.defaultBranch,
            orElse: () => 'main',
          ),
        ),
      ),
    );
  }

  // ── Releases Tab ────────────────────────────────────────────────────

  Widget _buildReleasesTab(ThemeData theme, ColorScheme colorScheme) {
    final releasesAsync = ref.watch(releasesProvider(_param));
    final filter = ref.watch(releaseFilterProvider);
    final selectedIndex = ref.watch(selectedReleaseIndexProvider);

    return releasesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tag,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load releases',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(releasesProvider(_param).notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (releases) {
        if (releases.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tag,
                    size: 48,
                    color:
                        theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No releases found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Apply filter
        final filteredReleases = filter == 'all'
            ? releases
            : filter == 'stable'
                ? releases.where((r) => !r.isPrerelease).toList()
                : releases.where((r) => r.isPrerelease).toList();

        if (filteredReleases.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 48,
                    color:
                        theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No ${filter == 'stable' ? 'stable' : 'pre-release'} versions found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Clamp selected index
        final safeIndex = selectedIndex.clamp(0, filteredReleases.length - 1);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Version picker (horizontal scroll) ─────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredReleases.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final release = filteredReleases[index];
                    final isSelected = index == safeIndex;
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedReleaseIndexProvider.notifier)
                            .state = index;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              release.tagName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            if (index == 0 && !release.isPrerelease) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.onPrimary.withOpacity(0.2)
                                      : colorScheme
                                          .tertiaryContainer.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'Latest',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.tertiary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Filter chips ──────────────────────────────────────
              Row(
                children: [
                  _buildFilterChip(
                    theme: theme,
                    label: 'All',
                    value: 'all',
                    currentValue: filter,
                    count: releases.length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    theme: theme,
                    label: 'Stable',
                    value: 'stable',
                    currentValue: filter,
                    count: releases
                        .where((r) => !r.isPrerelease)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    theme: theme,
                    label: 'Pre-release',
                    value: 'prerelease',
                    currentValue: filter,
                    count: releases
                        .where((r) => r.isPrerelease)
                        .length,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Selected release card ─────────────────────────────
              _buildSelectedRelease(
                theme: theme,
                colorScheme: colorScheme,
                release: filteredReleases[safeIndex],
                isLatest: safeIndex == 0 &&
                    !filteredReleases[safeIndex].isPrerelease,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required String label,
    required String value,
    required String currentValue,
    required int count,
  }) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        ref.read(releaseFilterProvider.notifier).state = value;
        ref.read(selectedReleaseIndexProvider.notifier).state = 0;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedRelease({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ReleaseModel release,
    required bool isLatest,
  }) {
    final downloadState = ref.watch(downloadProvider);

    return ReleaseCard(
      release: release,
      owner: widget.owner,
      repo: widget.repo,
      isLatest: isLatest,
      isDownloading: downloadState.isDownloading,
      downloadingAssetName: downloadState.assetName,
      onDownloadAsset: ({
        required String assetName,
        required String downloadUrl,
        required int assetId,
      }) async {
        if (downloadUrl.isEmpty) return null;

        // Find the asset model from the release
        final asset = release.assets.cast<ReleaseAssetModel?>().firstWhere(
              (a) => a?.name == assetName,
              orElse: () => null,
            );

        if (asset == null) return null;

        return ref.read(downloadProvider.notifier).downloadAsset(
              asset: asset,
              owner: widget.owner,
              name: widget.repo,
              version: release.tagName,
            );
      },
    );
  }

  // ── Info Tab ────────────────────────────────────────────────────────

  Widget _buildInfoTab(
    ThemeData theme,
    ColorScheme colorScheme,
    RepositoryModel repo,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Repository Info Section ────────────────────────────────
          Text(
            'Repository',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Default branch',
                  value: repo.defaultBranch,
                  icon: Icons.account_tree_outlined,
                ),
                const _InfoDivider(),
                _InfoRow(
                  label: 'Created',
                  value: _formatDate(repo.createdAt),
                  icon: Icons.calendar_today_outlined,
                ),
                const _InfoDivider(),
                _InfoRow(
                  label: 'Last pushed',
                  value: _formatDate(repo.pushedAt),
                  icon: Icons.update,
                ),
                const _InfoDivider(),
                _InfoRow(
                  label: 'Size',
                  value: _formatSize(repo.size),
                  icon: Icons.storage_outlined,
                ),
                if (repo.license != null &&
                    repo.license!.name != null &&
                    repo.license!.name != 'NOASSERTION') ...[
                  const _InfoDivider(),
                  _InfoRow(
                    label: 'License',
                    value: repo.license!.displayName,
                    icon: Icons.scale_outlined,
                  ),
                ],
                if (repo.hasHomepage) ...[
                  const _InfoDivider(),
                  _InfoRow(
                    label: 'Homepage',
                    value: repo.homepage!,
                    icon: Icons.language,
                    isLink: true,
                    onTap: () => _launchUrl(repo.homepage!),
                  ),
                ],
                const _InfoDivider(),
                _InfoRow(
                  label: 'GitHub URL',
                  value: repo.htmlUrl ?? '',
                  icon: Icons.link,
                  isLink: true,
                  onTap: () => _launchUrl(
                      repo.htmlUrl ?? 'https://github.com/${repo.fullName}'),
                ),
              ],
            ),
          ),

          // ── Topics Section ────────────────────────────────────────
          if (repo.topics.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Topics',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: repo.topics
                  .map((topic) => Chip(
                        label: Text(topic),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],

          // ── Owner Section ─────────────────────────────────────────
          if (repo.owner != null) ...[
            const SizedBox(height: 24),
            Text(
              'Owner',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OwnerCard(owner: repo.owner!),
          ],
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(repositoryProvider(_param).notifier).refresh(),
      ref.read(releasesProvider(_param).notifier).refresh(),
      ref.read(readmeProvider(_param).notifier).refresh(),
    ]);
  }

  void _handleInstall(BuildContext context, RepositoryModel repo) {
    // Navigate to the releases tab to select an asset
    _tabController.animateTo(1);

    // If there are releases, show a snackbar with info
    final releasesAsync = ref.read(releasesProvider(_param));
    releasesAsync.whenData((releases) {
      if (releases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No releases available for download')),
        );
      }
    });
  }

  Future<void> _copyGitHubUrl() async {
    final url = 'https://github.com/${widget.owner}/${widget.repo}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GitHub URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openInBrowser() async {
    final url = 'https://github.com/${widget.owner}/${widget.repo}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Formatters ──────────────────────────────────────────────────────

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatSize(int sizeKb) {
    if (sizeKb < 1) return '0 B';
    final bytes = sizeKb * 1024;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── Info Tab Helper Widgets ──────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isLink = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isLink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isLink ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isLink
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withOpacity(0.5),
      ),
    );
  }
}

// ── Sticky Tab Delegate ──────────────────────────────────────────────────

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabDelegate({
    required this.tabController,
    required this.tabs,
  });

  final TabController tabController;
  final List<Tab> tabs;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: TabBar(
        controller: tabController,
        tabs: tabs,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
