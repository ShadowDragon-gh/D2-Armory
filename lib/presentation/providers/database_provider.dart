import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../core/search/item_filter.dart';
import '../../data/repositories/database_repository.dart';
import '../../domain/models/item_detail.dart';
import 'manifest_provider.dart';

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository(manifest: ref.watch(manifestRepositoryProvider));
});

/// Which gear family the Database is browsing (the Weapons/Armor toggle). This
/// is the only structured facet left: it selects which per-kind index and
/// facet cache the list and search read. Every other facet (rarity, type,
/// element, ammo, breaker, frame…) is expressed through the search bar
/// ([databaseSearchProvider]) and evaluated by the shared search grammar.
class DatabaseFilter {
  const DatabaseFilter({this.kind = GearKind.weapon});

  final GearKind kind;

  GearFilter toGearFilter() => GearFilter(kind: kind);
}

class DatabaseFilterNotifier extends Notifier<DatabaseFilter> {
  @override
  DatabaseFilter build() => const DatabaseFilter();

  void setKind(GearKind kind) => state = DatabaseFilter(kind: kind);
}

final databaseFilterProvider =
    NotifierProvider<DatabaseFilterNotifier, DatabaseFilter>(
        DatabaseFilterNotifier.new);

/// The Database tab's free-text search string (name / `is:` keywords), kept
/// separate from the inventory search so the two tabs do not share a query.
class DatabaseSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
  void clear() => state = '';
}

final databaseSearchProvider =
    NotifierProvider<DatabaseSearchNotifier, String>(
        DatabaseSearchNotifier.new);

final _databaseCompiledQueryProvider = Provider<CompiledQuery>((ref) {
  // Definitions carry no instance data, so power/masterwork/equipped/locked
  // terms are flagged as unsupported rather than silently matching nothing.
  // The kind (not the other facets) selects which precomputed facet index the
  // stat:/perk:/source:/breaker: filters read, so only it is watched here.
  final kind = ref.watch(databaseFilterProvider.select((f) => f.kind));
  final repo = ref.watch(databaseRepositoryProvider);
  return compileQuery(
    ref.watch(databaseSearchProvider),
    instanceDataAvailable: false,
    facetsOf: (item) => repo.facetsFor(kind, item.itemHash),
  );
});

/// A kind's full gear index, built asynchronously (off the first-paint path,
/// yielding the frame before the ~800ms manifest scan). This is the per-kind
/// readiness signal: the Database list waits on it, and startup warms both
/// kinds in parallel. Cached in the repository, so switching kinds/tabs reuses
/// the build rather than re-scanning.
final databaseIndexProvider =
    FutureProvider.family<List<GearSummary>, GearKind>((ref, kind) {
  return ref.watch(databaseRepositoryProvider).warmIndex(kind);
});

/// A kind's search-facet index (perk pools, stats, breaker, source), resolved
/// in yielding batches. Warmed at startup so the first `stat:`/`perk:`/`frame:`
/// search is instant; the search grammar reads the per-item cache directly.
final databaseFacetsWarmProvider =
    FutureProvider.family<void, GearKind>((ref, kind) {
  return ref.watch(databaseRepositoryProvider).warmFacets(kind);
});

/// The gear matching the current facets, once the active kind's index is warm.
/// Waits on [databaseIndexProvider] so the list shows a spinner during the
/// one-time build instead of freezing, then filters the cached list (instant).
/// Kept separate from the search/sort step so a search keystroke never rebuilds.
final _databaseFacetResultsProvider =
    FutureProvider<List<GearSummary>>((ref) async {
  final filter = ref.watch(databaseFilterProvider);
  // Ensure the index is built (async, non-blocking) before filtering it.
  await ref.watch(databaseIndexProvider(filter.kind).future);
  return ref.watch(databaseRepositoryProvider).listGear(filter.toGearFilter());
});

/// The filtered, searched, and sorted gear list. The facet result is filtered
/// by the shared search grammar (name / `is:` keyword), then sorted. Carries
/// the [AsyncValue] so the UI can show a loading state during the one-time
/// per-kind index build.
final databaseResultsProvider = Provider<AsyncValue<List<GearSummary>>>((ref) {
  final query = ref.watch(_databaseCompiledQueryProvider);

  return ref.watch(_databaseFacetResultsProvider).whenData((facetResults) {
    var results = facetResults;
    if (!query.isEmpty) {
      results =
          results.where((g) => query.matches(g.toDestinyItem())).toList();
    } else {
      results = [...results]; // copy before the in-place sort below
    }
    // Always alphabetical by name (the sort control was removed).
    results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return results;
  });
});

/// `is:` keywords/terms typed into the Database search that cannot apply to a
/// definition (they need instance data: power, equipped, masterwork, locked).
/// Surfaced in the UI so the filter never silently ignores them (rule 12).
final databaseUnsupportedTermsProvider = Provider<List<String>>((ref) {
  return ref.watch(_databaseCompiledQueryProvider).unsupported;
});

/// Gear names for the Database search field's `name:"..."` autocomplete, taken
/// from the current kind's loaded facet results. Empty until the list loads.
final databaseItemNamesProvider = Provider<List<String>>((ref) {
  final results = ref.watch(_databaseFacetResultsProvider).value;
  if (results == null) return const [];
  final names = <String>{for (final g in results) g.name};
  return names.toList()..sort();
});

