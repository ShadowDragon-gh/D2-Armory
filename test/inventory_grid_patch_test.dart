import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/inventory_grid.dart';

const _kinetic = EquipmentBucket.kineticWeapons;
final _kh = _kinetic.hash;

DestinyItem _rifle(String id, {bool equipped = false, int? power}) =>
    DestinyItem(
      itemHash: 555,
      bucketHash: _kh,
      name: 'Rifle $id',
      iconPath: '',
      itemInstanceId: id,
      isEquipped: equipped,
      power: power,
    );

InventoryOwner _character(String id, List<DestinyItem> kinetic) =>
    InventoryOwner(
      id: id,
      title: id,
      isVault: false,
      itemsByBucket: {if (kinetic.isNotEmpty) _kh: kinetic},
    );

InventoryOwner _vault(List<DestinyItem> kinetic) => InventoryOwner(
      id: 'vault',
      title: 'Vault',
      isVault: true,
      itemsByBucket: {if (kinetic.isNotEmpty) _kh: kinetic},
    );

void main() {
  group('withItemMoved', () {
    test('relocates an item from the vault to a character', () {
      final grid = InventoryGrid([
        _character('charA', []),
        _vault([_rifle('r1')]),
      ]);

      final next = grid.withItemMoved(
        instanceId: 'r1',
        fromOwnerId: 'vault',
        toOwnerId: 'charA',
      );

      final vault = next.owners.firstWhere((o) => o.isVault);
      final charA = next.owners.firstWhere((o) => o.id == 'charA');
      expect(vault.itemsFor(_kh), isEmpty);
      expect(charA.itemsFor(_kh).map((i) => i.itemInstanceId), ['r1']);
    });

    test('does not mutate the original grid (immutability)', () {
      final vaultRifle = _rifle('r1');
      final grid = InventoryGrid([
        _character('charA', []),
        _vault([vaultRifle]),
      ]);

      grid.withItemMoved(
          instanceId: 'r1', fromOwnerId: 'vault', toOwnerId: 'charA');

      // Original still shows the rifle in the vault.
      final vault = grid.owners.firstWhere((o) => o.isVault);
      expect(vault.itemsFor(_kh).single.itemInstanceId, 'r1');
    });

    test('a transferred equipped item lands unequipped in the destination', () {
      final grid = InventoryGrid([
        _character('charA', [_rifle('r1', equipped: true)]),
        _vault([]),
      ]);

      final next = grid.withItemMoved(
          instanceId: 'r1', fromOwnerId: 'charA', toOwnerId: 'vault');

      final moved = next.owners
          .firstWhere((o) => o.isVault)
          .itemsFor(_kh)
          .single;
      expect(moved.itemInstanceId, 'r1');
      expect(moved.isEquipped, isFalse);
    });

    test('leaves other items in the source bucket in place', () {
      final grid = InventoryGrid([
        _character('charA', []),
        _vault([_rifle('r1'), _rifle('r2'), _rifle('r3')]),
      ]);

      final next = grid.withItemMoved(
          instanceId: 'r2', fromOwnerId: 'vault', toOwnerId: 'charA');

      final vault = next.owners.firstWhere((o) => o.isVault);
      expect(vault.itemsFor(_kh).map((i) => i.itemInstanceId), ['r1', 'r3']);
    });

    test('inserts the moved item in power-descending order (not at the end)',
        () {
      // Vault holds two rifles at power 1800 and 1600; move a 1700-power rifle
      // in from a character. It must land BETWEEN them, not appended last.
      final grid = InventoryGrid([
        _character('charA', [_rifle('mid', power: 1700)]),
        _vault([_rifle('high', power: 1800), _rifle('low', power: 1600)]),
      ]);

      final next = grid.withItemMoved(
          instanceId: 'mid', fromOwnerId: 'charA', toOwnerId: 'vault');

      final vault = next.owners.firstWhere((o) => o.isVault);
      expect(vault.itemsFor(_kh).map((i) => i.itemInstanceId),
          ['high', 'mid', 'low']);
    });

    test('returns the same grid when the item is not in the source owner', () {
      final grid = InventoryGrid([
        _character('charA', []),
        _vault([_rifle('r1')]),
      ]);

      final next = grid.withItemMoved(
          instanceId: 'nope', fromOwnerId: 'vault', toOwnerId: 'charA');
      expect(identical(next, grid), isTrue);
    });

    test('returns the same grid for a same-owner move', () {
      final grid = InventoryGrid([_vault([_rifle('r1')])]);
      final next = grid.withItemMoved(
          instanceId: 'r1', fromOwnerId: 'vault', toOwnerId: 'vault');
      expect(identical(next, grid), isTrue);
    });

    test('two-hop patch (char A -> vault -> char B) lands on B', () {
      final grid = InventoryGrid([
        _character('charA', [_rifle('r1')]),
        _character('charB', []),
        _vault([]),
      ]);

      // Hop 1: A -> vault.
      final afterHop1 = grid.withItemMoved(
          instanceId: 'r1', fromOwnerId: 'charA', toOwnerId: 'vault');
      expect(afterHop1.owners.firstWhere((o) => o.isVault).itemsFor(_kh).single
          .itemInstanceId, 'r1');

      // Hop 2: vault -> B.
      final afterHop2 = afterHop1.withItemMoved(
          instanceId: 'r1', fromOwnerId: 'vault', toOwnerId: 'charB');
      expect(afterHop2.owners.firstWhere((o) => o.id == 'charB').itemsFor(_kh)
          .single.itemInstanceId, 'r1');
      expect(afterHop2.owners.firstWhere((o) => o.isVault).itemsFor(_kh),
          isEmpty);
      expect(afterHop2.owners.firstWhere((o) => o.id == 'charA').itemsFor(_kh),
          isEmpty);
    });
  });

  group('withItemEquipped', () {
    test('equips the target and unequips the previously-equipped item', () {
      final grid = InventoryGrid([
        _character('charA', [
          _rifle('equipped', equipped: true),
          _rifle('spare'),
        ]),
      ]);

      final next =
          grid.withItemEquipped(instanceId: 'spare', ownerId: 'charA');
      final bucket = next.owners.single.itemsFor(_kh);
      final equipped = bucket.firstWhere((i) => i.isEquipped);
      expect(equipped.itemInstanceId, 'spare');
      // The old equipped item is now unequipped, and only one item is equipped.
      expect(bucket.where((i) => i.isEquipped).length, 1);
      expect(bucket.firstWhere((i) => i.itemInstanceId == 'equipped').isEquipped,
          isFalse);
    });

    test('does not mutate the original grid', () {
      final grid = InventoryGrid([
        _character('charA', [
          _rifle('equipped', equipped: true),
          _rifle('spare'),
        ]),
      ]);

      grid.withItemEquipped(instanceId: 'spare', ownerId: 'charA');
      // Original unchanged: 'equipped' still equipped, 'spare' still not.
      final bucket = grid.owners.single.itemsFor(_kh);
      expect(bucket.firstWhere((i) => i.itemInstanceId == 'equipped').isEquipped,
          isTrue);
      expect(bucket.firstWhere((i) => i.itemInstanceId == 'spare').isEquipped,
          isFalse);
    });

    test('returns the same grid when the item is already equipped', () {
      final grid = InventoryGrid([
        _character('charA', [_rifle('e', equipped: true)]),
      ]);
      final next = grid.withItemEquipped(instanceId: 'e', ownerId: 'charA');
      expect(identical(next, grid), isTrue);
    });

    test('returns the same grid when the item is not on the owner', () {
      final grid = InventoryGrid([
        _character('charA', [_rifle('e', equipped: true)]),
      ]);
      final next = grid.withItemEquipped(instanceId: 'nope', ownerId: 'charA');
      expect(identical(next, grid), isTrue);
    });
  });
}
