import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/core/destiny/drop_validation.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_character.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_item.dart';
import 'package:destiny2_loadout_planner/domain/models/inventory_grid.dart';

const _kinetic = EquipmentBucket.kineticWeapons;
const _helmet = EquipmentBucket.helmet;

DestinyItem _item({
  int bucketHash = 1498876634, // kinetic
  String? instanceId = '1',
  int? classType,
  bool isEquipped = false,
}) =>
    DestinyItem(
      itemHash: 1,
      bucketHash: bucketHash,
      name: 'Item',
      iconPath: '',
      itemInstanceId: instanceId,
      classType: classType,
      isEquipped: isEquipped,
    );

/// A character owner holding [unequipped] extra kinetic items (all in the
/// kinetic bucket) so the 3×3 cap can be exercised.
InventoryOwner _character(
  String id, {
  int classType = 1,
  int unequipped = 0,
}) =>
    InventoryOwner(
      id: id,
      title: id,
      isVault: false,
      character: DestinyCharacter(
        characterId: id,
        classType: classType,
        light: 1900,
        emblemPath: '',
        emblemBackgroundPath: '',
        dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      itemsByBucket: {
        _kinetic.hash: [
          for (var i = 0; i < unequipped; i++)
            DestinyItem(
              itemHash: 100 + i,
              bucketHash: _kinetic.hash,
              name: 'Filler $i',
              iconPath: '',
              itemInstanceId: 'filler$i',
            ),
        ],
      },
    );

const _vault = InventoryOwner(
  id: 'vault',
  title: 'Vault',
  isVault: true,
  itemsByBucket: {},
);

void main() {
  group('canDrop', () {
    test('allows a kinetic weapon into a character kinetic slot', () {
      final v = canDrop(_item(), _character('charB'), _kinetic,
          currentOwnerId: 'vault');
      expect(v.allowed, isTrue);
    });

    test('allows dropping into the vault (uncapped)', () {
      final v =
          canDrop(_item(), _vault, _kinetic, currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('denies a bucket mismatch (helmet into kinetic row)', () {
      final v = canDrop(_item(bucketHash: _helmet.hash), _character('charB'),
          _kinetic,
          currentOwnerId: 'vault');
      expect(v.allowed, isFalse);
      expect(v.reason, contains('slot'));
    });

    test('denies dropping onto the current owner as a silent no-op', () {
      final v = canDrop(_item(), _character('charA'), _kinetic,
          currentOwnerId: 'charA');
      expect(v.allowed, isFalse);
      expect(v.reason, isNull); // no-op: no error affordance
    });

    test('denies when the target character bucket already holds 9 unequipped',
        () {
      final full = _character('charB', unequipped: maxUnequippedPerBucket);
      final v =
          canDrop(_item(), full, _kinetic, currentOwnerId: 'vault');
      expect(v.allowed, isFalse);
      expect(v.reason, contains('full'));
    });

    test('allows when the target bucket holds 8 (one below the cap)', () {
      final nearlyFull =
          _character('charB', unequipped: maxUnequippedPerBucket - 1);
      final v =
          canDrop(_item(), nearlyFull, _kinetic, currentOwnerId: 'vault');
      expect(v.allowed, isTrue);
    });

    test('denies an uninstanced item', () {
      final v = canDrop(_item(instanceId: null), _character('charB'), _kinetic,
          currentOwnerId: 'vault');
      expect(v.allowed, isFalse);
    });
  });

  group('canEquip', () {
    test('allows equipping an item already on the character, matching class',
        () {
      final v = canEquip(_item(classType: 1), _character('charA', classType: 1),
          currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('allows equipping an item from another owner (a move-then-equip)', () {
      // From the vault onto charA: valid — the controller moves it first.
      final v = canEquip(_item(classType: 1), _character('charA', classType: 1),
          currentOwnerId: 'vault');
      expect(v.allowed, isTrue);
    });

    test('allows equipping a copy from another character', () {
      final v = canEquip(_item(classType: 1), _character('charA', classType: 1),
          currentOwnerId: 'charB');
      expect(v.allowed, isTrue);
    });

    test('denies equipping onto the vault', () {
      final v =
          canEquip(_item(), _vault, currentOwnerId: 'vault');
      expect(v.allowed, isFalse);
    });

    test('denies a class mismatch (Titan gear on a Hunter)', () {
      // Titan item (classType 0) onto a Hunter character (classType 1).
      final v = canEquip(_item(classType: 0), _character('charA', classType: 1),
          currentOwnerId: 'charA');
      expect(v.allowed, isFalse);
      expect(v.reason, contains('class'));
    });

    test('allows class-agnostic gear (classType 3) on any character', () {
      final v = canEquip(_item(classType: 3), _character('charA', classType: 1),
          currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('an already-equipped item is a silent no-op', () {
      final v = canEquip(_item(classType: 1, isEquipped: true),
          _character('charA', classType: 1),
          currentOwnerId: 'charA');
      expect(v.allowed, isFalse);
      expect(v.reason, isNull);
    });
  });

  group('canEquip exotic limit', () {
    // itemType 2 = armor, 3 = weapon; tierType 6 = exotic.
    DestinyItem gearIn(EquipmentBucket bucket,
            {required String id, required int tier, bool equipped = false}) =>
        DestinyItem(
          itemHash: 1,
          bucketHash: bucket.hash,
          name: 'Gear $id',
          iconPath: '',
          itemInstanceId: id,
          classType: 1,
          tierType: tier,
          itemType: bucket.isWeapon ? 3 : 2,
          isEquipped: equipped,
        );

    DestinyItem exoticIn(EquipmentBucket bucket,
            {required String id, bool equipped = false}) =>
        gearIn(bucket, id: id, tier: 6, equipped: equipped);

    DestinyItem legendaryIn(EquipmentBucket bucket,
            {required String id, bool equipped = false}) =>
        gearIn(bucket, id: id, tier: 5, equipped: equipped);

    InventoryOwner ownerWith(List<DestinyItem> items) {
      final byBucket = <int, List<DestinyItem>>{};
      for (final i in items) {
        (byBucket[i.bucketHash] ??= []).add(i);
      }
      return InventoryOwner(
        id: 'charA',
        title: 'charA',
        isVault: false,
        character: DestinyCharacter(
          characterId: 'charA',
          classType: 1,
          light: 1900,
          emblemPath: '',
          emblemBackgroundPath: '',
          dateLastPlayed: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        itemsByBucket: byBucket,
      );
    }

    test('denies a second exotic in the same category (exotic armor already on)',
        () {
      // Exotic helmet equipped; try to equip exotic gauntlets (both armor).
      final owner = ownerWith([
        exoticIn(EquipmentBucket.helmet, id: 'helm', equipped: true),
        exoticIn(EquipmentBucket.gauntlets, id: 'gaunt'),
      ]);
      final v = canEquip(owner.itemsFor(EquipmentBucket.gauntlets.hash).single,
          owner,
          currentOwnerId: 'charA');
      expect(v.allowed, isFalse);
      expect(v.reason, contains('exotic'));
    });

    test('allows swapping an exotic into a slot that already holds an exotic',
        () {
      // Exotic helmet A equipped; equip exotic helmet B (same bucket) — a swap,
      // still one exotic armor.
      final owner = ownerWith([
        exoticIn(EquipmentBucket.helmet, id: 'helmA', equipped: true),
        exoticIn(EquipmentBucket.helmet, id: 'helmB'),
      ]);
      final helmB = owner
          .itemsFor(EquipmentBucket.helmet.hash)
          .firstWhere((i) => i.itemInstanceId == 'helmB');
      final v = canEquip(helmB, owner, currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('exotic weapon does not block an exotic armor piece (separate limits)',
        () {
      // Exotic kinetic weapon equipped; equipping an exotic helmet is fine.
      final owner = ownerWith([
        exoticIn(EquipmentBucket.kineticWeapons, id: 'wpn', equipped: true),
        exoticIn(EquipmentBucket.helmet, id: 'helm'),
      ]);
      final helm = owner.itemsFor(EquipmentBucket.helmet.hash).single;
      final v = canEquip(helm, owner, currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('denies a second exotic weapon (exotic weapon already equipped)', () {
      final owner = ownerWith([
        exoticIn(EquipmentBucket.kineticWeapons, id: 'k', equipped: true),
        exoticIn(EquipmentBucket.energyWeapons, id: 'e'),
      ]);
      final energy = owner.itemsFor(EquipmentBucket.energyWeapons.hash).single;
      final v = canEquip(energy, owner, currentOwnerId: 'charA');
      expect(v.allowed, isFalse);
    });

    test('allows an exotic when no other exotic is equipped in the category',
        () {
      // Only legendaries equipped elsewhere; equip an exotic helmet.
      final owner = ownerWith([
        legendaryIn(EquipmentBucket.gauntlets, id: 'g', equipped: true),
        exoticIn(EquipmentBucket.helmet, id: 'helm'),
      ]);
      final helm = owner.itemsFor(EquipmentBucket.helmet.hash).single;
      final v = canEquip(helm, owner, currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });

    test('a legendary item is never blocked by the exotic limit', () {
      // Exotic helmet equipped; equipping a legendary chest is fine.
      final owner = ownerWith([
        exoticIn(EquipmentBucket.helmet, id: 'helm', equipped: true),
        legendaryIn(EquipmentBucket.chestArmor, id: 'chest'),
      ]);
      final chest = owner.itemsFor(EquipmentBucket.chestArmor.hash).single;
      final v = canEquip(chest, owner, currentOwnerId: 'charA');
      expect(v.allowed, isTrue);
    });
  });
}
