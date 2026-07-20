import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/exotic_ability_repository.dart';
import 'manifest_provider.dart';

/// The curated exotic-armor → ability interaction repository, backed by the
/// open manifest (for exotic icons).
final exoticAbilityRepositoryProvider =
    Provider<ExoticAbilityRepository>((ref) {
  return ExoticAbilityRepository(
    manifest: ref.watch(manifestRepositoryProvider),
  );
});

/// Loads the curated exotic-ability map once the manifest is open (it resolves
/// exotic icons from the manifest). Never awaited by a screen: the badge is
/// pure enrichment that appears once this resolves.
final exoticAbilityBootstrapProvider = FutureProvider<void>((ref) async {
  // The map needs the manifest for icons; wait for it to open first.
  if (!ref.watch(manifestBootstrapProvider).hasValue) return;
  await ref.watch(exoticAbilityRepositoryProvider).ensureLoaded();
});

/// The exotic-ability repository once its map has loaded, or null while it is
/// still loading (or unavailable). Watches the bootstrap so a widget rebuilds
/// when the map lands. Callers run the fine-grained socket query themselves via
/// [ExoticAbilityRepository.exoticsFor] — its arguments include a set of plug
/// names, which is not a stable provider-family key, so the query is not itself
/// a provider.
final loadedExoticAbilityRepositoryProvider =
    Provider<ExoticAbilityRepository?>((ref) {
  ref.watch(exoticAbilityBootstrapProvider);
  final repo = ref.watch(exoticAbilityRepositoryProvider);
  return repo.isReady ? repo : null;
});
