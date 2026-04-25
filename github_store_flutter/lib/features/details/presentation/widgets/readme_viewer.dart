import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// A markdown viewer widget that renders README content with theme-aware styling.
///
/// Handles relative image URLs by prepending the GitHub raw content base URL,
/// and provides a scrollable, themed markdown display.
class ReadmeViewer extends StatelessWidget {
  const ReadmeViewer({
    required this.markdownContent,
    required this.owner,
    required this.repo,
    this.defaultBranch = 'main',
    super.key,
  });

  final String markdownContent;
  final String owner;
  final String repo;
  final String defaultBranch;

  /// GitHub raw content URL prefix for resolving relative image URLs.
  String get _rawBaseUrl =>
      'https://raw.githubusercontent.com/$owner/$repo/$defaultBranch';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (markdownContent.isEmpty) {
      return Center(
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
                'No README found for this repository.',
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

    return SelectionArea(
      child: MarkdownBody(
        data: markdownContent,
        selectable: false,
        softLineBreak: true,
        imageBuilder: (uri, title, alt) {
          final imageUrl = _resolveImageUrl(uri.toString());
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: theme.colorScheme.error,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Image failed to load',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
        onTapLink: (text, href, title) {
          if (href == null) return;
          _launchUrl(context, href);
        },
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          // Headings
          h1: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            height: 1.3,
          ),
          h2: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            height: 1.3,
          ),
          h3: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 1.4,
          ),
          h4: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          h5: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          h6: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
          // Paragraphs
          p: theme.textTheme.bodyMedium?.copyWith(
            height: 1.7,
            fontSize: 14.5,
          ),
          // Code
          code: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: isDark
                ? const Color(0xFF1E1E2E)
                : const Color(0xFFF5F5F5),
            color: isDark
                ? const Color(0xFFCDD6F4)
                : const Color(0xFF24292F),
          ),
          codeblockDecoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2E)
                : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF313244)
                  : const Color(0xFFD0D7DE),
            ),
          ),
          codeblockPadding: const EdgeInsets.all(16),
          blockquotePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          blockquoteDecoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          // Tables
          tableHead: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          tableBorder: TableBorder.all(
            color: isDark
                ? const Color(0xFF313244)
                : const Color(0xFFD0D7DE),
            borderRadius: BorderRadius.circular(8),
          ),
          tableHeadAlign: TextAlign.left,
          tableCellsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          tableColumnWidths: const {
            0: FlexColumnWidth(1.0),
          },
          // Lists
          listBullet: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
          listIndent: 24,
          blockSpacing: 12,
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Resolve relative image URLs to absolute GitHub raw content URLs.
  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return 'https://raw.githubusercontent.com$url';
    }
    return '$_rawBaseUrl/$url';
  }

  /// Launch a URL in the browser.
  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }
}
