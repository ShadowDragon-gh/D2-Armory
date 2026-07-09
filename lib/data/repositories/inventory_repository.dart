import '../../core/destiny/destiny_buckets.dart';
import '../../domain/models/destiny_character.dart';
import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import '../remote/bungie_api.dart';
import 'manifest_repository.dart';
import 'membership_service.dart';

/// Builds the DIM-style inventory grid: character + vault columns, each with
/// items grouped by equipment bucket, names/icons resolved from the manifest.
class InventoryRepository {
  InventoryRepository({
    required BungieApi api,
    required this._manifest,
  })  : _api = api,
        _memberships = MembershipService(api);

  final BungieApi _api;
  final ManifestRepository _manifest;
  final MembershipService _memberships;

  static const _components = [
    100, // Profiles
    200, // Characters
    102, // ProfileInventories (vault)
    201, // CharacterInventories
    205, // CharacterEquipment
    300, // ItemInstances (power, damage type)
  ];

  Future<InventoryGrid> fetchInventory() async {
    final membership = await _memberships.resolvePrimary();
    final profile = await _api.getProfile(
      membershipType: membership.membershipType,
      membershipId: membership.membershipId,
      components: _components,
    );

    final instances = _dataMap(profile['itemComponents']?['instances']);

    // Characters, newest-played first — these become the leading columns.
    final characters = _dataMap(profile['characters'])
        .values
        .map((c) => DestinyCharacter.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateLastPlayed.compareTo(a.dateLastPlayed));

    final equipment = _dataMap(profile['characterEquipment']);
    final charInventories = _dataMap(profile['characterInventories']);

    final owners = <InventoryOwner>[];
    for (final character in characters) {
      final items = <DestinyItem>[
        ..._itemsOf(equipment[character.characterId], instances,
            equipped: true),
        ..._itemsOf(charInventories[character.characterId], instances),
      ];
      owners.add(InventoryOwner(
        id: character.characterId,
        title: character.className,
        isVault: false,
        character: character,
        itemsByBucket: _groupByBucket(items),
      ));
    }

    // Vault (profile inventory). Equipment-slot items in the vault report the
    // General bucket, so they are re-grouped by their definition's bucket.
    final vaultItems =
        _itemsOf(profile['profileInventory'], instances, useDefBucket: true);
    owners.add(InventoryOwner(
      id: 'vault',
      title: 'Vault',
      isVault: true,
      itemsByBucket: _groupByBucket(vaultItems),
    ));

    return InventoryGrid(owners);
  }

  /// Resolve the `items` list of an inventory/equipment component into display
  /// items, keeping only those in a known equipment bucket.
  List<DestinyItem> _itemsOf(
    dynamic component,
    Map<String, dynamic> instances, {
    bool equipped = false,
    bool useDefBucket = false,
  }) {
    final map = component is Map<String, dynamic> ? component : null;
    final data = map?['data'];
    final items = (data is Map<String, dynamic> ? data['items'] : null) ??
        (map?['items']);
    if (items is! List) return const [];

    final result = <DestinyItem>[];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final itemHash = (item['itemHash'] as num?)?.toInt();
      if (itemHash == null) continue;

      final def = _manifest.getInventoryItem(itemHash);
      if (def == null) continue;

      // Bucket: the item's own bucketHash, unless it sits in the vault's
      // general bucket, in which case fall back to the definition's bucket.
      final defBucket =
          (def['inventory']?['bucketTypeHash'] as num?)?.toInt();
      final itemBucket = (item['bucketHash'] as num?)?.toInt();
      final bucketHash = useDefBucket ? (defBucket ?? itemBucket) : itemBucket;
      if (bucketHash == null || EquipmentBucket.fromHash(bucketHash) == null) {
        continue; // only weapon/armor slots are shown
      }

      // int64 ids (itemInstanceId) are serialized as JSON strings by Bungie;
      // accept either form defensively.
      final instanceId = item['itemInstanceId']?.toString();
      final instance = instanceId == null
          ? null
          : instances[instanceId] as Map<String, dynamic>?;
      final display = def['displayProperties'] as Map<String, dynamic>?;
      final state = (item['state'] as num?)?.toInt() ?? 0;

      // Element glyph comes from the damage-type definition (its transparent
      // icon), resolved via the instance's damageTypeHash.
      final damageTypeHash =
          (instance?['damageTypeHash'] as num?)?.toInt();
      String? elementIconPath;
      if (damageTypeHash != null) {
        final dmgDef = _manifest.getDamageType(damageTypeHash);
        elementIconPath = (dmgDef?['transparentIconPath'] as String?) ??
            (dmgDef?['displayProperties']?['icon'] as String?);
      }

      result.add(DestinyItem(
        itemHash: itemHash,
        bucketHash: bucketHash,
        name: (display?['name'] as String?) ?? '',
        iconPath: (display?['icon'] as String?) ?? '',
        itemType: (def['itemType'] as num?)?.toInt() ?? 0,
        itemSubType: (def['itemSubType'] as num?)?.toInt() ?? 0,
        tierType: (def['inventory']?['tierType'] as num?)?.toInt() ?? 0,
        classType: (def['classType'] as num?)?.toInt(),
        itemInstanceId: instanceId,
        power: (instance?['primaryStat']?['value'] as num?)?.toInt(),
        damageType: (instance?['damageType'] as num?)?.toInt(),
        elementIconPath: elementIconPath,
        isEquipped: equipped,
        // ItemState bit flags: Locked=1, Masterwork=4.
        isLocked: state & 1 != 0,
        isMasterwork: state & 4 != 0,
      ));
    }
    return result;
  }

  Map<int, List<DestinyItem>> _groupByBucket(List<DestinyItem> items) {
    final grouped = <int, List<DestinyItem>>{};
    for (final item in items) {
      (grouped[item.bucketHash] ??= []).add(item);
    }
    // Equipped first, then by power descending.
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.isEquipped != b.isEquipped) return a.isEquipped ? -1 : 1;
        return (b.power ?? 0).compareTo(a.power ?? 0);
      });
    }
    return grouped;
  }

  Map<String, dynamic> _dataMap(dynamic component) {
    if (component is Map<String, dynamic>) {
      final data = component['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return const {};
  }
}
