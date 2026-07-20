import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import 'clarity_provider.dart';
import 'd2ai_provider.dart';
import 'database_provider.dart';
import 'inventory_provider.dart';
import 'manifest_provider.dart';

/// Kicks off every heavy data load once the manifest is open, so each tab's
/// data is warming in the background from startup rather than lazily on first
/// visit or first search.
///
/// It only *starts* the loads (by watching them); it never awaits or rethrows,
/// so a slow or failing load — e.g. the inventory network fetch — never blocks
/// the others. Each tab watches its own provider for readiness and shows its
/// own spinner/error; this provider just ensures all of them begin at once.
///
/// The loads run on the UI isolate (sqlite3 is synchronous and its handle is
/// not sendable to a background isolate), but each yields between chunks — the
/// gear index scan runs after a frame, and the facet index resolves in batches
/// — so warming stays responsive and tabs paint as their data lands.
final appWarmupProvider = Provider<void>((ref) {
  // Clarity community insights are independent of the manifest (a public
  // static file), so their bootstrap starts immediately, in parallel with
  // the manifest download. Nothing blocks on it.
  ref.watch(clarityBootstrapProvider);

  // d2ai source data is a bundled asset (no network), also manifest-independent
  // — start it immediately so the Source row has its cleaner text right away.
  ref.watch(d2aiBootstrapProvider);

  // Gate on the manifest: nothing below can run until the DB is open.
  if (!ref.watch(manifestBootstrapProvider).hasValue) return;

  // Inventory (live profile fetch — its own network path) and its search
  // facets (warmed on the UI isolate once the grid lands; bounded by owned
  // items — the live profile can't be read from a background isolate).
  ref.watch(inventoryGridProvider);
  ref.watch(inventoryFacetsWarmProvider);

  // Database gear indexes + search-facet indexes, every kind, in parallel.
  for (final kind in GearKind.values) {
    ref.watch(databaseIndexProvider(kind));
    ref.watch(databaseFacetsWarmProvider(kind));
  }
});
