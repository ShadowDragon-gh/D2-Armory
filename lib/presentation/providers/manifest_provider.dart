import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../data/local/manifest_downloader.dart';
import '../../data/repositories/manifest_repository.dart';
import 'character_provider.dart';

final manifestRepositoryProvider = Provider<ManifestRepository>((ref) {
  return ManifestRepository(
    api: ref.watch(bungieApiProvider),
    downloader: ManifestDownloader(DioClient.unauthenticated()),
  );
});

/// Holds the latest bootstrap progress so the loading screen can show it.
class ManifestProgressNotifier extends Notifier<ManifestProgress> {
  @override
  ManifestProgress build() => const ManifestProgress(ManifestPhase.checking);

  void update(ManifestProgress progress) => state = progress;
}

final manifestProgressProvider =
    NotifierProvider<ManifestProgressNotifier, ManifestProgress>(
        ManifestProgressNotifier.new);

/// Runs the one-time manifest bootstrap (download if needed + open). The UI
/// awaits this before showing manifest-dependent screens.
final manifestBootstrapProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(manifestRepositoryProvider);
  await repo.ensureLoaded(
    // Progress fires synchronously during this provider's build; scheduling the
    // sibling-provider write onto a microtask keeps it out of the build phase,
    // which Riverpod forbids modifying other providers within.
    onProgress: (p) => Future.microtask(
        () => ref.read(manifestProgressProvider.notifier).update(p)),
  );
});
