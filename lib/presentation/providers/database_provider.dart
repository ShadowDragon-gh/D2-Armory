import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../core/search/item_filter.dart';
import '../../core/search/search_suggestions.dart';
import '../../data/repositories/database_repository.dart';
import '../../domain/models/armor_set.dart';
import '../../domain/models/item_detail.dart';
import 'inventory_provider.dart';
import 'manifest_provider.dart';

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository(manifest: ref.watch(manifestRepositoryProvider));
});

/// Which gear family the Database is browsing (the Weapons/Armor toggle) and,
/// for armor, an optional class constraint. The kind selects which per-kind
/// index and facet cache the list and search read. Every other facet (rarity,
/// type, element, ammo, breaker, frame…) is expressed through the search bar
/// ([databaseSearchProvider]) and evaluated by the shared search grammar.
class DatabaseFilter {
  const DatabaseFilter({
    this.kind = GearKind.weapon,
    this.classType,
    this.collapseSets = true,
    this.hideBelowLegendary = true,
    this.hideLegacy = true,
    this.exoticsOnly = false,
  });

  final GearKind kind;

  /// DestinyClass (0=Titan, 1=Hunter, 2=Warlock) to restrict armor to, or null
  /// for all classes. Only meaningful for armor; cleared when browsing weapons.
  final int? classType;

  /// Whether armor is collapsed into set rows (on by default). Armor-only —
  /// weapons have no sets, so it never affects them.
  final bool collapseSets;

  /// Whether to hide gear below Legendary rarity (on by default). Applies to
  /// both tabs.
  final bool hideBelowLegendary;

  /// Whether to hide legacy armor — sets with no modern set bonus and their
  /// pieces (on by default). Armor-only.
  final bool hideLegacy;

  /// Whether to show only Exotic gear (off by default). Mutually exclusive with
  /// [collapseSets] — exotics are single pieces, never part of a set.
  final bool exoticsOnly;

  GearFilter toGearFilter() => GearFilter(
        kind: kind,
        classType: classType,
        // Exotics-only pins the tier to Exotic; otherwise the Legendary floor
        // applies when hiding lower rarity.
        tierType: exoticsOnly ? 6 : null, // 6 = Exotic
        minTierType:
            (!exoticsOnly && hideBelowLegendary) ? 5 : null, // 5 = Legendary
      );
}

class DatabaseFilterNotifier extends Notifier<DatabaseFilter> {
  @override
  DatabaseFilter build() => const DatabaseFilter();

  /// Switch the browsed family. Weapons carry no class constraint, so the class
  /// filter is dropped when leaving armor; the other preferences are kept.
  void setKind(GearKind kind) => state = DatabaseFilter(
        kind: kind,
        classType: kind == GearKind.armor ? state.classType : null,
        collapseSets: state.collapseSets,
        hideBelowLegendary: state.hideBelowLegendary,
        hideLegacy: state.hideLegacy,
        exoticsOnly: state.exoticsOnly,
      );

  /// Set (or clear, with null) the armor class constraint.
  void setClassType(int? classType) =>
      state = _copyWith(classType: classType, clearClass: classType == null);

  /// Toggle collapsing armor into set rows. Turning it on turns off
  /// exotics-only (exotics are single pieces, never in a set); turning it off
  /// leaves exotics-only untouched.
  void setCollapseSets(bool collapse) => state = _copyWith(
      collapseSets: collapse, exoticsOnly: collapse ? false : null);

  /// Toggle hiding gear below Legendary rarity.
  void setHideBelowLegendary(bool hide) =>
      state = _copyWith(hideBelowLegendary: hide);

  /// Toggle hiding legacy armor (sets with no modern bonus + their pieces).
  void setHideLegacy(bool hide) => state = _copyWith(hideLegacy: hide);

  /// Toggle showing only Exotic gear. Turning it on turns off set collapsing
  /// (they are mutually exclusive); turning it off leaves collapsing untouched.
  void setExoticsOnly(bool only) => state =
      _copyWith(exoticsOnly: only, collapseSets: only ? false : null);

  DatabaseFilter _copyWith({
    int? classType,
    bool clearClass = false,
    bool? collapseSets,
    bool? hideBelowLegendary,
    bool? hideLegacy,
    bool? exoticsOnly,
  }) =>
      DatabaseFilter(
        kind: state.kind,
        classType: clearClass ? classType : (classType ?? state.classType),
        collapseSets: collapseSets ?? state.collapseSets,
        hideBelowLegendary: hideBelowLegendary ?? state.hideBelowLegendary,
        hideLegacy: hideLegacy ?? state.hideLegacy,
        exoticsOnly: exoticsOnly ?? state.exoticsOnly,
      );
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

/// One row in the Database list: either a single gear [piece] or a collapsed
/// armor [set] (with the member summaries that survived the current filter).
/// Exactly one of [piece] / [set] is non-null.
class DatabaseRow {
  const DatabaseRow.piece(GearSummary this.piece)
      : set = null,
        members = const [];
  const DatabaseRow.set(ArmorSet this.set, this.members) : piece = null;

  final GearSummary? piece;
  final ArmorSet? set;

  /// For a set row, the member summaries present in the current (filtered)
  /// result — so the row's piece count reflects the active class filter.
  final List<GearSummary> members;

  bool get isSet => set != null;

