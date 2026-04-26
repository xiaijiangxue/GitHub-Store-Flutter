import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/repository_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import '../data/dev_profile_repository.dart';
import 'providers/dev_profile_provider.dart';

/// Developer profile screen showing user info and their repositories.
///
/// Features a hero header with avatar, name, bio, stats, company/location/
/// blog links, and a scrollable repository list with filter, sort, search,
/// and infinite-scroll pagination.
class DevProfileScreen extends ConsumerStatefulWidget {
  const DevProfileScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<DevProfileScreen> createState() => _DevProfileScreenState();
}

class _DevProfileScreenState extends ConsumerState<DevProfileScreen> {
  bool _showAllRepos = false;
  bool _reposInitialized = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _ensureReposLoaded() {
    if (!_reposInitialized) {
      _reposInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userReposNotifierProvider).loadRepos(widget.username);
      });
    }
  }

  Future<void> _loadMore() async {
    final notifier = ref.read(userReposNotifierProvider);
    if (!notifier.hasMore || notifier.isLoading || !_showAllRepos) return;
    await notifier.loadMore(widget.username);
  }

  Future<void> _shareProfile() async {
    final url = 'https://github.com/${widget.username}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile link copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    // Handle URLs without protocol
    final uri = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    final parsed = Uri.tryParse(uri);
    if (parsed != null) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureReposLoaded();

    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider(widget.username));
    final repos = ref.watch(userReposProvider);
    final reposLoading = ref.watch(userReposIsLoadingProvider);
    final filteredRepos = ref.watch(filteredReposProvider);
    final filter = ref.watch(repoFilterProvider);
    final sort = ref.watch(repoSortProvider);
    final search = ref.watch(repoSearchProvider);
    final isLoadingMore = ref.watch(userReposIsLoadingProvider);
    final hasMore = ref.watch(userReposHasMoreProvider);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
              tooltip: 'Back',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Copy profile link',
                onPressed: _shareProfile,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text('@${widget.username}'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.secondaryContainer.withValues(alpha: 0.08),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Profile Header ───────────────────────────────────────────────
          profileAsync.when(
            loading: () => SliverToBoxAdapter(
              child: _ProfileShimmer(),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: _ErrorView(
                message: 'Failed to load profile',
                error: error,
                onRetry: () => ref.invalidate(
                  userProfileProvider(widget.username),
                ),
              ),
            ),
            data: (user) => SliverToBoxAdapter(
              child: _ProfileHeader(
                user: user,
                onBlogTap: () => _openUrl(user.blog),
                onOpenGitHub: () =>
                    _openUrl('https://github.com/${user.login}'),
              ),
            ),
          ),

          // ── Tab Toggle ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Pinned Repos'),
                    icon: Icon(Icons.push_pin, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('All Repos'),
                    icon: Icon(Icons.list, size: 16),
                  ),
                ],
                selected: {_showAllRepos},
                onSelectionChanged: (selected) {
                  setState(() {
                    _showAllRepos = selected.first;
                  });
                },
              ),
            ),
          ),

          // ── Repos Content ────────────────────────────────────────────────
          if (!_showAllRepos)
            SliverToBoxAdapter(
              child: reposLoading && repos.isEmpty
                  ? _ReposShimmer()
                  : repos.isEmpty
                      ? const _EmptyReposView(
                          message: 'No public repositories found')
                      : _PinnedReposGrid(
                          repos: repos.take(6).toList(),
                          username: widget.username,
                        ),
            )
          else ...[
            // Filters & Search
            SliverToBoxAdapter(
              child: _RepoControls(
                filter: filter,
                sort: sort,
                search: search,
                onFilterChanged: (f) {
                  ref.read(repoFilterProvider.notifier).state = f;
                },
                onSortChanged: (s) {
                  ref.read(repoSortProvider.notifier).state = s;
                },
                onSearchChanged: (q) {
                  ref.read(repoSearchProvider.notifier).state = q;
                },
              ),
            ),

            // Repo count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '${filteredRepos.length} repositor${filteredRepos.length != 1 ? 'ies' : 'y'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),

            // Repo list
            if (filteredRepos.isEmpty)
              const SliverToBoxAdapter(
                child: _EmptyReposView(
                    message: 'No repositories match your filter'),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final repo = filteredRepos[index];
                    return _RepoListItem(
                      repo: repo,
                      username: widget.username,
                      onTap: () => context.push(
                        AppRoute.details.withParams({
                          'owner': repo.ownerLogin,
                          'repo': repo.name,
                        }),
                      ),
                    );
                  },
                  childCount: filteredRepos.length,
                ),
              ),

            // Loading more indicator
            if (isLoadingMore && filteredRepos.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // Load more trigger
            if (hasMore && !isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load more repositories'),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ],
      ),
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.user,
    required this.onBlogTap,
    required this.onOpenGitHub,
  });

  final UserModel user;
  final VoidCallback onBlogTap;
  final VoidCallback onOpenGitHub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              CircleAvatar(
                radius: 52,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    CachedNetworkImageProvider(user.avatarUrl!),
              )
            else
              CircleAvatar(
                radius: 52,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.login[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 40,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Name
            Text(
              user.displayName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.login}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),

            // Bio
            if (user.hasBio) ...[
              const SizedBox(height: 10),
              Text(
                user.bio!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 18),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProfileStat(
                  value: DevProfileRepository.formatCount(user.publicRepos),
                  label: 'Repos',
                  theme: theme,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                ),
                _ProfileStat(
                  value: user.formattedFollowers,
                  label: 'Followers',
                  theme: theme,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: theme.colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                ),
                _ProfileStat(
                  value: user.formattedFollowing,
                  label: 'Following',
                  theme: theme,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Info rows: company, location, blog (tappable)
            if (user.hasCompany)
              _InfoRow(
                icon: Icons.business,
                text: user.company!,
              ),
            if (user.hasLocation)
              _InfoRow(
                icon: Icons.location_on,
                text: user.location!,
              ),
            if (user.hasBlog)
              GestureDetector(
                onTap: onBlogTap,
                child: _InfoRow(
                  icon: Icons.link,
                  text: user.blog!,
                  isLink: true,
                ),
              ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: 'https://github.com/${user.login}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile link copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Profile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenGitHub,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open on GitHub'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    required this.theme,
  });

  final String value;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.isLink = false,
  });

  final IconData icon;
  final String text;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isLink
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pinned Repos Grid ─────────────────────────────────────────────────────

