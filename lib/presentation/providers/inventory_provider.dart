import 'dart:async';

import 'package:flutter/scheduler.dart';
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
    // Reuse the prior decode for items whose inputs are unchanged — a poll
    // rebuilds hundreds of items and most are untouched between ticks.
    final grid = await repo.fetchInventory(reuseDecoded: true);
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

/// The result of a completed action (a move, equip, or perk/mod insert),
/// surfaced to the UI for a toast. [ok] is false on failure; [message] is
/// always safe to show (on failure it states what went wrong, including a
/// stranded-in-vault partial failure). [title] is the toast's header line —
/// caller-supplied so it names the specific action ("Move complete",
/// "Perk selected", …); it defaults to move/failure wording.
class MoveOutcome {
  const MoveOutcome._(this.ok, this.message, this.title);

  const MoveOutcome.success(String message, {String title = 'Move complete'})
      : this._(true, message, title);
  const MoveOutcome.failure(String message, {String title = 'Action failed'})
      : this._(false, message, title);

  final bool ok;
  final String message;
  final String title;
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

  /// The most recent mod/perk pick made while an insert was already in flight,
  /// run once the current one settles. Only the latest is kept — intermediate
  /// clicks collapse to the last, so a rapid series stays serialised (never
  /// concurrent POSTs) yet the final selection always wins.
  ({DestinyItem item, int socketIndex, int plugHash, String plugName})?
      _pendingInsert;

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
      ref.read(recentlyMovedProvider.notifier).mark(instanceId);
      state =
          MoveOutcome.success('Moved ${drag.item.name} to ${toOwner.title}.');
    } on StrandedInVaultFailure catch (e) {
      // A cross-character move whose second hop failed: the item is in the
      // vault, not on the destination. Patch it to the vault so the grid shows
      // where it actually is (never a false success), and highlight it there.
      _patchMove(instanceId, drag.fromOwnerId, 'vault');
      ref.read(recentlyMovedProvider.notifier).mark(instanceId);
      state = MoveOutcome.failure(e.message, title: 'Move failed');
    } on Failure catch (e) {
      // The move did not happen; leave the grid unchanged.
      state = MoveOutcome.failure(e.message, title: 'Move failed');
    } finally {
      _inFlight = false;
    }
  }

  /// Equip [drag]'s item on [toOwner]. When the item is already on [toOwner] it
  /// is simply equipped. When it is on another character or the vault, it is
  /// first moved to [toOwner] and then equipped. Every success patches the grid
  /// in memory (no refetch) so a rapid sequence stays instant and consistent.
  ///
  /// Partial failure of the move-then-equip is surfaced, never hidden: if the
  /// move succeeds but the equip fails, the item stays on [toOwner] (unequipped)
  /// and the toast says so.
  Future<void> equip(ItemDrag drag, InventoryOwner toOwner) async {
    if (_inFlight) return;
    final instanceId = drag.item.itemInstanceId;
    if (instanceId == null) return;

    _inFlight = true;
    state = null;
    try {
      // Move first when the item is not already on the target character.
      if (drag.fromOwnerId != toOwner.id) {
        final grid = ref.read(inventoryGridProvider).value;
        final fromOwner =
            grid?.owners.where((o) => o.id == drag.fromOwnerId).firstOrNull;
        if (grid == null || fromOwner == null) return;

        try {
          await ref
              .read(itemTransferRepositoryProvider)
              .moveItem(drag.item, fromOwner, toOwner);
        } on StrandedInVaultFailure catch (e) {
          _patchMove(instanceId, drag.fromOwnerId, 'vault');
          ref.read(recentlyMovedProvider.notifier).mark(instanceId);
          state = MoveOutcome.failure(e.message, title: 'Move failed');
          return;
        }
        _patchMove(instanceId, drag.fromOwnerId, toOwner.id);

        // Move done; now equip. A failure here leaves the item on the target
        // (unequipped) — report that rather than claiming success.
        try {
          await ref.read(itemTransferRepositoryProvider).equip(drag.item, toOwner);
        } on Failure catch (e) {
          // The item still moved — highlight where it landed.
          ref.read(recentlyMovedProvider.notifier).mark(instanceId);
          state = MoveOutcome.failure(
              'Moved ${drag.item.name} to ${toOwner.title}, but could not '
              'equip it: ${e.message}',
              title: 'Move failed');
          return;
        }
        _patchEquip(instanceId, toOwner.id);
        ref.read(recentlyMovedProvider.notifier).mark(instanceId);
        state = MoveOutcome.success(
            'Moved ${drag.item.name} to ${toOwner.title} and equipped it.');
        return;
      }

      // Same character: equip in place.
      await ref.read(itemTransferRepositoryProvider).equip(drag.item, toOwner);
      _patchEquip(instanceId, toOwner.id);
      ref.read(recentlyMovedProvider.notifier).mark(instanceId);
      state = MoveOutcome.success('Equipped ${drag.item.name}.');
    } on Failure catch (e) {
      state = MoveOutcome.failure(e.message, title: 'Move failed');
    } finally {
      _inFlight = false;
    }
  }

  /// Insert [plugHash] into [item]'s [socketIndex] socket — selecting the perk
  /// or mod named [plugName] in-game. [item] must be the owned instance backing
  /// the gear-detail modal; its owner is resolved from the current grid (the
  /// insert needs a character, so an item in the vault cannot be edited).
  ///
  /// The modal's highlight moves optimistically via [gearModalPlugOverrideProvider]
  /// the moment the click lands; the POST then runs, and on success the profile
  /// is refetched so the roll's stats/sockets reconcile from real data — the
  /// grid's fresh [DestinyItem] is re-selected so the modal's instance-detail
  /// recomputes. On failure the optimistic override for that socket is rolled
  /// back and the toast says what went wrong. Serialised with moves/equips via
  /// [_inFlight] so a rapid series of clicks never fires concurrent POSTs.
  Future<void> insertPlug(
    DestinyItem item, {
    required int socketIndex,
    required int plugHash,
    required String plugName,
  }) async {
    final instanceId = item.itemInstanceId;
    if (instanceId == null) return;
    // A click while another insert is in flight: acknowledge it visually (move
    // the highlight now) and queue it to run when the current one settles, so
    // the click is never silently dropped and POSTs stay serialised. A later
    // click overwrites the pending one — only the last selection is applied.
    if (_inFlight) {
      ref
          .read(gearModalPlugOverrideProvider.notifier)
          .set(socketIndex, plugHash);
      _pendingInsert = (
        item: item,
        socketIndex: socketIndex,
        plugHash: plugHash,
        plugName: plugName,
      );
      return;
    }

    final grid = ref.read(inventoryGridProvider).value;
    final owner = grid == null ? null : _ownerOf(grid, instanceId);
    if (owner == null) {
      state = MoveOutcome.failure(
          'Could not find "${item.name}" in your inventory.',
          title: 'Selection failed');
      return;
    }
    if (owner.isVault) {
      state = MoveOutcome.failure(
          'Move "${item.name}" to a character before changing its perks.',
          title: 'Selection failed');
      return;
    }

    _inFlight = true;
    state = null;
    final repo = ref.read(inventoryRepositoryProvider);
    // Optimistic update, applied together the moment the click lands:
    //  - the highlight moves to the picked plug (override), and
    //  - the cached sockets/stats are patched so the stat bars shift too.
    // Both are reverted as a unit if the insert fails. `oldPlugHash` is the plug
    // the socket held (captured from the patch) so the rollback can restore it,
    // which reverses the stat delta symmetrically.
    ref.read(gearModalPlugOverrideProvider.notifier).set(socketIndex, plugHash);
    final oldPlugHash = repo.patchSocketPlug(item, socketIndex, plugHash);
    ref.read(gearModalRevisionProvider.notifier).bump();
    try {
      await ref.read(itemTransferRepositoryProvider).insertPlug(
            item,
            owner,
            socketIndex: socketIndex,
            plugHash: plugHash,
          );
      // The roll changed on the server; refetch so the instance's stats and
      // sockets reconcile from real data. The refetch may be discarded if
      // Bungie's edge cache serves a not-newer profile — the optimistic patch
      // above still holds until a genuinely newer snapshot lands. Re-select the
      // grid's (possibly refreshed) copy so the modal's instance detail
      // recomputes, and bump the revision so it re-resolves even when that copy
      // is the same object (a discarded refetch leaves the grid unchanged).
      await ref.read(inventoryGridProvider.notifier).refresh();
      final refreshed = ref.read(inventoryGridProvider).value;
      final current =
          refreshed == null ? null : _itemOf(refreshed, instanceId);
      if (current != null) {
        ref.read(gearModalInstanceProvider.notifier).select(current);
      }
      ref.read(gearModalRevisionProvider.notifier).bump();
      state = MoveOutcome.success('Selected $plugName on ${item.name}.',
          title: 'Perk selected');
    } on Failure catch (e) {
      // The insert did not take — roll back the optimistic update as a unit:
      // restore the socket's prior plug (reversing the stat delta), forget the
      // pending edit so it is not re-applied over later fetches, and clear the
      // highlight override, then re-resolve the detail.
      if (oldPlugHash != null) {
        repo.patchSocketPlug(item, socketIndex, oldPlugHash);
      }
      repo.clearPendingSocketEdit(item, socketIndex);
      ref.read(gearModalPlugOverrideProvider.notifier).clearSocket(socketIndex);
      ref.read(gearModalRevisionProvider.notifier).bump();
      state = MoveOutcome.failure(e.message, title: 'Selection failed');
    } finally {
      _inFlight = false;
    }

    // Drain a pick queued while this insert ran (the latest wins). Cleared
    // first so its own in-flight run doesn't see itself as pending; runs as a
    // fresh insert, which patches the cache against the now-settled base.
    final pending = _pendingInsert;
    if (pending != null) {
      _pendingInsert = null;
      await insertPlug(
        pending.item,
        socketIndex: pending.socketIndex,
        plugHash: pending.plugHash,
        plugName: pending.plugName,
      );
    }
  }

  /// The item with instance id [instanceId] in [grid], or null if not found.
  DestinyItem? _itemOf(InventoryGrid grid, String instanceId) {
    for (final owner in grid.owners) {
      for (final list in owner.itemsByBucket.values) {
        for (final i in list) {
          if (i.itemInstanceId == instanceId) return i;
        }
      }
    }
    return null;
  }

  /// The owner (character or vault) holding the instance [instanceId] in the
  /// current [grid], or null when it is not found.
  InventoryOwner? _ownerOf(InventoryGrid grid, String instanceId) {
    for (final owner in grid.owners) {
      for (final list in owner.itemsByBucket.values) {
        if (list.any((i) => i.itemInstanceId == instanceId)) return owner;
      }
    }
    return null;
  }

  void _patchEquip(String instanceId, String ownerId) {
    final grid = ref.read(inventoryGridProvider).value;
    if (grid == null) return;
    ref.read(inventoryGridProvider.notifier).patch(
          grid.withItemEquipped(instanceId: instanceId, ownerId: ownerId),
        );
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

/// How long a just-moved item keeps its green "here's where it went" border —
/// matched to the move toast's visible life (slide-in + hold + slide-out) so the
/// two clear together.
const Duration kRecentlyMovedDuration = Duration(milliseconds: 3700);

/// The instance id of the item most recently moved or equipped, so its tile can
/// flash a green border showing where it landed. Holds one id at a time (a new
/// move replaces it and resets the timer); auto-clears after
/// [kRecentlyMovedDuration]. Null when no highlight is active.
class RecentlyMovedNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Highlight [instanceId] and (re)start the clear timer.
  void mark(String instanceId) {
    _timer?.cancel();
    state = instanceId;
    _timer = Timer(kRecentlyMovedDuration, () {
      if (state == instanceId) state = null;
    });
  }
}

