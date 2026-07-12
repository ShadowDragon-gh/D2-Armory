import 'destiny_character.dart';
import 'destiny_item.dart';

/// The canonical order of items within one equipment bucket: the equipped item
/// first, then by power descending. Used both when building the grid from a
/// profile and when patching it after a move, so a moved item lands in the same
/// order a refetch would place it (rather than at the end of the list).
List<DestinyItem> sortBucketItems(List<DestinyItem> items) {
  final sorted = [...items]..sort((a, b) {
      if (a.isEquipped != b.isEquipped) return a.isEquipped ? -1 : 1;
      return (b.power ?? 0).compareTo(a.power ?? 0);
    });
  return sorted;
}

/// One column in the inventory grid: a character or the vault.
class InventoryOwner {
  const InventoryOwner({
    required this.id,
    required this.title,
    required this.isVault,
    required this.itemsByBucket,
    this.character,
  });

  /// characterId, or 'vault'.
  final String id;
  final String title;
  final bool isVault;

  /// Present for character owners (for the emblem/class in the header).
  final DestinyCharacter? character;

  /// Items in this column keyed by their equipment bucket hash.
  final Map<int, List<DestinyItem>> itemsByBucket;

  List<DestinyItem> itemsFor(int bucketHash) =>
      itemsByBucket[bucketHash] ?? const [];

  /// The equipped item in [bucketHash], if any (characters only).
  DestinyItem? equippedIn(int bucketHash) {
    for (final item in itemsFor(bucketHash)) {
      if (item.isEquipped) return item;
    }
    return null;
  }

  /// Non-equipped items in [bucketHash].
  List<DestinyItem> unequippedIn(int bucketHash) =>
      itemsFor(bucketHash).where((i) => !i.isEquipped).toList();

  /// A copy of this owner with [bucketHash]'s item list replaced. Other buckets
  /// share the original (immutable) lists; only the changed one is rebuilt.
  InventoryOwner withBucket(int bucketHash, List<DestinyItem> items) {
    final next = Map<int, List<DestinyItem>>.from(itemsByBucket);
    if (items.isEmpty) {
      next.remove(bucketHash);
    } else {
      next[bucketHash] = List.unmodifiable(items);
    }
    return InventoryOwner(
      id: id,
      title: title,
      isVault: isVault,
      character: character,
      itemsByBucket: next,
    );
  }
}

/// The full grid: ordered owners (characters by last-played, then vault).
class InventoryGrid {
  const InventoryGrid(this.owners);

  final List<InventoryOwner> owners;

  /// A new grid with the instanced item [instanceId] relocated from owner
  /// [fromOwnerId] to owner [toOwnerId] — the in-memory patch applied after a
  /// successful move, so the grid updates instantly without a full refetch.
  ///
  /// The item lands unequipped in its destination bucket. A no-op (returns the
  /// same grid) when the item is not found in the source owner, or the owners
  /// are the same. Both owners must exist; if the item's source bucket is not
  /// found the grid is returned unchanged.
  InventoryGrid withItemMoved({
    required String instanceId,
    required String fromOwnerId,
    required String toOwnerId,
  }) {
    if (fromOwnerId == toOwnerId) return this;

    final from = owners.where((o) => o.id == fromOwnerId).firstOrNull;
    final to = owners.where((o) => o.id == toOwnerId).firstOrNull;
    if (from == null || to == null) return this;

    // Locate the item and its bucket in the source owner.
    DestinyItem? moved;
    int? bucketHash;
    for (final entry in from.itemsByBucket.entries) {
      final match = entry.value
          .where((i) => i.itemInstanceId == instanceId)
          .firstOrNull;
      if (match != null) {
        moved = match;
        bucketHash = entry.key;
        break;
      }
    }
    if (moved == null || bucketHash == null) return this;

    final fromItems = from
        .itemsFor(bucketHash)
        .where((i) => i.itemInstanceId != instanceId)
        .toList();
    // Insert in the bucket's canonical order (power-descending) so the item
    // lands where a refetch would place it, not at the end of the list.
    final toItems =
        sortBucketItems([...to.itemsFor(bucketHash), moved.asUnequipped()]);

    final patchedFrom = from.withBucket(bucketHash, fromItems);
    final patchedTo = to.withBucket(bucketHash, toItems);

    return InventoryGrid([
      for (final owner in owners)
        owner.id == fromOwnerId
            ? patchedFrom
            : owner.id == toOwnerId
                ? patchedTo
                : owner,
    ]);
  }

  /// A new grid reflecting [instanceId] becoming the equipped item in its bucket
  /// on owner [ownerId] — the in-memory patch after a successful equip, so the
  /// grid updates instantly without a refetch. The item is marked equipped and
  /// whatever was equipped in that bucket is marked unequipped.
  ///
  /// A no-op (returns the same grid) when the owner or item is not found, or the
  /// item is already equipped.
  InventoryGrid withItemEquipped({
    required String instanceId,
    required String ownerId,
  }) {
    final owner = owners.where((o) => o.id == ownerId).firstOrNull;
    if (owner == null) return this;

    // Find the item's bucket on this owner.
    int? bucketHash;
    for (final entry in owner.itemsByBucket.entries) {
      if (entry.value.any((i) => i.itemInstanceId == instanceId)) {
        bucketHash = entry.key;
        break;
      }
    }
    if (bucketHash == null) return this;

    final current = owner.itemsFor(bucketHash);
    if (current.any((i) => i.itemInstanceId == instanceId && i.isEquipped)) {
      return this; // already equipped — nothing to change
    }

    // Equip the target; unequip whatever was equipped in this bucket.
    final patchedItems = [
      for (final item in current)
        item.itemInstanceId == instanceId
            ? item.asEquipped()
            : item.isEquipped
                ? item.asUnequipped()
                : item,
    ];

    final patchedOwner = owner.withBucket(bucketHash, patchedItems);
    return InventoryGrid([
      for (final o in owners) o.id == ownerId ? patchedOwner : o,
    ]);
  }
}