/// The hash of the gear whose detail is open, or null when none is selected.
class SelectedDatabaseItemNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int itemHash) => state = itemHash;
  void clear() => state = null;
  void toggle(int itemHash) => state = state == itemHash ? null : itemHash;
}

final selectedDatabaseItemProvider =
    NotifierProvider<SelectedDatabaseItemNotifier, int?>(
        SelectedDatabaseItemNotifier.new);

/// The resolved definition detail (for the modal) of the selected gear, or null
/// when none is selected. Resolved lazily — only the selected item decodes full
/// detail (~8ms), so this is fine to compute synchronously.
///
/// autoDispose: this and the two modal-scoped providers below tear down when the
/// modal closes. Without it they linger; re-selecting an item leaves them dirty
/// with a live subscriber, so the modal's first `watch` flushes them mid-build
/// and Riverpod's re-invalidation calls setState during the build phase (the
/// same class of error the manifest bootstrap works around).
final databaseItemDetailProvider = Provider.autoDispose<GearDetail?>((ref) {
  final hash = ref.watch(selectedDatabaseItemProvider);
  if (hash == null) return null;
  return ref.watch(databaseRepositoryProvider).resolveGearDetail(hash);
});

/// Which enhancement state the perk grid shows: enhanced-only or regular-only
/// (the toggle by the "Perks" title). Modal-scoped so it resets each time the
/// modal opens, defaulting to enhanced.
enum PerkView { regular, enhanced }

class DatabasePerkViewNotifier extends Notifier<PerkView> {
  @override
  PerkView build() {
    // Default to the enhanced view for each newly-opened item.
    ref.watch(selectedDatabaseItemProvider);
    return PerkView.enhanced;
  }

  /// Switch the view and carry the current selection across: each selected
  /// perk swaps to the same-named plug in the target enhancement state (its
  /// enhanced ⇄ base counterpart). A selection with no counterpart in the
  /// target state is dropped (it cannot be shown there).
  void set(PerkView view) {
    if (view == state) return;
    ref
        .read(databasePerkSelectionProvider.notifier)
        .remapToEnhancement(view == PerkView.enhanced);
    state = view;
  }
}

final databasePerkViewProvider =
    NotifierProvider.autoDispose<DatabasePerkViewNotifier, PerkView>(
        DatabasePerkViewNotifier.new);

/// The perks the user has picked in the modal's perk grid: a map of perk-column
/// index → the selected plug's index within that column. One selection per
/// column (picking another in the same column replaces it), mirroring a real
/// roll. Resets when the selected item changes; the enhanced/regular toggle
/// keeps the selection and swaps each pick to its counterpart (see
/// [DatabasePerkViewNotifier.set] / [remapToEnhancement]).
class DatabasePerkSelectionNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() {
    // Reset the selection when the open item changes.
    ref.watch(selectedDatabaseItemProvider);
    return const {};
  }

  /// Select [plugIndex] in [column]; picking the already-selected plug clears
  /// that column's selection (toggle off).
  void toggle(int column, int plugIndex) {
    final next = {...state};
    if (next[column] == plugIndex) {
      next.remove(column);
    } else {
      next[column] = plugIndex;
    }
    state = next;
  }

  /// Re-point each selection to the same-named plug in the target enhancement
  /// state ([enhanced] true → enhanced version, false → base). A selection with
  /// no counterpart in the target state is dropped. Called by the view toggle
  /// so switching enhanced ⇄ regular keeps the selected perks, swapped.
  void remapToEnhancement(bool enhanced) {
    final detail = ref.read(databaseItemDetailProvider);
    if (detail == null || state.isEmpty) return;
    final next = <int, int>{};
    state.forEach((column, plugIndex) {
      if (column < 0 || column >= detail.perkColumns.length) return;
      final plugs = detail.perkColumns[column].plugs;
      if (plugIndex < 0 || plugIndex >= plugs.length) return;
      final name = plugs[plugIndex].name;
      final target = plugs.indexWhere(
          (p) => p.name == name && p.isEnhanced == enhanced);
      if (target != -1) next[column] = target;
    });
    state = next;
  }
}

final databasePerkSelectionProvider =
    NotifierProvider.autoDispose<DatabasePerkSelectionNotifier, Map<int, int>>(
        DatabasePerkSelectionNotifier.new);

/// The combined stat deltas of the currently-selected perks, keyed by stat
/// hash (signed: positive = gain, negative = penalty). Empty when nothing is
/// selected. Derived so the modal's stat bars and effects list stay in sync.
final databaseSelectedStatDeltasProvider =
    Provider.autoDispose<Map<int, int>>((ref) {
  final detail = ref.watch(databaseItemDetailProvider);
  final selection = ref.watch(databasePerkSelectionProvider);
  if (detail == null || selection.isEmpty) return const {};
  final deltas = <int, int>{};
  selection.forEach((column, plugIndex) {
    if (column < 0 || column >= detail.perkColumns.length) return;
    final plugs = detail.perkColumns[column].plugs;
    if (plugIndex < 0 || plugIndex >= plugs.length) return;
    for (final e in plugs[plugIndex].statEffects) {
      deltas[e.hash] = (deltas[e.hash] ?? 0) + e.value;
    }
  });
  return deltas;
});
