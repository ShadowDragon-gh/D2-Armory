import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../data/repositories/manifest_repository.dart';
import '../providers/manifest_provider.dart';

/// Blocks manifest-dependent screens until the manifest is downloaded and
/// opened, showing progress and a retry on failure.
class ManifestLoadingScreen extends ConsumerWidget {
  const ManifestLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(manifestBootstrapProvider);
    final progress = ref.watch(manifestProgressProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: bootstrap.when(
            data: (_) =>
                const CircularProgressIndicator(), // brief; RootScreen swaps out
            loading: () => _Progress(progress: progress),
            error: (error, _) => _Error(
              message: error is Failure
                  ? error.message
                  : 'Could not load the Destiny manifest.',
              onRetry: () => ref.invalidate(manifestBootstrapProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final ManifestProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, showBar) = switch (progress.phase) {
      ManifestPhase.checking => ('Checking for game data updates…', false),
      ManifestPhase.downloading => ('Downloading game data…', true),
      ManifestPhase.opening => ('Preparing game data…', false),
      ManifestPhase.ready => ('Ready.', false),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          child: LinearProgressIndicator(
            value: showBar ? progress.fraction : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(label, style: theme.textTheme.bodyMedium),
        if (showBar && progress.total > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${_mb(progress.received)} / ${_mb(progress.total)} MB',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off,
            size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
