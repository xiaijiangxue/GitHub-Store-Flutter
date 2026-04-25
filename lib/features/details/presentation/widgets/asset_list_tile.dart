import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/models/release_asset_model.dart';

/// A list tile widget for displaying a downloadable release asset.
///
/// Shows the asset name, platform icon, file size, architecture badge,
/// and a download button. Highlights the best-matching asset for the
/// current platform.
class AssetListTile extends StatelessWidget {
  const AssetListTile({
    required this.asset,
    this.isLatest = false,
    this.isPrimary = false,
    this.isDownloading = false,
    this.onDownload,
    super.key,
  });

  final ReleaseAssetModel asset;
  final bool isLatest;
  final bool isPrimary;
  final bool isDownloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primaryContainer.withOpacity(0.2)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: isPrimary
            ? Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Platform icon
            _buildPlatformIcon(theme),
            const SizedBox(width: 10),

            // Asset info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      if (isPrimary) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Recommended',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          asset.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isPrimary
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Meta row: platform, arch, size
                  Row(
                    children: [
                      Text(
                        asset.platform.displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      if (asset.architecture !=
                          ReleaseAssetArchitecture.unknown) ...[
                        Text(
                          ' · ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          asset.architecture.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      Text(
                        ' · ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        asset.formattedSize,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      if (asset.downloadCount > 0) ...[
                        Text(
                          ' · ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${asset.downloadCount} downloads',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Download button
            const SizedBox(width: 8),
            _buildDownloadButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(ThemeData theme) {
    final iconData = _getPlatformIcon();
    final iconColor = _getPlatformColor(theme);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(iconData, size: 18, color: iconColor),
    );
  }

  IconData _getPlatformIcon() {
    return switch (asset.platform) {
      ReleaseAssetPlatform.android => Icons.android,
      ReleaseAssetPlatform.macos => Icons.apple,
      ReleaseAssetPlatform.windows => Icons.laptop_windows,
      ReleaseAssetPlatform.linux => Icons.laptop_mac,
      ReleaseAssetPlatform.ios => Icons.phone_iphone,
      ReleaseAssetPlatform.unknown => Icons.insert_drive_file,
    };
  }

  Color _getPlatformColor(ThemeData theme) {
    return switch (asset.platform) {
      ReleaseAssetPlatform.android => const Color(0xFF3DDC84),
      ReleaseAssetPlatform.macos => const Color(0xFF555555),
      ReleaseAssetPlatform.windows => const Color(0xFF0078D4),
      ReleaseAssetPlatform.linux => const Color(0xFFDD4814),
      ReleaseAssetPlatform.ios => const Color(0xFF999999),
      ReleaseAssetPlatform.unknown => theme.colorScheme.onSurfaceVariant,
    };
  }

  Widget _buildDownloadButton(ThemeData theme) {
    if (isDownloading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (onDownload == null) return const SizedBox.shrink();

    return IconButton.filledTonal(
      onPressed: onDownload,
      icon: const Icon(Icons.download, size: 18),
      tooltip: 'Download ${asset.name}',
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// Detect if this asset is the best match for the current platform.
  static bool isBestMatchForPlatform(ReleaseAssetModel asset) {
    final currentPlatform = _detectCurrentPlatform();
    return asset.platform == currentPlatform;
  }

  static ReleaseAssetPlatform _detectCurrentPlatform() {
    if (Platform.isAndroid) return ReleaseAssetPlatform.android;
    if (Platform.isMacOS) return ReleaseAssetPlatform.macos;
    if (Platform.isWindows) return ReleaseAssetPlatform.windows;
    if (Platform.isLinux) return ReleaseAssetPlatform.linux;
    if (Platform.isIOS) return ReleaseAssetPlatform.ios;
    return ReleaseAssetPlatform.unknown;
  }
}
