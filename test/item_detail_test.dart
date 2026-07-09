import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/core/destiny/plug_category.dart';
import 'package:destiny2_loadout_planner/data/remote/bungie_api.dart';
import 'package:destiny2_loadout_planner/data/repositories/inventory_repository.dart';
import 'package:destiny2_loadout_planner/data/repositories/manifest_repository.dart';

class _MockApi extends Mock implements BungieApi {}

class _MockManifest extends Mock implements ManifestRepository {}

void main() {
  const weaponHash = 1001;
  const rangeStatHash = 1240592695;
  const framePlugHash = 3001; // intrinsic
  const perkPlugHash = 3002; // trait
  const enhancedPerkPlugHash = 3005; // enhanced trait
  const modPlugHash = 3003; // weapon mod
  const trackerPlugHash = 3004; // masterwork kill tracker
  const breakerHash = 2611060930; // Disruption

  late _MockApi api;
  late _MockManifest manifest;
  late InventoryRepository repo;

  setUp(() {
    api = _MockApi();
    manifest = _MockManifest();
    repo = InventoryRepository(api: api, manifest: manifest);

    when(() => api.getMembershipsForCurrentUser()).thenAnswer((_) async => {
          'destinyMemberships': [
            {'membershipType': 3, 'membershipId': 42, 'displayName': 'G'}
          ],
          'primaryMembershipId': 42,
        });

    when(() => manifest.getInventoryItem(weaponHash)).thenReturn({
      'displayProperties': {'name': 'Eyasluna', 'icon': '/i/gun.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'equippingBlock': {'ammoType': 1},
      'breakerTypeHash': breakerHash, // intrinsic champion breaker
    });

    // Plug definitions, categorised by plugCategoryIdentifier.
    when(() => manifest.getInventoryItem(framePlugHash)).thenReturn({
      'displayProperties': {'name': 'Adaptive Frame', 'icon': '/i/frame.jpg'},
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
    });
    when(() => manifest.getInventoryItem(perkPlugHash)).thenReturn({
      'displayProperties': {'name': 'Headstone', 'icon': '/i/perk.jpg'},
      'plug': {'plugCategoryIdentifier': 'v300.weapon.traits'},
    });
    when(() => manifest.getInventoryItem(enhancedPerkPlugHash)).thenReturn({
      'displayProperties': {
        'name': 'Enhanced Headstone',
        'icon': '/i/perk_e.jpg',
        'description': 'Enhanced effect.',
      },
      // Enhanced traits share the "frames" category with base traits; the
      // distinguishing signal is itemTypeDisplayName == "Enhanced Trait".
      'itemTypeDisplayName': 'Enhanced Trait',
      'plug': {'plugCategoryIdentifier': 'frames'},
    });
    when(() => manifest.getInventoryItem(modPlugHash)).thenReturn({
      'displayProperties': {'name': 'Backup Mag', 'icon': '/i/mod.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
    });
    when(() => manifest.getInventoryItem(trackerPlugHash)).thenReturn({
      'displayProperties': {'name': 'Kill Tracker', 'icon': '/i/tracker.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.masterworks.trackers'},
    });

    when(() => manifest.getStat(rangeStatHash)).thenReturn({
      'displayProperties': {'name': 'Range'},
    });
    when(() => manifest.getBreakerType(breakerHash)).thenReturn({
      'displayProperties': {'name': 'Disruption', 'icon': '/i/breaker.jpg'},
    });
    // Default: no catalyst record for a weapon (overridden in the catalyst test).
    when(() => manifest.findCatalystRecord(any())).thenReturn(null);

    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'c1': {
                'characterId': 'c1',
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
              'c1': {
                'items': [
                  {
                    'itemHash': weaponHash,
                    'itemInstanceId': '999',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'itemComponents': {
            'instances': {
              'data': {
                '999': {'damageType': 3, 'primaryStat': {'value': 540}}
              }
            },
            'stats': {
              'data': {
                '999': {
                  'stats': {
                    '$rangeStatHash': {
                      'statHash': rangeStatHash,
                      'value': 73
                    }
                  }
                }
              }
            },
            'sockets': {
              'data': {
                '999': {
                  'sockets': [
                    {'plugHash': framePlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': perkPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': enhancedPerkPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': modPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': trackerPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': 55, 'isEnabled': true, 'isVisible': false},
                  ]
                }
              }
            },
            'plugObjectives': {
              'data': {
                '999': {
                  'objectivesPerPlug': {
                    '$trackerPlugHash': [
                      {'objectiveHash': 90275515, 'progress': 1234}
                    ]
                  }
                }
              }
            },
          },
        });
  });

  test('resolveDetail resolves stats, categorised plugs, and breaker',
      () async {
    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;

    final detail = repo.resolveDetail(weapon);

    // Stats
    expect(detail.stats.single.name, 'Range');
    expect(detail.stats.single.value, 73);

    // Plugs categorised; the invisible socket and the tracker are skipped.
    expect(detail.plugsOf(PlugCategory.frame).single.name, 'Adaptive Frame');
    final perks = detail.plugsOf(PlugCategory.perk).toList();
    expect(perks.map((p) => p.name),
        containsAll(['Headstone', 'Enhanced Headstone']));
    expect(detail.plugsOf(PlugCategory.mod).single.name, 'Backup Mag');
    expect(detail.plugs.length, 4);
    // The kill tracker is surfaced separately, not as a masterwork plug.
    expect(detail.plugsOf(PlugCategory.masterwork), isEmpty);

    // The enhanced trait is flagged; the base trait is not.
    expect(perks.firstWhere((p) => p.name == 'Enhanced Headstone').isEnhanced,
        isTrue);
    expect(
        perks.firstWhere((p) => p.name == 'Headstone').isEnhanced, isFalse);

    // Kill tracker resolved from the tracker plug + its objective progress.
    expect(detail.killTracker?.count, 1234);
    expect(detail.killTracker?.iconPath, '/i/tracker.jpg');

    // Exotic-style breaker resolved from the item definition's breakerTypeHash.
    expect(detail.breaker?.name, 'Disruption');

    // Header fields carried through from the definition.
    expect(detail.item.itemTypeDisplayName, 'Hand Cannon');
    expect(detail.item.ammoType, 1);
  });

  test('breaker falls back to a frame marker perk when the def has none',
      () async {
    const legendaryHash = 5001;
    const framePlugHash2 = 5002;
    const markerPerkHash = 5003;

    when(() => manifest.getInventoryItem(legendaryHash)).thenReturn({
      'displayProperties': {'name': 'Blast Furnace', 'icon': '/i/bf.jpg'},
      'itemType': 3,
      'itemSubType': 13,
      'itemTypeDisplayName': 'Pulse Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      // No breakerTypeHash on the definition (legendary).
    });
    // The intrinsic frame plug carries the marker sandbox perk.
    when(() => manifest.getInventoryItem(framePlugHash2)).thenReturn({
      'displayProperties': {'name': 'Aggressive Burst', 'icon': '/i/ab.jpg'},
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
      'perks': [
        {'perkHash': markerPerkHash}
      ],
    });
    when(() => manifest.getSandboxPerk(markerPerkHash)).thenReturn({
      'displayProperties': {
        'name': '[Stagger] Unstoppable',
        'icon': '/i/unstop.jpg'
      },
    });

    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'c1': {
                'characterId': 'c1',
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
              'c1': {
                'items': [
                  {
                    'itemHash': legendaryHash,
                    'itemInstanceId': '888',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'itemComponents': {
            'instances': {
              'data': {
                '888': {'damageType': 3, 'primaryStat': {'value': 543}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                '888': {
                  'sockets': [
                    {
                      'plugHash': framePlugHash2,
                      'isEnabled': true,
                      'isVisible': true
                    }
                  ]
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon);

    // Cleaned marker → breaker label.
    expect(detail.breaker?.name, 'Unstoppable');
  });

  test('catalyst progress resolves from the record + Records component',
      () async {
    const exoticHash = 6001;
    const catalystRecordHash = 6002;

    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': 'D.A.R.C.I.', 'icon': '/i/darci.jpg'},
      'itemType': 3,
      'itemSubType': 12,
      'itemTypeDisplayName': 'Sniper Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
    });
    when(() => manifest.findCatalystRecord('D.A.R.C.I.')).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {
        'name': 'D.A.R.C.I. Catalyst',
        'description': 'Defeat enemies with precision final blows.',
      },
    });

    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'c1': {
                'characterId': 'c1',
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
              'c1': {
                'items': [
                  {
                    'itemHash': exoticHash,
                    'itemInstanceId': '777',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'profileRecords': {
            'data': {
              'records': {
                '$catalystRecordHash': {
                  // Bit 4 (ObjectiveNotCompleted) set → still locked.
                  'state': 4,
                  'objectives': [
                    {'progress': 342, 'completionValue': 500, 'complete': false}
                  ]
                }
              }
            }
          },
          'itemComponents': {
            'instances': {
              'data': {
                '777': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'stats': {'data': {}},
            'sockets': {'data': {}},
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon);

    expect(detail.catalyst?.name, 'D.A.R.C.I. Catalyst');
    expect(detail.catalyst?.complete, isFalse);
    expect(detail.catalyst?.progress, 342);
    expect(detail.catalyst?.completionValue, 500);
  });

  test('a completed catalyst (ObjectiveNotCompleted bit clear) reads complete',
      () async {
    const exoticHash = 6001;
    const catalystRecordHash = 6002;

    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': 'D.A.R.C.I.', 'icon': '/i/d.jpg'},
      'itemType': 3,
      'itemSubType': 12,
      'itemTypeDisplayName': 'Sniper Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
    });
    when(() => manifest.findCatalystRecord('D.A.R.C.I.')).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {'name': 'D.A.R.C.I. Catalyst', 'description': ''},
    });
    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'c1': {
                'characterId': 'c1',
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
              'c1': {
                'items': [
                  {
                    'itemHash': exoticHash,
                    'itemInstanceId': '777',
                    'bucketHash': EquipmentBucket.kineticWeapons.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'profileRecords': {
            'data': {
              'records': {
                // state 1 = RecordRedeemed; ObjectiveNotCompleted (bit 4) clear.
                '$catalystRecordHash': {
                  'state': 1,
                  'objectives': [
                    {'progress': 700, 'completionValue': 700, 'complete': true}
                  ]
                }
              }
            }
          },
          'itemComponents': {
            'instances': {
              'data': {
                '777': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'stats': {'data': {}},
            'sockets': {'data': {}},
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon);

    expect(detail.catalyst?.complete, isTrue);
  });
}
