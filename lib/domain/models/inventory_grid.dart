import 'destiny_character.dart';
import 'destiny_item.dart';

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
}

/// The full grid: ordered owners (characters by last-played, then vault).
class InventoryGrid {
  const InventoryGrid(this.owners);

  final List<InventoryOwner> owners;
}
