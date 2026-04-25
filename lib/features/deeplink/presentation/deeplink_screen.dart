import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/deeplink_repository.dart';
import 'deeplink_handler.dart';

/// Provider for the [DeeplinkRepository].
final deeplinkRepositoryProvider = Provider<DeeplinkRepository>((ref) {
  return DeeplinkRepository();
});

/// Deep link handler screen — a diagnostic/debug view.
///
/// In production the deep link handling is done automatically via the
/// [DeepLinkHandlerMixin] on the app widget. This screen exists for
/// testing and debugging deep link parsing.
class DeepLinkScreen extends ConsumerStatefulWidget {
  const DeepLinkScreen({super.key});

  @override
  ConsumerState<DeepLinkScreen> createState() => _DeepLinkScreenState();
}

class _DeepLinkScreenState extends ConsumerState<DeepLinkScreen>
    with DeepLinkHandlerMixin {
  final TextEditingController _urlController = TextEditingController();
  DeeplinkResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // Example URL for quick testing
    _urlController.text = 'githubstore://repo/flutter/flutter';
  }

  @override
  void dispose() {
    _urlController.dispose();
    disposeDeepLinkHandler();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Handler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_outlined),
            tooltip: 'Register Protocol',
            onPressed: () async {
              await registerDeepLinkHandler();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Protocol registration attempted.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── URL Input ───────────────────────────────────────────────
            Text(
              'Test Deep Link',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'githubstore://repo/owner/name',
                prefixIcon: Icon(Icons.link_outlined),
                suffixIcon: Icon(Icons.send),
              ),
              onSubmitted: (_) => _parseUrl(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _parseUrl,
                child: const Text('Parse & Navigate'),
              ),
            ),
            const SizedBox(height: 24),

            // ── Result ──────────────────────────────────────────────────
            if (_lastResult != null) ...[
              Text(
                'Parsed Result',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResultRow(
                        label: 'Type',
                        value: _lastResult!.type.name,
                      ),
                      if (_lastResult!.owner != null)
                        _ResultRow(
                          label: 'Owner',
                          value: _lastResult!.owner!,
                        ),
                      if (_lastResult!.repo != null)
                        _ResultRow(
                          label: 'Repo',
                          value: _lastResult!.repo!,
                        ),
                      if (_lastResult!.fullName != null)
                        _ResultRow(
                          label: 'Full Name',
                          value: _lastResult!.fullName!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Supported Formats ───────────────────────────────────────
            Text(
              'Supported URL Formats',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormatItem(
                    icon: Icons.link,
                    format: 'githubstore://repo/{owner}/{name}',
                    description: 'Custom app scheme',
                  ),
                  const Divider(height: 1),
                  _FormatItem(
                    icon: Icons.language,
                    format: 'https://github.com/{owner}/{name}',
                    description: 'GitHub direct link',
                  ),
                  const Divider(height: 1),
                  _FormatItem(
                    icon: Icons.storefront,
                    format: 'https://github-store.org/app?repo={owner}/{name}',
                    description: 'GitHub Store web link',
                  ),
                  const Divider(height: 1),
                  _FormatItem(
                    icon: Icons.short_text,
                    format: '{owner}/{name}',
                    description: 'Bare owner/repo format',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Platform Info ───────────────────────────────────────────
            Text(
              'Platform Setup',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To register the githubstore:// protocol on your '
                      'platform, tap the register button in the app bar.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Windows: Registry keys are written to HKCU.',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '• macOS: Add CFBundleURLTypes to Info.plist.',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '• Linux: A .desktop file is created with '
                      'x-scheme-handler/githubstore.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _parseUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final result = ref.read(deeplinkRepositoryProvider).parse(url);
    setState(() => _lastResult = result);

    // Attempt navigation
    final handled = handleDeeplink(url);
    if (!handled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unrecognised URL format.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatItem extends StatelessWidget {
  const _FormatItem({
    required this.icon,
    required this.format,
    required this.description,
  });

  final IconData icon;
  final String format;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(
        format,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(description),
      dense: true,
    );
  }
}
