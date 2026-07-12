import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/inventory_repository.dart';
import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import '../../domain/models/item_detail.dart';
import 'character_provider.dart';
import 'manifest_provider.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    api: ref.watch(bungieApiProvider),
    manifest: ref.watch(manifestRepositoryProvider),
  );
});

/// The full inventory grid (characters + vault). Re-read after invalidation
/// to refresh.
final inventoryGridProvider = FutureProvider<InventoryGrid>((ref) {
  return ref.watch(inventoryRepositoryProvider).fetchInventory();
});

/// Warms the inventory search facets (perk/stat/breaker/source/catalyst) for
/// every owned item, so the first facet-backed search is instant instead of
/// decoding on the first keystroke. Runs on the UI isolate (the decode needs
/// the live profile components), but is bounded by owned items. Recomputed when
/// the grid changes.
///
/// Deliberately deferred: it waits for the grid to load and then a beat longer,
/// so the grid builds and paints first without the (heavy, UI-isolate) warm
/// competing for the isolate at the handoff. [InventoryRepository.warmFacets]
/// then trickles the work in over several seconds without dropping frames.
final inventoryFacetsWarmProvider = FutureProvider<void>((ref) async {
  final grid = await ref.watch(inventoryGridProvider.future);
  // Let the grid build and paint before the warm starts taking the isolate.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final items = [
    for (final owner in grid.owners)
      for (final list in owner.itemsByBucket.values) ...list,
  ];
  await ref.watch(inventoryRepositoryProvider).warmFacets(items);
});

/// Deduped, sorted item names from the loaded grid, for search autocomplete.
/// Empty until the grid has loaded.
final itemNamesProvider = Provider<List<String>>((ref) {
  final grid = ref.watch(inventoryGridProvider).value;
  if (grid == null) return const [];
  final names = <String>{};
  for (final owner in grid.owners) {
    for (final list in owner.itemsByBucket.values) {
      for (final item in list) {
        if (item.name.isNotEmpty) names.add(item.name);
      }
    }
  }
  final sorted = names.toList()..sort();
  return sorted;
});

/// The item whose detail panel is open, or null when the panel is closed.
class SelectedItemNotifier extends Notifier<DestinyItem?> {
  @override
  DestinyItem? build() => null;

  void select(DestinyItem item) => state = item;
  void clear() => state = null;

  /// Toggle: selecting the already-selected item closes the panel.
  void toggle(DestinyItem item) =>
      state = identical(state, item) ? null : item;
}

final selectedItemProvider =
    NotifierProvider<SelectedItemNotifier, DestinyItem?>(
        SelectedItemNotifier.new);

/// The resolved detail for the selected item, or null when none is selected.
final selectedItemDetailProvider = Provider<ItemDetail?>((ref) {
  final item = ref.watch(selectedItemProvider);
  if (item == null) return null;
  return ref.watch(inventoryRepositoryProvider).resolveDetail(item);
});

/// The owned item backing the gear-detail modal when it was opened from the
/// Inventory tab, or null when the modal shows a plain Database definition.
/// Lets the modal offer the instance's rolled stats alongside the definition.
class GearModalInstanceNotifier extends Notifier<DestinyItem?> {
  @override
  DestinyItem? build() => null;

  void select(DestinyItem item) => state = item;
  void clear() => state = null;
}

final gearModalInstanceProvider =
    NotifierProvider<GearModalInstanceNotifier, DestinyItem?>(
        GearModalInstanceNotifier.new);

/// The resolved instance detail behind the gear-detail modal, or null when it
/// was opened from the Database tab. Guarded so the inventory repository is
/// only touched when an owned item is actually backing the modal.
final gearModalInstanceDetailProvider =
    Provider.autoDispose<ItemDetail?>((ref) {
  final item = ref.watch(gearModalInstanceProvider);
  if (item == null) return null;
  return ref
      .watch(inventoryRepositoryProvider)
      .resolveDetail(item, withPerkColumns: true);
});
