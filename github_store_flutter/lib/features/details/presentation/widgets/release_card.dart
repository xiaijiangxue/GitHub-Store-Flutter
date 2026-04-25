import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/models/release_model.dart';
import 'asset_list_tile.dart';

/// A card widget that displays a single GitHub release with its metadata,
/// release notes (expandable), and downloadable assets.
class ReleaseCard extends StatefulWidget {
  const ReleaseCard({
    required this.release,
    required this.owner,
    required this.repo,
    this.isLatest = false,
    this.onDownloadAsset,
    this.isDownloading = false,
    this.downloadingAssetName,
    super.key,
  });

  final ReleaseModel release;
  final String owner;
  final String repo;
  final bool isLatest;
  final Future<String?> Function({
    required String assetName,
    required String downloadUrl,
    required int assetId,
  })? onDownloadAsset;
  final bool isDownloading;
  final String? downloadingAssetName;

  @override
  State<ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<ReleaseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = widget.release;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          _buildHeader(theme, release),

          // ── Meta Info ───────────────────────────────────────────────
          _buildMetaInfo(theme, release),

          // ── Release Notes (expandable) ──────────────────────────────
          if (release.body != null && release.body!.isNotEmpty) ...[
            _buildNotesSection(theme, release),
          ],

          // ── Assets ─────────────────────────────────────────────────
          if (release.assets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assets (${release.assets.length})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...release.assets.map(
                    (asset) => AssetListTile(
                      asset: asset,
                      isLatest: widget.isLatest,
                      isPrimary: widget.isLatest &&
                          AssetListTile.isBestMatchForPlatform(asset),
                      isDownloading: widget.isDownloading &&
                          widget.downloadingAssetName == asset.name,
                      onDownload: widget.onDownloadAsset != null
                          ? () => widget.onDownloadAsset!(
                                assetName: asset.name,
                                downloadUrl: asset.downloadUrl ?? '',
                                assetId: asset.id,
                              )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ReleaseModel release) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isLatest
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      child: Row(
        children: [
          // Tag badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              release.tagName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          if (widget.isLatest) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Latest',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
          if (release.isPrerelease) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Pre-release',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaInfo(ThemeData theme, ReleaseModel release) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          if (release.author != null) ...[
            CircleAvatar(
              radius: 10,
              backgroundImage: release.author!.avatarUrl != null
                  ? CachedNetworkImageProvider(release.author!.avatarUrl!)
                  : null,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: release.author!.avatarUrl == null
                  ? Text(
                      release.author!.login[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              release.author!.login,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              ' released this on ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          Text(
            _formatDate(release.publishedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, ReleaseModel release) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        title: Text(
          'Release Notes',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 20,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              release.body ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'unknown date';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    }
    return '${(diff.inDays / 365).floor()} years ago';
  }
}