  /// The name this row sorts and displays by (set name or item name).
  String get sortName => (set?.name ?? piece?.name ?? '').toLowerCase();
}

/// The Database list as display rows.
///
/// Weapons (and armor with collapse-sets off) are all piece rows. For armor
/// with collapse-sets on, the list shows **only** set rows — gear in a set
/// collapses to one [DatabaseRow.set] (holding the members that passed the
/// filter) and gear in no set is hidden. When [DatabaseFilter.hideLegacy] is
/// on, legacy sets (no modern bonus) and their pieces are dropped entirely.
/// Rows are sorted alphabetically by display name.
final databaseRowsProvider = Provider<AsyncValue<List<DatabaseRow>>>((ref) {
  final filter = ref.watch(databaseFilterProvider);
  final collapse = filter.kind == GearKind.armor && filter.collapseSets;
  final hideLegacy = filter.kind == GearKind.armor && filter.hideLegacy;
  return ref.watch(databaseResultsProvider).whenData((results) {
    final repo = ref.watch(databaseRepositoryProvider);

    if (!collapse) {
      // Flat per-piece view. Hiding legacy still drops legacy-set members.
      final rows = <DatabaseRow>[];
      for (final g in results) {
        if (hideLegacy && (repo.armorSetForItem(g.itemHash)?.isLegacy ?? false)) {
          continue;
        }
        rows.add(DatabaseRow.piece(g));
      }
      return rows;
    }

    // Collapsed view: only set rows; setless gear is hidden.
    final setMembers = <int, List<GearSummary>>{};
    final setById = <int, ArmorSet>{};
    for (final g in results) {
      final set = repo.armorSetForItem(g.itemHash);
      if (set == null) continue; // loose piece — hidden in the collapsed view
      if (hideLegacy && set.isLegacy) continue; // legacy set — hidden
      (setMembers[set.hash] ??= []).add(g);
      setById[set.hash] = set;
    }
    final rows = [
      for (final entry in setMembers.entries)
        DatabaseRow.set(setById[entry.key]!, entry.value),
    ]..sort((a, b) => a.sortName.compareTo(b.sortName));
    return rows;
  });
});

/// `is:` keywords/terms typed into the Database search that cannot apply to a
/// definition (they need instance data: power, equipped, masterwork, locked).
/// Surfaced in the UI so the filter never silently ignores them (rule 12).
final databaseUnsupportedTermsProvider = Provider<List<String>>((ref) {
  return ref.watch(_databaseCompiledQueryProvider).unsupported;
});

/// The perk catalog (name + icon) offered as `perk:`/`perk1:`/`perk2:` value
/// autocomplete on both tabs. Sourced from the Database weapon facet warm (the
/// full weapon perk pool), so it is game-wide, not account-scoped. Empty until
/// that warm completes, then fully populated; watching the warm rebuilds this
/// when it lands.
final perkCatalogProvider = Provider<List<PerkOption>>((ref) {
  ref.watch(databaseFacetsWarmProvider(GearKind.weapon));
  return ref.watch(databaseRepositoryProvider).perkOptions();
});

/// The archetype-frame catalog (name + icon) offered as `frame:` value
/// autocomplete on both tabs. Sourced from the Database weapon facet warm (frame
/// archetypes are a weapon concept), so it is game-wide. Empty until that warm
/// completes; watching the warm rebuilds this when it lands.
final frameCatalogProvider = Provider<List<PerkOption>>((ref) {
  ref.watch(databaseFacetsWarmProvider(GearKind.weapon));
  return ref.watch(databaseRepositoryProvider).frameOptions();
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

/// The hash of the armor set whose detail modal is open, or null when none is
/// selected. Set when a collapsed set row is tapped; the set-detail modal reads
/// it and clears it on close.
class SelectedArmorSetNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int setHash) => state = setHash;
  void clear() => state = null;
  void toggle(int setHash) => state = state == setHash ? null : setHash;
}

final selectedArmorSetProvider =
    NotifierProvider<SelectedArmorSetNotifier, int?>(
        SelectedArmorSetNotifier.new);

/// Whether the shared gear-detail modal is currently up. Both the Database
/// list and the Inventory grid react to [selectedDatabaseItemProvider] (both
/// stay alive in the shell's IndexedStack), so `showGearDetailModal` uses this
/// to let the first open win and make later calls no-op.
class GearModalOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final gearModalOpenProvider =
    NotifierProvider<GearModalOpenNotifier, bool>(GearModalOpenNotifier.new);

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
  final detail = ref.watch(databaseRepositoryProvider).resolveGearDetail(hash);
  if (detail == null) return null;
  // When an owned instance backs the modal (opened from Inventory), show the
  // ornamented look it actually wears — the applied ornament's screenshot and
  // icon — over the base definition art. Database-tab (definition-only) detail
  // keeps the base art.
  final instance = ref.watch(gearModalInstanceProvider);
  if (instance != null) {
    final art =
        ref.watch(inventoryRepositoryProvider).appliedOrnamentArt(instance);
    if (art != null) {
      return detail.withOrnamentArt(
          screenshot: art.screenshot, icon: art.icon);
    }
  }
  return detail;
});

/// Which view the gear-detail modal shows when an owned item backs it (opened
/// from the Inventory tab): the instance's actual roll — its stats, perks,
/// mods, and masterwork state — or the item definition with every possible
/// roll. Modal-scoped so it resets per opened item.
enum GearModalView { rolled, definition }

class GearModalViewNotifier extends Notifier<GearModalView> {
  @override
  GearModalView build() {
    // Reset to the roll for each newly-opened item.
    ref.watch(selectedDatabaseItemProvider);
    return GearModalView.rolled;
  }

  void set(GearModalView view) => state = view;
}

final gearModalViewProvider =
    NotifierProvider.autoDispose<GearModalViewNotifier, GearModalView>(
        GearModalViewNotifier.new);

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