class _PinnedReposGrid extends StatelessWidget {
  const _PinnedReposGrid({
    required this.repos,
    required this.username,
  });

  final List<RepositoryModel> repos;
  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Pinned Repositories',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: repos.length,
            itemBuilder: (context, index) {
              final repo = repos[index];
              return _PinnedRepoCard(
                repo: repo,
                username: username,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PinnedRepoCard extends StatelessWidget {
  const _PinnedRepoCard({
    required this.repo,
    required this.username,
  });

  final RepositoryModel repo;
  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            AppRoute.details.withParams({
              'owner': repo.ownerLogin,
              'repo': repo.name,
            }),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: repo.ownerAvatarUrl != null
                        ? CachedNetworkImageProvider(repo.ownerAvatarUrl!)
                        : null,
                    child: repo.ownerAvatarUrl == null
                        ? Text(
                            username[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
              const SizedBox(height: 8),

              // Description
              if (repo.description != null &&
                  repo.description!.isNotEmpty)
                Expanded(
                  child: Text(
                    repo.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Footer
              const SizedBox(height: 8),
              Row(
                children: [
                  if (repo.language != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _parseColor(repo.languageColor),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      repo.language!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                  ],
                  const Icon(
                    Icons.star_outline,
                    size: 14,
                    color: Color(0xFF9E9E9E),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    repo.formattedStars,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
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

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return Colors.grey;
  }
}

// ── Repo Controls ─────────────────────────────────────────────────────────

class _RepoControls extends StatelessWidget {
  const _RepoControls({
    required this.filter,
    required this.sort,
    required this.search,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
  });

  final RepoFilter filter;
  final RepoSort sort;
  final String search;
  final ValueChanged<RepoFilter> onFilterChanged;
  final ValueChanged<RepoSort> onSortChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search repositories...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => onSearchChanged(''),
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
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 8),

          // Filter chips and sort
          Row(
            children: [
              // Filter chips
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: RepoFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final f = RepoFilter.values[index];
                      return ChoiceChip(
                        label: Text(
                          f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: filter == f,
                        onSelected: (_) => onFilterChanged(f),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
              ),

              // Sort dropdown
              PopupMenuButton<RepoSort>(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: 'Sort',
                onSelected: onSortChanged,
                itemBuilder: (context) => RepoSort.values
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              if (s == sort)
                                const Icon(Icons.check, size: 16)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Repo List Item ────────────────────────────────────────────────────────

class _RepoListItem extends StatelessWidget {
  const _RepoListItem({
    required this.repo,
    required this.username,
    required this.onTap,
  });

  final RepositoryModel repo;
  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: repo.ownerAvatarUrl != null
            ? CachedNetworkImageProvider(repo.ownerAvatarUrl!)
            : null,
        child: repo.ownerAvatarUrl == null
            ? Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              repo.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (repo.isPrivate) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.lock,
              size: 14,
              color: Color(0xFF9E9E9E),
            ),
          ],
          if (repo.isArchived) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Archived',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: repo.description != null
          ? Text(
              repo.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (repo.language != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _parseColor(repo.languageColor),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              repo.language!,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 12),
          ],
          if (repo.hasLatestRelease) ...[
            const Icon(
              Icons.tag,
              size: 14,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(width: 2),
            Text(
              repo.latestReleaseTag ?? '',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Icon(
            Icons.star_outline,
            size: 14,
            color: Color(0xFF9E9E9E),
          ),
          const SizedBox(width: 2),
          Text(
            repo.formattedStars,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    return Colors.grey;
  }
}

// ── Shimmer / Loading ─────────────────────────────────────────────────────

class _ProfileShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 160,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (_) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReposShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Error & Empty States ──────────────────────────────────────────────────

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

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
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
    );
  }
}

class _EmptyReposView extends StatelessWidget {
  const _EmptyReposView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