final recentlyMovedProvider =
    NotifierProvider<RecentlyMovedNotifier, String?>(RecentlyMovedNotifier.new);

/// Warms the inventory search facets (perk/stat/breaker/source/catalyst) for
/// every owned item, so the first facet-backed search is instant instead of
/// decoding on the first keystroke. Runs on the UI isolate (the decode needs
/// the live profile components), but is bounded by owned items. Recomputed when
/// the grid changes.
///
/// Deliberately deferred: it waits for the grid to load and then a beat longer,
/// so the grid builds and paints first without the (heavy, UI-isolate) warm
/// competing for the isolate at the handoff. [InventoryRepository.warmFacets]
/// then resolves one item per frame — each heavy decode lands after the current
/// frame paints (via [SchedulerBinding.endOfFrame]) — so the warm never blocks a
/// stretch of frames and the app stays responsive while it runs.
final inventoryFacetsWarmProvider = FutureProvider<void>((ref) async {
  final grid = await ref.watch(inventoryGridProvider.future);
  // When the grid changes this provider re-runs and the prior execution is
  // disposed; that flips [cancelled], so the previous (now stale) warm loop
  // stops instead of running concurrently with the new one.
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  // Let the grid build and paint before the warm starts taking the isolate.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  if (cancelled) return;
  final items = [
    for (final owner in grid.owners)
      for (final list in owner.itemsByBucket.values) ...list,
  ];
  await ref.watch(inventoryRepositoryProvider).warmFacets(
        items,
        onYield: _yieldToFrame,
        isCancelled: () => cancelled,
      );
});

