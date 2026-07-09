import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/data/remote/bungie_api.dart';
import 'package:destiny2_loadout_planner/data/repositories/inventory_repository.dart';
import 'package:destiny2_loadout_planner/data/repositories/manifest_repository.dart';

class _MockApi extends Mock implements BungieApi {}

class _MockManifest extends Mock implements ManifestRepository {}

void main() {
  late _MockApi api;
  late _MockManifest manifest;
  late InventoryRepository repo;

  // Hashes used across the fixtures.
  const kineticHash = 1001;
  const helmetHash = 2002;

  setUp(() {
    api = _MockApi();
    manifest = _MockManifest();
    repo = InventoryRepository(api: api, manifest: manifest);

    when(() => api.getMembershipsForCurrentUser()).thenAnswer((_) async => {
          'destinyMemberships': [
            {'membershipType': 3, 'membershipId': 42, 'displayName': 'Guardian'}
          ],
          'primaryMembershipId': 42,
        });

    // Manifest returns a definition placing kineticHash in the kinetic bucket
    // and helmetHash in the helmet bucket, each with a name + icon.
    when(() => manifest.getInventoryItem(kineticHash)).thenReturn({
      'displayProperties': {'name': 'Test Rifle', 'icon': '/icon/rifle.jpg'},
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
    });
    when(() => manifest.getInventoryItem(helmetHash)).thenReturn({
      'displayProperties': {'name': 'Test Helm', 'icon': '/icon/helm.jpg'},
      'inventory': {'bucketTypeHash': EquipmentBucket.helmet.hash},
    });

    // Solar damage-type definition (hash 1847026933) → its glyph.
    when(() => manifest.getDamageType(1847026933)).thenReturn({
      'transparentIconPath': '/icon/solar.png',
    });
    // Any other damage-type hash resolves to nothing.
    when(() => manifest.getDamageType(any(that: isNot(1847026933))))
        .thenReturn(null);
  });

  test('groups equipped + inventory items into buckets, equipped first', () async {
    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'char1': {
                'characterId': 'char1',
                'classType': 1,
                'light': 500,
                'emblemPath': '',
                'emblemBackgroundPath': '',
                'dateLastPlayed': '2026-07-01T00:00:00Z',
              }
            }
          },
          'characterEquipment': {
            'data': {
              'char1': {
                'items': [
                  {
                    'itemHash': kineticHash,
                    // int64 ids arrive as JSON strings from Bungie.
                    'itemInstanceId': '111',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {
            'data': {
              'char1': {
                'items': [
                  {
                    'itemHash': kineticHash,
                    'itemInstanceId': '222',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'profileInventory': {
            'data': {
              'items': [
                {
                  'itemHash': helmetHash,
                  'itemInstanceId': '333',
                  // Vault items report the general bucket; def bucket is used.
                  'bucketHash': 138197802,
                  'state': 0,
                }
              ]
            }
          },
          'itemComponents': {
            'instances': {
              'data': {
                '111': {
                  'damageType': 3,
                  'damageTypeHash': 1847026933,
                  'primaryStat': {'value': 540}
                },
                '222': {'damageType': 3, 'primaryStat': {'value': 500}},
              }
            }
          },
        });

    final grid = await repo.fetchInventory();

    // One character column + vault.
    expect(grid.owners.length, 2);
    final char = grid.owners.first;
    expect(char.isVault, isFalse);

    final kinetic = char.itemsFor(EquipmentBucket.kineticWeapons.hash);
    expect(kinetic.length, 2);
    // Equipped item sorts first even though its power ties/leads.
    expect(kinetic.first.isEquipped, isTrue);
    expect(kinetic.first.power, 540);
    expect(kinetic.first.damageType, 3);
    expect(kinetic.first.name, 'Test Rifle');
    // Element glyph resolved from the damage-type definition.
    expect(kinetic.first.elementIconUrl,
        'https://www.bungie.net/icon/solar.png');

    // Vault helmet re-grouped via the definition's bucket, not general.
    final vault = grid.owners.last;
    expect(vault.isVault, isTrue);
    expect(vault.itemsFor(EquipmentBucket.helmet.hash).single.name, 'Test Helm');
  });

  test('skips items with no manifest definition', () async {
    when(() => manifest.getInventoryItem(9999)).thenReturn(null);
    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {'data': {}},
          'characterEquipment': {'data': {}},
          'characterInventories': {'data': {}},
          'profileInventory': {
            'data': {
              'items': [
                {'itemHash': 9999, 'bucketHash': EquipmentBucket.helmet.hash}
              ]
            }
          },
          'itemComponents': {'instances': {'data': {}}},
        });

    final grid = await repo.fetchInventory();
    expect(grid.owners.single.isVault, isTrue);
    expect(grid.owners.single.itemsFor(EquipmentBucket.helmet.hash), isEmpty);
  });
}
