import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:destiny2_loadout_planner/data/repositories/manifest_repository.dart';
import 'package:destiny2_loadout_planner/presentation/providers/manifest_provider.dart';

class _MockManifestRepository extends Mock implements ManifestRepository {}

void main() {
  test(
      'bootstrap completes when the repo emits progress synchronously '
      '(no "modify other providers during init" assertion)', () async {
    final repo = _MockManifestRepository();

    // Mirror the real repository: fire a progress callback synchronously,
    // before the first await. This is what tripped the Riverpod lifecycle
    // assertion when the write was not deferred.
    when(() => repo.ensureLoaded(onProgress: any(named: 'onProgress')))
        .thenAnswer((invocation) async {
      final onProgress = invocation.namedArguments[#onProgress]
          as void Function(ManifestProgress)?;
      onProgress?.call(const ManifestProgress(ManifestPhase.checking));
      onProgress?.call(const ManifestProgress(
          ManifestPhase.downloading,
          received: 5,
          total: 10));
      onProgress?.call(const ManifestProgress(ManifestPhase.ready));
    });

    final container = ProviderContainer(overrides: [
      manifestRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // Would throw _AssertionError before the microtask deferral fix.
    await expectLater(
        container.read(manifestBootstrapProvider.future), completes);

    // Progress writes land after the build phase.
    await Future<void>.delayed(Duration.zero);
    expect(container.read(manifestProgressProvider).phase,
        ManifestPhase.ready);
  });
}
