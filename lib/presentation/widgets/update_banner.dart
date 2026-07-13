import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/models/app_release.dart';
import '../providers/update_provider.dart';

/// App-bar action that appears only when a newer release is available. Tapping
/// it opens a dialog to download and install the update.
class UpdateAction extends ConsumerWidget {
  const UpdateAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(availableUpdateProvider).value;
    if (release == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Update available (${release.tag})',
      icon: const Icon(Icons.system_update_alt),
      color: Theme.of(context).colorScheme.primary,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _UpdateDialog(release: release),
      ),
    );
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(updateControllerProvider);
    final progress = ref.watch(updateDownloadProgressProvider);
    final busy = controller.isLoading;

    return AlertDialog(
      title: Text('Update to ${release.tag}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The app will download the update, close, apply it, and reopen.',
          ),
          if (busy) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(progress == null
                ? 'Preparing…'
                : '${(progress * 100).toStringAsFixed(0)}%'),
          ],
          if (controller.hasError) ...[
            const SizedBox(height: 16),
            Text(
              _messageFor(controller.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => ref
                  .read(updateControllerProvider.notifier)
                  .downloadAndInstall(release),
          child: const Text('Update now'),
        ),
      ],
    );
  }

  String _messageFor(Object error) =>
      error is Failure ? error.message : 'Update failed.';
}
