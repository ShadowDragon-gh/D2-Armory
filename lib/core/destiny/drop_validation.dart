import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import 'destiny_buckets.dart';
import 'destiny_enums.dart';

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
  if (item.itemType == DestinyEnums.typeSubclass) {
    return const DropVerdict.deny("Subclasses can't be transferred.");
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
/// equipped slot. The item may come from another character or the vault — the
/// controller then moves it to [targetOwner] first and equips it. The item must
/// be usable by the character's class and respect the one-exotic-per-category
/// limit.
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
  // Already equipped on this character → nothing to do (a silent no-op). This
  // only applies when the item is on the target owner; a copy from elsewhere is
  // a move-then-equip below.
  if (item.isEquipped && targetOwner.id == currentOwnerId) {
    return const DropVerdict.noop();
  }
  if (!_classAllows(item.classType, targetOwner.character?.classType)) {
    return const DropVerdict.deny('Wrong class for this item.');
  }
  // Exotic limit: at most one exotic equipped per category (weapons and armor
  // are counted separately). Equipping an exotic while a *different* exotic is
  // already equipped in another slot of the same category is invalid.
  if (_isExotic(item) &&
      _hasConflictingExotic(item, targetOwner)) {
    return DropVerdict.deny(
        'Already using an exotic ${_categoryLabel(item)}.');
  }
  return const DropVerdict.allow();
}

bool _isExotic(DestinyItem item) => item.tierType == 6;

/// Whether [item]'s slot is a weapon slot (vs an armor slot). Falls back to the
/// item type when the bucket is unknown.
bool _isWeaponCategory(DestinyItem item) {
  final bucket = EquipmentBucket.fromHash(item.bucketHash);
  if (bucket != null) return bucket.isWeapon;
  return item.itemType == 3; // DestinyItemType 3 = Weapon
}

String _categoryLabel(DestinyItem item) =>
    _isWeaponCategory(item) ? 'weapon' : 'armor piece';

/// True when [owner] already has an exotic equipped in a *different* bucket of
/// [item]'s category (weapon vs armor). Swapping an exotic into a slot that
/// already holds an exotic is fine — only a second exotic in the category is
/// the conflict.
bool _hasConflictingExotic(DestinyItem item, InventoryOwner owner) {
  final wantWeapon = _isWeaponCategory(item);
  for (final entry in owner.itemsByBucket.entries) {
    if (entry.key == item.bucketHash) continue; // same slot → a swap, not a 2nd
    final equipped = owner.equippedIn(entry.key);
    if (equipped == null || !_isExotic(equipped)) continue;
    if (_isWeaponCategory(equipped) == wantWeapon) return true;
  }
  return false;
}

/// True when an item of [itemClass] can be used by a character of
/// [characterClass]. DestinyClass 3 (or a null item class) is class-agnostic
/// gear usable by anyone.
bool _classAllows(int? itemClass, int? characterClass) {
  if (itemClass == null || itemClass == 3) return true;
  return itemClass == characterClass;
}
