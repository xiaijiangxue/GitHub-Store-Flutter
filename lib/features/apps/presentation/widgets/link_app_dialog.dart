import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/installed_app_model.dart';
import '../../../../core/models/release_asset_model.dart';
import '../../../../core/models/release_model.dart';
import '../../../../core/network/github_store_api.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../providers/apps_provider.dart';

/// Dialog for linking existing installed apps to their GitHub repositories.
///
/// Three-step process:
/// 1. Enter GitHub repo URL (with validation)
/// 2. Select matching release asset
/// 3. Confirm and link
class LinkAppDialog extends ConsumerStatefulWidget {
  const LinkAppDialog({super.key});

  @override
  ConsumerState<LinkAppDialog> createState() => _LinkAppDialogState();
}

class _LinkAppDialogState extends ConsumerState<LinkAppDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _versionController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorText;

  // Parsed repo info
  String _owner = '';
  String _repoName = '';

  // Available releases and assets
  List<ReleaseModel> _releases = [];
  ReleaseModel? _selectedRelease;
  ReleaseAssetModel? _selectedAsset;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _parseRepoUrl() async {
    final url = _urlController.text.trim();
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      // Parse GitHub URL
      final parsed = _parseGitHubUrl(url);
      if (parsed == null) {
        setState(() {
          _errorText =
              'Invalid GitHub URL. Expected format: '
              'https://github.com/owner/repo';
          _isLoading = false;
        });
        return;
      }

      _owner = parsed.$1;
      _repoName = parsed.$2;

      // Fetch releases
      final storeApi = ref.read(githubStoreApiProvider);
      _releases = await storeApi.getReleases(_owner, _repoName);

      if (_releases.isEmpty) {
        setState(() {
          _errorText = 'No releases found for $_owner/$_repoName';
          _isLoading = false;
        });
        return;
      }

      // Auto-select latest non-prerelease
      _selectedRelease = _releases.firstWhere(
        (r) => !r.isPrerelease && !r.isDraft,
        orElse: () => _releases.first,
      );

      // Auto-set version
      _versionController.text = _selectedRelease?.tagName ?? '';

      if (mounted) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Failed to fetch repo info: ${_toString(e)}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkApp() async {
    setState(() => _isLoading = true);

    try {
      final app = InstalledAppModel(
        id: 0, // Will be auto-generated
        owner: _owner,
        name: _repoName,
        fullName: '$_owner/$_repoName',
        installedVersion: _selectedRelease?.tagName,
        installedAssetUrl: _selectedAsset?.downloadUrl,
        installedAssetName: _selectedAsset?.name,
        installMethod: 'linked',
        installedAt: DateTime.now(),
      );

      final repo = ref.read(appsRepositoryProvider);
      await repo.addInstalledApp(app);
      await ref.read(installedAppsProvider.notifier).refresh();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Linked $_repoName (${_selectedRelease?.tagName ?? 'unknown version'})'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Failed to link app: ${_toString(e)}';
          _isLoading = false;
        });
      }
    }
  }

  (String, String)? _parseGitHubUrl(String url) {
    // Support formats:
    // https://github.com/owner/repo
    // https://github.com/owner/repo/
    // github.com/owner/repo
    // owner/repo

    String cleaned = url.trim();
    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      final uri = Uri.tryParse(cleaned);
      if (uri == null) return null;
      cleaned = uri.path;
    }

    // Remove leading/trailing slashes
    cleaned = cleaned.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');

    final parts = cleaned.split('/');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0], parts[1]);
    }

    return null;
  }

  String _toString(dynamic error) {
    if (error is Exception) return error.toString();
    return error?.toString() ?? 'Unknown error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Link Installed App'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            Row(
              children: List.generate(3, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? theme.colorScheme.primary
                              : isActive
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(Icons.check, size: 14,
                                  color: theme.colorScheme.onPrimary)
                              : Text(
                                  '${index + 1}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.outline,
                                  ),
                                ),
                        ),
                      ),
                      if (index < 2)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Step content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (_currentStep == 0) _buildStep1(theme),
              if (_currentStep == 1) _buildStep2(theme),
              if (_currentStep == 2) _buildStep3(theme),
            ],

            // Error message
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_currentStep > 0 && !_isLoading)
          TextButton(
            onPressed: () {
              setState(() {
                _currentStep--;
                _errorText = null;
              });
            },
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_currentStep < 2 && !_isLoading)
          FilledButton(
            onPressed: _currentStep == 0 ? _parseRepoUrl : _goToStep3,
            child: Text(_currentStep == 0 ? 'Find Repo' : 'Continue'),
          ),
        if (_currentStep == 2 && !_isLoading)
          FilledButton(
            onPressed: _linkApp,
            child: const Text('Link'),
          ),
      ],
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1: Enter GitHub Repo URL',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the URL of the GitHub repository for the app you want to link.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://github.com/owner/repo',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _parseRepoUrl(),
        ),
        const SizedBox(height: 12),
        Text(
          'Tip: You can also enter "owner/repo" directly.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Select Release & Asset',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_owner/$_repoName',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Release selector
        Text('Release:', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        DropdownButtonFormField<ReleaseModel>(
          value: _selectedRelease,
          isDense: true,
          decoration: const InputDecoration(),
          items: _releases.map((r) {
            return DropdownMenuItem(
              value: r,
              child: Text(
                '${r.tagName}${r.isPrerelease ? ' (pre-release)' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (release) {
            setState(() {
              _selectedRelease = release;
              _selectedAsset = null;
              _versionController.text = release?.tagName ?? '';
            });
          },
        ),

        const SizedBox(height: 16),

        // Asset selector
        if (_selectedRelease != null &&
            _selectedRelease!.assets.isNotEmpty) ...[
          Text('Asset:', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          DropdownButtonFormField<ReleaseAssetModel>(
            value: _selectedAsset,
            isDense: true,
            decoration: const InputDecoration(),
            items: _selectedRelease!.assets.map((a) {
              return DropdownMenuItem(
                value: a,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            a.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${a.formattedSize} · ${a.platform.displayName}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            hint: const Text('Select an asset (optional)'),
            onChanged: (asset) {
              setState(() => _selectedAsset = asset);
            },
          ),
        ],
      ],
    );
  }

  void _goToStep3() {
    setState(() {
      _currentStep = 2;
      _errorText = null;
    });
  }

  Widget _buildStep3(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Confirm Linking',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                label: 'Repository',
                value: '$_owner/$_repoName',
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Version',
                value: _selectedRelease?.tagName ?? 'Not selected',
              ),
              if (_selectedAsset != null) ...[
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Asset',
                  value: _selectedAsset!.name,
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Platform',
                  value: _selectedAsset!.platform.displayName,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