/// Wait for the current frame to finish painting before the next heavy decode,
/// so each one lands in the gap between frames. Falls back to a short delay if
/// no frame is pending (an idle app draws no frames, so `endOfFrame` alone
/// could stall the warm indefinitely).
Future<void> _yieldToFrame() {
  return Future.any([
    SchedulerBinding.instance.endOfFrame,
    Future<void>.delayed(const Duration(milliseconds: 16)),
  ]);
}

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

/// The modal's optimistic perk/mod selections while an in-game insert is in
/// flight (and until a genuinely newer profile snapshot reconciles them): a map
/// of socket index → the plug hash the user just picked. The rolled perk grid
/// and mod chips render this on top of the resolved roll so the highlight moves
/// the instant the click lands, before (and independent of) the refetch.
///
/// Cleared when the modal switches to a *different* item — but not when
/// [MoveController.insertPlug] re-selects the same instance after its refetch,
/// so a still-pending (or discarded-refetch) override survives the reconcile.
class GearModalPlugOverrideNotifier extends Notifier<Map<int, int>> {
  String? _instanceId;
  // The map is held here (not only in [state]) so it survives a same-instance
  // rebuild — [build] cannot read the prior [state].
  Map<int, int> _overrides = const {};

  @override
  Map<int, int> build() {
    // Reset when the open instance changes; keep the map when the same instance
    // is re-selected (the post-insert reconcile re-selects the same id).
    final id = ref.watch(
        gearModalInstanceProvider.select((i) => i?.itemInstanceId));
    if (id != _instanceId) {
      _instanceId = id;
      _overrides = const {};
    }
    return _overrides;
  }

