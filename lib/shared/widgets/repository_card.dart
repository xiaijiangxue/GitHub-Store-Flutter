import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A compact, rich card widget displaying repository information.
///
/// Designed for grid/list layouts in the GitHub Store home, search results,
/// favorites, and recently viewed screens. Supports multiple density modes
/// and interactive states.
class RepositoryCard extends StatefulWidget {
  const RepositoryCard({
    required this.fullName,
    required this.description,
    required this.owner,
    required this.repoName,
    this.avatarUrl,
    this.language,
    this.languageColor,
    this.stargazersCount = 0,
    this.forksCount = 0,
    this.topics = const [],
    this.isFavorite = false,
    this.isStarred = false,
    this.latestVersion,
    this.updatedAt,
    this.isArchived = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onStarToggle,
    this.onOwnerTap,
    this.density = CardDensity.normal,
    this.showTopics = true,
    super.key,
  });

  // ── Required Fields ────────────────────────────────────────────────────

  /// Full repository name (e.g. "flutter/flutter").
  final String fullName;

  /// Repository description.
  final String description;

  /// Owner login / organization name.
  final String owner;

  /// Repository name (without owner).
  final String repoName;

  // ── Optional Display Fields ────────────────────────────────────────────

  /// Avatar URL for the repository owner.
  final String? avatarUrl;

  /// Primary language name (e.g. "Dart").
  final String? language;

  /// Color for the language indicator dot.
  final String? languageColor;

  /// Number of stargazers.
  final int stargazersCount;

  /// Number of forks.
  final int forksCount;

  /// Topic tags associated with the repository.
  final List<String> topics;

  /// Whether this repository is bookmarked/favorited.
  final bool isFavorite;

  /// Whether the user has starred this repository.
  final bool isStarred;

  /// Latest release tag (e.g. "v3.22.0").
  final String? latestVersion;

  /// When the repository was last updated.
  final DateTime? updatedAt;

  /// Whether the repository is archived (read-only).
  final bool isArchived;

  // ── Callbacks ──────────────────────────────────────────────────────────

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the favorite button is pressed.
  final VoidCallback? onFavoriteToggle;

  /// Called when the star button is pressed.
  final VoidCallback? onStarToggle;

  /// Called when the owner avatar/name is tapped.
  final VoidCallback? onOwnerTap;

  // ── Display Options ────────────────────────────────────────────────────

  /// Visual density of the card.
  final CardDensity density;

  /// Whether to show topic chips.
  final bool showTopics;

  @override
  State<RepositoryCard> createState() => _RepositoryCardState();
}

class _RepositoryCardState extends State<RepositoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = widget.density == CardDensity.compact;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: _elevationAnimation.value,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 10 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header: Avatar + Name ────────────────────────
                      _buildHeader(theme, isCompact),

                      // ── Description ────────────────────────────────────
                      if (widget.description.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 6 : 8),
                        _buildDescription(theme, isCompact),
                      ],

                      // ── Topics ─────────────────────────────────────────
                      if (widget.showTopics && widget.topics.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 6 : 8),
                        _buildTopics(theme, isCompact),
                      ],

                      // ── Footer: Stats + Actions ───────────────────────
                      SizedBox(height: isCompact ? 6 : 10),
                      _buildFooter(theme),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isCompact) {
    return Row(
      children: [
        // Owner avatar
        GestureDetector(
          onTap: widget.onOwnerTap,
          child: _buildAvatar(isCompact),
        ),
        SizedBox(width: isCompact ? 8 : 10),
        // Full name
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: widget.onOwnerTap,
                  child: Text(
                    widget.owner,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                  widget.repoName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isArchived) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Archived',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(bool isCompact) {
    final size = isCompact ? 24.0 : 32.0;
    if (widget.avatarUrl == null || widget.avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          widget.owner.isNotEmpty ? widget.owner[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontSize: isCompact ? 10 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: CachedNetworkImageProvider(widget.avatarUrl!),
    );
  }

  Widget _buildDescription(ThemeData theme, bool isCompact) {
    final maxLines = isCompact ? 2 : 3;
    return Text(
      widget.description,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
        fontSize: isCompact ? 12 : 13,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTopics(ThemeData theme, bool isCompact) {
    final displayTopics = widget.topics.take(isCompact ? 2 : 3).toList();
    return SizedBox(
      height: isCompact ? 20 : 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayTopics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final topic = displayTopics[index];
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : 8,
              vertical: isCompact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              topic,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: isCompact ? 10 : 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      children: [
        // Language
        if (widget.language != null && widget.language!.isNotEmpty) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _parseColor(widget.languageColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            widget.language!,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(width: 12),
        ],

        // Stars
        Icon(
          Icons.star_outline,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          _formatCount(widget.stargazersCount),
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(width: 12),

        // Forks
        Icon(
          Icons.fork_right,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          _formatCount(widget.forksCount),
          style: theme.textTheme.labelSmall,
        ),

        // Latest version (if available)
        if (widget.latestVersion != null) ...[
          const SizedBox(width: 12),
          Icon(
            Icons.tag,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            widget.latestVersion!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],

        const Spacer(),

        // Favorite button
        _buildIconButton(
          icon: widget.isFavorite
              ? Icons.bookmark
              : Icons.bookmark_border,
          color: widget.isFavorite
              ? theme.colorScheme.tertiary
              : theme.colorScheme.outline,
          onTap: widget.onFavoriteToggle,
          tooltip: widget.isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),

        const SizedBox(width: 2),

        // Star button
        _buildIconButton(
          icon: widget.isStarred ? Icons.star : Icons.star_outline,
          color: widget.isStarred
              ? const Color(0xFFE3B341)
              : theme.colorScheme.outline,
          onTap: widget.onStarToggle,
          tooltip: widget.isStarred ? 'Unstar' : 'Star',
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  void _setHovered(bool hovered) {
    if (hovered && !_isHovered) {
      _isHovered = true;
      _controller.forward();
    } else if (!hovered && _isHovered) {
      _isHovered = false;
      _controller.reverse();
    }
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Theme.of(context).colorScheme.outline;
    }
    try {
      final hex = hexColor.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return Theme.of(context).colorScheme.outline;
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

/// Visual density mode for the card.
enum CardDensity {
  compact,
  normal,
  comfortable;

  double get contentPadding => switch (this) {
        CardDensity.compact => 10,
        CardDensity.normal => 14,
        CardDensity.comfortable => 18,
      };
}
