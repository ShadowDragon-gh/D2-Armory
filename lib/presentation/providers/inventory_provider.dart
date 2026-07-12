import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/item_transfer_repository.dart';
import '../../data/repositories/membership_service.dart';
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

/// The full inventory grid (characters + vault). Owns both a full fetch (on
/// build / invalidate) and two cheaper in-place updates: [InventoryGridNotifier.patch]
/// for the instant post-move grid mutation, and [InventoryGridNotifier.refresh]
/// for the background poll (staleness-guarded refetch).
class InventoryGridNotifier extends AsyncNotifier<InventoryGrid> {
  @override
  Future<InventoryGrid> build() {
    return ref.watch(inventoryRepositoryProvider).fetchInventory();
  }

  /// Replace the grid with a locally-patched copy (a completed move), without a
  /// network call. No-op when the grid has not loaded yet.
  void patch(InventoryGrid grid) {
    if (state.hasValue) state = AsyncData(grid);
  }

  /// Refetch the profile and replace the grid, unless Bungie served a snapshot
  /// no newer than the one already shown — its edge cache can return a profile
  /// older than what we hold, and rebuilding from that would flicker the grid
  /// back to a stale state. Used by the background poll; never surfaces a
  /// loading state (the current grid stays visible while it runs).
  Future<void> refresh() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final before = repo.lastMintedTimestamp;
    final grid = await repo.fetchInventory();
    final after = repo.lastMintedTimestamp;
    // Discard a response that is not strictly newer than what we already show.
    if (before != null && after != null && !after.isAfter(before)) return;
    state = AsyncData(grid);
  }
}

final inventoryGridProvider =
    AsyncNotifierProvider<InventoryGridNotifier, InventoryGrid>(
        InventoryGridNotifier.new);

/// Shared membership resolver (cross-save aware). Used by both the inventory
/// fetch and the transfer service so membership resolution is not duplicated.
final membershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService(ref.watch(bungieApiProvider));
});

final itemTransferRepositoryProvider = Provider<ItemTransferRepository>((ref) {
  return ItemTransferRepository(
    api: ref.watch(bungieApiProvider),
    memberships: ref.watch(membershipServiceProvider),
  );
});

/// Carried by a dragged tile so a drop knows where the item came from: the item
/// and the id of the owner (character or vault) it currently sits in.
class ItemDrag {
  const ItemDrag({required this.item, required this.fromOwnerId});

  final DestinyItem item;
  final String fromOwnerId;
}

/// True while a tile is being dragged. The background poll stands down while
/// dragging so a refetch never resets the grid out from under the cursor.
class DraggingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void end() => state = false;
}

final isDraggingProvider =
    NotifierProvider<DraggingNotifier, bool>(DraggingNotifier.new);

/// The result of a completed move, surfaced to the UI for a snackbar. [ok] is
/// false for a failed move; [message] is always safe to show (on failure it
/// states what went wrong, including a stranded-in-vault partial failure).
class MoveOutcome {
  const MoveOutcome._(this.ok, this.message);

  const MoveOutcome.success(String message) : this._(true, message);
  const MoveOutcome.failure(String message) : this._(false, message);

  final bool ok;
  final String message;
}

/// Drives item moves triggered by a drag-and-drop: it resolves the source and
/// destination owners from the current grid, runs the transfer, and — on
/// success — patches the grid in memory (no refetch) so it updates instantly,
/// mirroring how DIM reconciles a move. Reports the outcome for a toast. Moves
/// are serialised: a drop while one is in flight is ignored, so a rapid
/// sequence never fires concurrent POSTs.
///
/// [inFlight] is exposed so the background poll can stand down while a move is
/// running (a mid-move refetch could clobber the patch before the POST settles).
class MoveController extends Notifier<MoveOutcome?> {
  @override
  MoveOutcome? build() => null;

  bool _inFlight = false;

  /// True while a move is running, so the UI can show progress and the poll can
  /// pause.
  bool get inFlight => _inFlight;

  /// Move [drag]'s item into [toOwner]. No-op when the grid is not loaded, a
  /// move is already in flight, or the drop is onto the item's current owner.
  Future<void> move(ItemDrag drag, InventoryOwner toOwner) async {
    if (_inFlight) return;
    if (drag.fromOwnerId == toOwner.id) return; // dropped where it started

    final grid = ref.read(inventoryGridProvider).value;
    if (grid == null) return;
    final fromOwner =
        grid.owners.where((o) => o.id == drag.fromOwnerId).firstOrNull;
    if (fromOwner == null) return;
    final instanceId = drag.item.itemInstanceId;
    if (instanceId == null) return;

    _inFlight = true;
    state = null;
    try {
      await ref
          .read(itemTransferRepositoryProvider)
          .moveItem(drag.item, fromOwner, toOwner);
      // Patch the grid to show the item on its destination — no refetch.
      _patchMove(instanceId, drag.fromOwnerId, toOwner.id);
      state =
          MoveOutcome.success('Moved ${drag.item.name} to ${toOwner.title}.');
    } on StrandedInVaultFailure catch (e) {
      // A cross-character move whose second hop failed: the item is in the
      // vault, not on the destination. Patch it to the vault so the grid shows
      // where it actually is (never a false success).
      _patchMove(instanceId, drag.fromOwnerId, 'vault');
      state = MoveOutcome.failure(e.message);
    } on Failure catch (e) {
      // The move did not happen; leave the grid unchanged.
      state = MoveOutcome.failure(e.message);
    } finally {
      _inFlight = false;
    }
  }

  /// Equip [drag]'s item on [toOwner] (the item must already be on that
  /// character). Equipping does not move the item between owners, so a
  /// successful equip refetches to reflect the new equipped/unequipped state.
  Future<void> equip(ItemDrag drag, InventoryOwner toOwner) async {
    if (_inFlight) return;
    _inFlight = true;
    state = null;
    try {
      await ref.read(itemTransferRepositoryProvider).equip(drag.item, toOwner);
      state = MoveOutcome.success('Equipped ${drag.item.name}.');
      ref.invalidate(inventoryGridProvider);
    } on Failure catch (e) {
      state = MoveOutcome.failure(e.message);
    } finally {
      _inFlight = false;
    }
  }

  void _patchMove(String instanceId, String fromOwnerId, String toOwnerId) {
    final grid = ref.read(inventoryGridProvider).value;
    if (grid == null) return;
    ref.read(inventoryGridProvider.notifier).patch(grid.withItemMoved(
          instanceId: instanceId,
          fromOwnerId: fromOwnerId,
          toOwnerId: toOwnerId,
        ));
  }

  /// Clear the last outcome after the toast has shown it.
  void clear() => state = null;
}

final moveControllerProvider =
    NotifierProvider<MoveController, MoveOutcome?>(MoveController.new);

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