  void set(int socketIndex, int plugHash) {
    _overrides = {..._overrides, socketIndex: plugHash};
    state = _overrides;
  }

  void clearSocket(int socketIndex) {
    _overrides = {..._overrides}..remove(socketIndex);
    state = _overrides;
  }
}

final gearModalPlugOverrideProvider =
    NotifierProvider<GearModalPlugOverrideNotifier, Map<int, int>>(
        GearModalPlugOverrideNotifier.new);

/// A counter bumped whenever an in-game socket insert patches the repository's
/// cached components ([InventoryRepository.patchSocketPlug]). The modal's
/// instance-detail watches it so it re-resolves from the patched cache — the
/// re-selected [DestinyItem] can be the *same* object (a discarded refetch
/// leaves the grid unchanged), so watching the item alone would not recompute.
class GearModalRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state = state + 1;
}

final gearModalRevisionProvider =
    NotifierProvider<GearModalRevisionNotifier, int>(
        GearModalRevisionNotifier.new);

/// The resolved instance detail behind the gear-detail modal, or null when it
/// was opened from the Database tab. Guarded so the inventory repository is
/// only touched when an owned item is actually backing the modal. Watches
/// [gearModalRevisionProvider] so a socket insert's cache patch re-resolves the
/// detail even when the re-selected item is the same object.
final gearModalInstanceDetailProvider =
    Provider.autoDispose<ItemDetail?>((ref) {
  final item = ref.watch(gearModalInstanceProvider);
  if (item == null) return null;
  ref.watch(gearModalRevisionProvider);
  return ref
      .watch(inventoryRepositoryProvider)
      .resolveDetail(item, withPerkColumns: true);
});
