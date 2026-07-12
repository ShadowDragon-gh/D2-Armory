import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import 'destiny_buckets.dart';

/// The outcome of a pre-flight drop check: whether the drop is allowed, and —
/// when it is not — a short human reason the UI can surface (and use to tint
/// the hover target red). A no-op self-drop is [allowed] false with no reason,
/// so the UI simply shows no affordance rather than an error.
class DropVerdict {
  const DropVerdict._(this.allowed, this.reason);

  const DropVerdict.allow() : this._(true, null);

  /// A rejection the user should see explained (bucket full, wrong slot, …).
  const DropVerdict.deny(String reason) : this._(false, reason);

  /// A silent rejection (dropping onto where the item already is): no move, no
  /// message.
  const DropVerdict.noop() : this._(false, null);

  final bool allowed;
  final String? reason;
}

/// Max unequipped items a character may hold in one equipment bucket — the 3×3
/// grid the inventory renders (the equipped slot is separate). A drop that
/// would exceed this is rejected locally rather than bounced by Bungie.
const int maxUnequippedPerBucket = 9;

/// Whether [item] may be dropped into [targetOwner]'s [targetBucket] as an
/// unequipped transfer. Pure and decidable from the current grid — it drives
/// both the hover affordance and the guard before the transfer POST.
///
/// Rules:
/// - only instanced gear is movable;
/// - the item's bucket must match the target bucket (a helmet can't go in the
///   kinetic row);
/// - dropping onto the owner the item already belongs to is a no-op;
/// - a character bucket may hold at most [maxUnequippedPerBucket] unequipped
///   items (the vault is uncapped here).
DropVerdict canDrop(
  DestinyItem item,
  InventoryOwner targetOwner,
  EquipmentBucket targetBucket, {
  required String currentOwnerId,
}) {
  if (item.itemInstanceId == null) {
    return const DropVerdict.deny('Only instanced items can be moved.');
  }
  if (item.bucketHash != targetBucket.hash) {
    return const DropVerdict.deny('Wrong slot for this item.');
  }
  if (targetOwner.id == currentOwnerId) {
    return const DropVerdict.noop();
  }
  if (!targetOwner.isVault &&
      targetOwner.unequippedIn(targetBucket.hash).length >=
          maxUnequippedPerBucket) {
    return const DropVerdict.deny('That slot is full.');
  }
  return const DropVerdict.allow();
}

/// Whether [item] may be equipped on [targetOwner] by dropping it on the
/// equipped slot. v1 requires the item already be on that character (equipping
/// pulls nothing across), and the item must be usable by the character's class.
DropVerdict canEquip(
  DestinyItem item,
  InventoryOwner targetOwner, {
  required String currentOwnerId,
}) {
  if (item.itemInstanceId == null) {
    return const DropVerdict.deny('Only instanced items can be equipped.');
  }
  if (targetOwner.isVault) {
    return const DropVerdict.deny('Items in the vault cannot be equipped.');
  }
  if (targetOwner.id != currentOwnerId) {
    return const DropVerdict.deny('Move it to this character first.');
  }
  if (item.isEquipped) {
    return const DropVerdict.noop(); // already equipped here
  }
  if (!_classAllows(item.classType, targetOwner.character?.classType)) {
    return const DropVerdict.deny('Wrong class for this item.');
  }
  return const DropVerdict.allow();
}

/// True when an item of [itemClass] can be used by a character of
/// [characterClass]. DestinyClass 3 (or a null item class) is class-agnostic
/// gear usable by anyone.
bool _classAllows(int? itemClass, int? characterClass) {
  if (itemClass == null || itemClass == 3) return true;
  return itemClass == characterClass;
}
