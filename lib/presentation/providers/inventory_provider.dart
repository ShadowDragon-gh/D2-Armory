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
