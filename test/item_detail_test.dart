import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/destiny/plug_category.dart';
import 'package:d2_armory/domain/models/item_detail.dart';
import 'package:d2_armory/data/remote/bungie_api.dart';
import 'package:d2_armory/data/repositories/inventory_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';

class _MockApi extends Mock implements BungieApi {}

class _MockManifest extends Mock implements ManifestRepository {}

void main() {
  const weaponHash = 1001;
  const rangeStatHash = 1240592695;
  const handlingStatHash = 943549884;
  const framePlugHash = 3001; // intrinsic
  const perkPlugHash = 3002; // trait
  const enhancedPerkPlugHash = 3005; // enhanced trait
  const modPlugHash = 3003; // weapon mod
  const trackerPlugHash = 3004; // masterwork kill tracker
  const masterworkPlugHash = 3006; // range masterwork (+10)
  const ornamentPlugHash = 3007; // applied weapon ornament
  // A "Default Ornament" whose hash is NOT in the well-known blocklist:
  // it must be skipped by its name.
  const defaultOrnamentHash = 3009;
  const mementoSocketHash = 3008; // craftable's empty memento socket
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
      // Stats are computed from the definition (DIM model): `stats.stats`
      // declares which stats the item shows, `investmentStats` the base roll.
      // No stat group → 1:1 (identity) interpolation.
      'stats': {
        'stats': {
          '$rangeStatHash': {'statHash': rangeStatHash},
          '$handlingStatHash': {'statHash': handlingStatHash},
          '4043523819': {'statHash': 4043523819},
        }
      },
      'investmentStats': [
        {'statTypeHash': rangeStatHash, 'value': 51},
        {'statTypeHash': handlingStatHash, 'value': 46},
        {'statTypeHash': 4043523819, 'value': -5},
      ],
    });

    // Plug definitions, categorised by plugCategoryIdentifier.
    when(() => manifest.getInventoryItem(framePlugHash)).thenReturn({
      'displayProperties': {'name': 'Adaptive Frame', 'icon': '/i/frame.jpg'},
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
    });
    when(() => manifest.getInventoryItem(perkPlugHash)).thenReturn({
      'displayProperties': {'name': 'Headstone', 'icon': '/i/perk.jpg'},
      'plug': {'plugCategoryIdentifier': 'v300.weapon.traits'},
      // A perk drawback: counts toward the red deficit, while its positive
      // contribution folds into the base bar.
      'investmentStats': [
        {'statTypeHash': handlingStatHash, 'value': -4},
        {'statTypeHash': rangeStatHash, 'value': 7},
      ],
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
      'investmentStats': [
        {'statTypeHash': handlingStatHash, 'value': -12},
        // A positive mod contribution — the blue bar segment.
        {'statTypeHash': rangeStatHash, 'value': 5},
      ],
    });
    when(() => manifest.getInventoryItem(trackerPlugHash)).thenReturn({
      'displayProperties': {'name': 'Kill Tracker', 'icon': '/i/tracker.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.masterworks.trackers'},
    });
    // Ornament plugs: the default one restores the original look and never
    // overrides the icon; the applied one supplies the tile's icon.
    when(() => manifest.getInventoryItem(defaultOrnamentHash)).thenReturn({
      'displayProperties': {'name': 'Default Ornament', 'icon': '/i/swirl.jpg'},
      'itemSubType': 21,
      'plug': {'plugCategoryIdentifier': 'exotic_all_skins'},
    });
    when(() => manifest.getInventoryItem(ornamentPlugHash)).thenReturn({
      'displayProperties': {'name': 'Gilded Smoke', 'icon': '/i/ornament.jpg'},
      'itemSubType': 21,
      'plug': {'plugCategoryIdentifier': 'exotic_all_skins'},
    });
    // The craftable memento socket shares the generic crafting empty-socket
    // category but belongs with the cosmetics.
    when(() => manifest.getInventoryItem(mementoSocketHash)).thenReturn({
      'displayProperties': {
        'name': 'Empty Memento Socket',
        'icon': '/i/memento.jpg',
      },
      'plug': {'plugCategoryIdentifier': 'crafting.recipes.empty_socket'},
    });
    when(() => manifest.getInventoryItem(masterworkPlugHash)).thenReturn({
      'displayProperties': {'name': 'Masterwork: Range', 'icon': '/i/mw.jpg'},
      'plug': {
        'plugCategoryIdentifier': 'v400.plugs.weapons.masterworks.stat.range'
      },
      'investmentStats': [
        {'statTypeHash': rangeStatHash, 'value': 10},
      ],
    });

    when(() => manifest.getStat(rangeStatHash)).thenReturn({
      'displayProperties': {'name': 'Range'},
    });
    when(() => manifest.getStat(handlingStatHash)).thenReturn({
      'displayProperties': {'name': 'Handling'},
    });
    when(() => manifest.getStat(4043523819)).thenReturn({
      'displayProperties': {'name': 'Weapons'},
    });
    when(() => manifest.getBreakerType(breakerHash)).thenReturn({
      'displayProperties': {'name': 'Disruption', 'icon': '/i/breaker.jpg'},
    });
    // Default: no catalyst for a weapon (overridden in the catalyst tests).
    when(() => manifest.catalystRecordHashFor(any())).thenReturn(null);
    when(() => manifest.getRecord(any())).thenReturn(null);
    when(() => manifest.findCatalystRecord(any())).thenReturn(null);
    when(() => manifest.getObjective(any())).thenReturn(null);
    when(() => manifest.getPlugSet(any())).thenReturn(null);

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
            'sockets': {
              'data': {
                '999': {
                  'sockets': [
                    {'plugHash': framePlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': perkPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': enhancedPerkPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': modPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': trackerPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': masterworkPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': defaultOrnamentHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': ornamentPlugHash, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': mementoSocketHash, 'isEnabled': true, 'isVisible': true},
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

    // Stats: the masterwork's +10 Range is the gold segment and the mod's +5
    // Range is the blue segment (split by source); the perk's +7 Range folds
    // into the base bar. Reductions from the mod (-12) and the perk drawback
    // (-4) combine into the red deficit segment.
    final range = detail.stats.firstWhere((s) => s.name == 'Range');
    expect(range.value, 73);
    expect(range.masterworkBonus, 10);
    expect(range.modBonus, 5);
    expect(range.bonus, 15); // combined getter
    expect(range.reduction, 0);
    final handling = detail.stats.firstWhere((s) => s.name == 'Handling');
    expect(handling.value, 30);
    expect(handling.masterworkBonus, 0);
    expect(handling.modBonus, 0);
    expect(handling.reduction, 16);
    // A negative stat value resolves without throwing, with no gain segment.
    final weapons = detail.stats.firstWhere((s) => s.name == 'Weapons');
    expect(weapons.value, -5);
    expect(weapons.bonus, 0);

    // Plugs categorised; the invisible socket and the tracker are skipped.
    expect(detail.plugsOf(PlugCategory.frame).single.name, 'Adaptive Frame');
    final perks = detail.plugsOf(PlugCategory.perk).toList();
    expect(perks.map((p) => p.name),
        containsAll(['Headstone', 'Enhanced Headstone']));
    expect(detail.plugsOf(PlugCategory.mod).single.name, 'Backup Mag');
    expect(detail.plugs.length, 8);

    // The memento socket is cosmetic, not a trait, despite its generic
    // crafting empty-socket category.
    expect(detail.plugsOf(PlugCategory.cosmetic).map((p) => p.name),
        contains('Empty Memento Socket'));
    expect(perks.map((p) => p.name),
        isNot(contains('Empty Memento Socket')));

    // The applied ornament's icon overrides the tile icon; the well-known
    // Default Ornament plug (socketed first) is skipped.
    expect(weapon.ornamentIconPath, '/i/ornament.jpg');
    // The kill tracker is surfaced separately, not as a masterwork plug.
    expect(detail.plugsOf(PlugCategory.masterwork).single.name,
        'Masterwork: Range');

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
    const catalystPlugHash = 6003;
    const effectPerkHash = 6004;
    const stabilityStatHash = 155624089;

    // The weapon definition lists the catalyst plug inline on its masterwork
    // socket entry, which is where the effect is resolved from.
    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': 'D.A.R.C.I.', 'icon': '/i/darci.jpg'},
      'itemType': 3,
      'itemSubType': 12,
      'itemTypeDisplayName': 'Sniper Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'sockets': {
        'socketEntries': [
          {
            'reusablePlugItems': [
              {'plugItemHash': catalystPlugHash}
            ]
          }
        ]
      },
    });
    // Resolved via DIM's itemHash -> recordHash map (the primary path).
    when(() => manifest.catalystRecordHashFor(exoticHash))
        .thenReturn(catalystRecordHash);
    when(() => manifest.getRecord(catalystRecordHash)).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {
        'name': 'D.A.R.C.I. Catalyst',
        'description': 'Defeat enemies with precision final blows.',
      },
    });

    // The catalyst plug carries the effect (a sandbox perk + a stat).
    when(() => manifest.getInventoryItem(catalystPlugHash)).thenReturn({
      'displayProperties': {'name': 'D.A.R.C.I. Catalyst'},
      'plug': {'plugCategoryIdentifier': 'v620.exotic.weapon.masterwork'},
      'perks': [
        {'perkHash': effectPerkHash}
      ],
      'investmentStats': [
        {'statTypeHash': stabilityStatHash, 'value': 30}
      ],
    });
    when(() => manifest.getSandboxPerk(effectPerkHash)).thenReturn({
      'displayProperties': {
        'name': 'Personal Assistant',
        'description': 'Aiming marks a target.',
      },
    });
    when(() => manifest.getStat(stabilityStatHash)).thenReturn({
      'displayProperties': {'name': 'Stability'},
    });
    when(() => manifest.getObjective(9001)).thenReturn({
      'progressDescription': 'Precision Kills',
      'completionValue': 500,
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
                    {
                      'objectiveHash': 9001,
                      'progress': 342,
                      'completionValue': 500,
                      'complete': false
                    }
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
            'sockets': {
              'data': {
                '777': {
                  'sockets': [
                    {
                      'plugHash': catalystPlugHash,
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

    expect(detail.catalyst?.name, 'D.A.R.C.I. Catalyst');
    expect(detail.catalyst?.complete, isFalse);
    // Bit 8 (Obscured) clear: the catalyst is obtained, just not finished.
    expect(detail.catalyst?.acquired, isTrue);
    // Objective resolved with its name and per-objective progress.
    expect(detail.catalyst?.objectives.single.name, 'Precision Kills');
    expect(detail.catalyst?.objectives.single.progress, 342);
    expect(detail.catalyst?.objectives.single.completionValue, 500);

    // Effect resolved from the definition's catalyst plug (perk + stat).
    final option = detail.catalyst?.options.single;
    expect(option?.effects.single.name, 'Personal Assistant');
    expect(option?.effects.single.description, 'Aiming marks a target.');
    expect(option?.statBonuses.single.name, 'Stability');
    expect(option?.statBonuses.single.value, 30);
    // The socketed catalyst plug still shows as the masterwork plug row.
    expect(detail.plugsOf(PlugCategory.masterwork).single.name,
        'D.A.R.C.I. Catalyst');
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
    when(() => manifest.catalystRecordHashFor(exoticHash))
        .thenReturn(catalystRecordHash);
    when(() => manifest.getRecord(catalystRecordHash)).thenReturn({
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
    expect(detail.catalyst?.acquired, isTrue);
  });

  test('a catalyst with no record state reads not obtained, effect intact',
      () async {
    const exoticHash = 8001;
    const catalystRecordHash = 8002;
    const catalystPlugHash = 8003;
    const effectPerkHash = 8004;

    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': 'Vex Mythoclast', 'icon': '/i/vex.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Fusion Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'sockets': {
        'socketEntries': [
          {
            'reusablePlugItems': [
              {'plugItemHash': catalystPlugHash}
            ]
          }
        ]
      },
    });
    when(() => manifest.getInventoryItem(catalystPlugHash)).thenReturn({
      'displayProperties': {'name': 'Vex Mythoclast Catalyst'},
      'plug': {'plugCategoryIdentifier': 'v600.new.fusion_rifle0.masterwork'},
      'perks': [
        {'perkHash': effectPerkHash}
      ],
    });
    when(() => manifest.getSandboxPerk(effectPerkHash)).thenReturn({
      'displayProperties': {
        'name': 'Calculated Balance',
        'description': 'Gain a stack of Overcharge for each rapid kill.',
      },
    });
    when(() => manifest.catalystRecordHashFor(exoticHash))
        .thenReturn(catalystRecordHash);
    when(() => manifest.getRecord(catalystRecordHash)).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {'name': 'Vex Mythoclast Catalyst'},
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
          // No record state for the catalyst: the player has not obtained it.
          'profileRecords': {'data': {'records': {}}},
          'itemComponents': {
            'instances': {
              'data': {
                '888': {'damageType': 3, 'primaryStat': {'value': 540}}
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

    expect(detail.catalyst, isNotNull);
    expect(detail.catalyst?.acquired, isFalse);
    expect(detail.catalyst?.complete, isFalse);
    // The effect still resolves from the weapon definition.
    expect(detail.catalyst?.options.single.effects.single.name,
        'Calculated Balance');
  });

  test('crafting-era catalysts resolve multiple options from the plug set',
      () async {
    const exoticHash = 8101;
    const catalystRecordHash = 8102;
    const plugSetHash = 8103;
    const emptyPlugHash = 8104;
    const refitAHash = 8105;
    const refitBHash = 8106;
    const perkAHash = 8107;
    const perkBHash = 8108;

    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': "Slayer's Fang", 'icon': '/i/fang.jpg'},
      'itemType': 3,
      'itemSubType': 12,
      'itemTypeDisplayName': 'Sniper Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'sockets': {
        'socketEntries': [
          // The catalyst socket has no initial plug; its selectable options
          // live in a randomized plug set.
          {'randomizedPlugSetHash': plugSetHash}
        ]
      },
    });
    when(() => manifest.getPlugSet(plugSetHash)).thenReturn({
      'reusablePlugItems': [
        {'plugItemHash': emptyPlugHash},
        {'plugItemHash': refitAHash},
        {'plugItemHash': refitBHash},
      ],
    });
    // The empty shell contributes nothing and is dropped. It has no icon of
    // its own, so the classic empty-socket plug's icon is borrowed.
    when(() => manifest.getInventoryItem(emptyPlugHash)).thenReturn({
      'displayProperties': {'name': 'Empty Catalyst Socket'},
      'plug': {'plugCategoryIdentifier': 'v400.empty.exotic.masterwork'},
    });
    when(() => manifest.getInventoryItem(1498917124)).thenReturn({
      'displayProperties': {
        'name': 'Empty Catalyst Socket',
        'icon': '/i/empty_catalyst.png',
      },
      'plug': {'plugCategoryIdentifier': 'v400.empty.exotic.masterwork'},
    });
    when(() => manifest.getInventoryItem(refitAHash)).thenReturn({
      'displayProperties': {'name': 'Repulsor Brace Refit'},
      'plug': {'plugCategoryIdentifier': 'catalysts'},
      'perks': [
        {'perkHash': perkAHash}
      ],
    });
    when(() => manifest.getInventoryItem(refitBHash)).thenReturn({
      'displayProperties': {'name': 'Loose Change Refit'},
      'plug': {'plugCategoryIdentifier': 'catalysts'},
      'perks': [
        {'perkHash': perkBHash}
      ],
    });
    when(() => manifest.getSandboxPerk(perkAHash)).thenReturn({
      'displayProperties': {
        'name': 'Repulsor Brace',
        'description': 'Defeating a Void-debuffed target grants an overshield.',
      },
    });
    // Description carrying Bungie's named-substitution template tokens.
    when(() => manifest.getSandboxPerk(perkBHash)).thenReturn({
      'displayProperties': {
        'name': 'Loose Change',
        'description':
            'Harvest nests with [###DestinyNamedSubstitutions.ui_player_action_interact_button###] '
                '[###DestinyNamedSubstitutions.ui_player_action_interact_verb###] to gain a Tangle.',
      },
    });
    when(() => manifest.catalystRecordHashFor(exoticHash))
        .thenReturn(catalystRecordHash);
    when(() => manifest.getRecord(catalystRecordHash)).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {'name': "Slayer's Fang Catalyst"},
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
          'profileRecords': {'data': {'records': {}}},
          'itemComponents': {
            'instances': {
              'data': {
                '999': {'damageType': 4, 'primaryStat': {'value': 540}}
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

    final options = detail.catalyst?.options;
    expect(options?.length, 2);
    expect(options?[0].name, 'Repulsor Brace Refit');
    expect(options?[0].effects.single.name, 'Repulsor Brace');
    expect(options?[1].name, 'Loose Change Refit');
    // Substitution tokens replaced/stripped into readable text.
    expect(options?[1].effects.single.description,
        'Harvest nests with [Interact] to gain a Tangle.');
    // The live instance hides the empty catalyst socket, so the Masterwork
    // row is synthesized from the definition's shell plug, borrowing the
    // classic empty-socket icon when the shell has none.
    final emptyRow = detail.plugsOf(PlugCategory.masterwork).single;
    expect(emptyRow.name, 'Empty Catalyst Socket');
    expect(emptyRow.iconPath, '/i/empty_catalyst.png');
  });

  test('catalyst falls back to name matching when not in the record map',
      () async {
    const exoticHash = 7001;
    const catalystRecordHash = 7002;

    when(() => manifest.getInventoryItem(exoticHash)).thenReturn({
      'displayProperties': {'name': 'Whisper of the Worm', 'icon': '/i/w.jpg'},
      'itemType': 3,
      'itemSubType': 12,
      'itemTypeDisplayName': 'Sniper Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
    });
    // Not in DIM's map → resolver falls back to the name convention.
    when(() => manifest.catalystRecordHashFor(exoticHash)).thenReturn(null);
    when(() => manifest.findCatalystRecord('Whisper of the Worm')).thenReturn({
      'hash': catalystRecordHash,
      'displayProperties': {
        'name': 'Whisper of the Worm Catalyst',
        'description': '',
      },
    });
    when(() => manifest.getObjective(9002)).thenReturn({
      'progressDescription': 'Boss Damage',
      'completionValue': 65,
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
                    'itemInstanceId': '666',
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
                  'state': 4,
                  'objectives': [
                    {
                      'objectiveHash': 9002,
                      'progress': 10,
                      'completionValue': 65,
                      'complete': false
                    }
                  ]
                }
              }
            }
          },
          'itemComponents': {
            'instances': {
              'data': {
                '666': {'damageType': 1, 'primaryStat': {'value': 540}}
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

    expect(detail.catalyst?.name, 'Whisper of the Worm Catalyst');
    expect(detail.catalyst?.objectives.single.name, 'Boss Damage');
    expect(detail.catalyst?.objectives.single.progress, 10);
  });

  test('resolveDetail(withPerkColumns) resolves a weapon mod socket into an '
      'options column with the equipped mod flagged', () async {
    const modWeaponHash = 7001;
    const equippedMod = 7101; // Backup Mag (equipped)
    const altMod = 7102; // Appended Mag (alternative)
    const modsCategory = 2685412949; // WEAPON MODS socket category

    when(() => manifest.getInventoryItem(modWeaponHash)).thenReturn({
      'displayProperties': {'name': 'Modded HC', 'icon': '/i/hc.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'sockets': {
        // The mod socket is index 1.
        'socketCategories': [
          {
            'socketCategoryHash': modsCategory,
            'socketIndexes': [1],
          }
        ],
        'socketEntries': [
          {'singleInitialItemHash': 0},
          {'singleInitialItemHash': equippedMod},
        ],
      },
    });
    // Backup Mag: descriptive-only (prose on its sandbox perk, no stat effects)
    // — the fallback description must surface.
    const equippedSandboxPerk = 8200;
    when(() => manifest.getInventoryItem(equippedMod)).thenReturn({
      'displayProperties': {'name': 'Backup Mag', 'icon': '/i/bm.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
      'perks': [
        {'perkHash': equippedSandboxPerk}
      ],
    });
    when(() => manifest.getSandboxPerk(equippedSandboxPerk)).thenReturn({
      'displayProperties': {
        'description': 'Adds a small amount of reserve ammo.',
      },
    });
    // Appended Mag: a bare stat mod (a magazine stat, and a sandbox-perk
    // "description" that merely restates it) — the stat effect must surface and
    // the redundant restated description must NOT (the duplicate-line bug).
    const modSandboxPerk = 8201;
    const magazineStatHash = 3871231066;
    when(() => manifest.getInventoryItem(altMod)).thenReturn({
      'displayProperties': {'name': 'Appended Mag', 'icon': '/i/am.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
      'perks': [
        {'perkHash': modSandboxPerk}
      ],
      'investmentStats': [
        {'statTypeHash': magazineStatHash, 'value': 10},
      ],
    });
    when(() => manifest.getSandboxPerk(modSandboxPerk)).thenReturn({
      'displayProperties': {'description': '+10 Magazine'},
    });
    when(() => manifest.getStat(magazineStatHash)).thenReturn({
      'displayProperties': {'name': 'Magazine'},
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
                    'itemHash': modWeaponHash,
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
          'itemComponents': {
            'instances': {
              'data': {
                '777': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                '777': {
                  'sockets': [
                    {'plugHash': 0, 'isEnabled': true, 'isVisible': true},
                    {
                      'plugHash': equippedMod,
                      'isEnabled': true,
                      'isVisible': true
                    },
                  ]
                }
              }
            },
            // The socket's available options for socket index 1.
            'reusablePlugs': {
              'data': {
                '777': {
                  'plugs': {
                    '1': [
                      {'plugItemHash': equippedMod},
                      {'plugItemHash': altMod},
                    ]
                  }
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon, withPerkColumns: true);

    final modColumn = detail.modColumns.single;
    expect(modColumn.socketIndex, 1);
    expect(modColumn.plugs.map((p) => p.name),
        containsAll(['Backup Mag', 'Appended Mag']));
    // The equipped mod is the flagged (active) option.
    expect(modColumn.plugs[modColumn.activeIndex!].name, 'Backup Mag');
    // Each option carries the plug hash needed to insert it in-game.
    final appended =
        modColumn.plugs.firstWhere((p) => p.name == 'Appended Mag');
    expect(appended.plugHash, altMod);
    expect(appended.socketIndex, 1);
    // A bare stat mod: the stat effect surfaces, and the sandbox-perk
    // "description" that only restates it is suppressed (no duplicate line).
    expect(appended.statEffects.single.name, 'Magazine');
    expect(appended.statEffects.single.value, 10);
    expect(appended.description, isEmpty);

    // A descriptive-only mod (no stat effects) still gets its sandbox-perk
    // prose via the fallback.
    final backup = modColumn.plugs.firstWhere((p) => p.name == 'Backup Mag');
    expect(backup.statEffects, isEmpty);
    expect(backup.description, 'Adds a small amount of reserve ammo.');
  });

  test('resolveDetail(withPerkColumns) makes only modern ARMOR MODS sockets '
      '(enhancements.* whitelist) editable — dropping the masterwork socket, '
      'the legacy 1.0-mods socket, and the fixed ARMOR PERKS socket', () async {
    const armorHash = 9001;
    const armorModsCategory = 590099826; // ARMOR MODS
    const legacyPerksCategory = 2518356196; // legacy "ARMOR PERKS" (1.0 mods)
    const fixedPerksCategory = 3154740035; // built-in, non-swappable

    // Socket type hashes → distinct plug whitelists (what gates editability).
    const modHeadType = 968742181; // whitelist enhancements.v2_head → editable
    const masterworkType = 1843767421; // v460.plugs.armor.masterworks → dropped
    const legacyModType = 4076485920; // whitelist "mods" (1.0) → NOT editable
    const fixedType = 3154740036; // intrinsics-ish → not a mod socket

    // Socket 0: a modern ARMOR MODS slot with two swappable mods → a column.
    const equippedMod = 9101; // Recovery Mod (equipped)
    const altMod = 9102; // Resilience Mod (alternative)
    // Socket 2: the masterwork/tier socket → dropped (non-enhancements.*).
    const tierPlug = 9301; // Upgrade Armor
    // Socket 1: a legacy ARMOR PERKS 1.0-mods slot with two options — the free
    // socket-insert endpoint cannot edit these, so they must NOT be a column.
    const equippedLegacy = 9201; // Plasteel Reinforcement (equipped)
    const altLegacy = 9202; // Restorative (alternative)
    // Socket 3: a fixed (built-in) armor perk → never a mod column.
    const fixedPerk = 9401;

    when(() => manifest.getInventoryItem(armorHash)).thenReturn({
      'displayProperties': {'name': 'Test Helm', 'icon': '/i/helm.jpg'},
      'itemType': 2,
      'itemSubType': 26,
      'itemTypeDisplayName': 'Helmet',
      'inventory': {'bucketTypeHash': EquipmentBucket.helmet.hash},
      'sockets': {
        'socketCategories': [
          {
            'socketCategoryHash': armorModsCategory,
            'socketIndexes': [0, 2],
          },
          {
            'socketCategoryHash': legacyPerksCategory,
            'socketIndexes': [1],
          },
          {
            'socketCategoryHash': fixedPerksCategory,
            'socketIndexes': [3],
          },
        ],
        'socketEntries': [
          {'singleInitialItemHash': equippedMod, 'socketTypeHash': modHeadType},
          {
            'singleInitialItemHash': equippedLegacy,
            'socketTypeHash': legacyModType
          },
          {'singleInitialItemHash': tierPlug, 'socketTypeHash': masterworkType},
          {'singleInitialItemHash': fixedPerk, 'socketTypeHash': fixedType},
        ],
      },
    });
    // Socket-type whitelists: the enhancements.* family is what makes a socket
    // an editable modern mod slot; the others are excluded.
    when(() => manifest.getSocketType(modHeadType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'enhancements.v2_head'}
      ],
    });
    when(() => manifest.getSocketType(masterworkType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'v460.plugs.armor.masterworks'}
      ],
    });
    when(() => manifest.getSocketType(legacyModType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'mods'}
      ],
    });
    when(() => manifest.getSocketType(fixedType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'intrinsics'}
      ],
    });
    when(() => manifest.getInventoryItem(equippedMod)).thenReturn({
      'displayProperties': {'name': 'Recovery Mod', 'icon': '/i/rec.jpg'},
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_head'},
    });
    when(() => manifest.getInventoryItem(altMod)).thenReturn({
      'displayProperties': {'name': 'Resilience Mod', 'icon': '/i/res.jpg'},
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_head'},
    });
    when(() => manifest.getInventoryItem(equippedLegacy)).thenReturn({
      'displayProperties': {
        'name': 'Plasteel Reinforcement Mod',
        'icon': '/i/pl.jpg'
      },
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_general'},
    });
    when(() => manifest.getInventoryItem(altLegacy)).thenReturn({
      'displayProperties': {'name': 'Restorative Mod', 'icon': '/i/rt.jpg'},
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_general'},
    });
    // The masterwork "Upgrade Armor" plug is not a mod-category plug, so even
    // if it had alternatives it would be excluded; here it is a lone option.
    when(() => manifest.getInventoryItem(tierPlug)).thenReturn({
      'displayProperties': {'name': 'Upgrade Armor', 'icon': '/i/up.jpg'},
      'plug': {'plugCategoryIdentifier': 'v460.plugs.armor.masterworks'},
    });
    when(() => manifest.getInventoryItem(fixedPerk)).thenReturn({
      'displayProperties': {'name': 'Intrinsic Boost', 'icon': '/i/in.jpg'},
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
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
                    'itemHash': armorHash,
                    'itemInstanceId': '888',
                    'bucketHash': EquipmentBucket.helmet.hash,
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
                '888': {'primaryStat': {'value': 1800}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                '888': {
                  'sockets': [
                    {'plugHash': equippedMod, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': equippedLegacy, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': tierPlug, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': fixedPerk, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            'reusablePlugs': {
              'data': {
                '888': {
                  'plugs': {
                    '0': [
                      {'plugItemHash': equippedMod},
                      {'plugItemHash': altMod},
                    ],
                    '1': [
                      {'plugItemHash': equippedLegacy},
                      {'plugItemHash': altLegacy},
                    ],
                    // The masterwork socket lists only its single tier plug.
                    '2': [
                      {'plugItemHash': tierPlug},
                    ],
                  }
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final armor =
        grid.owners.first.itemsFor(EquipmentBucket.helmet.hash).single;
    final detail = repo.resolveDetail(armor, withPerkColumns: true);

    // Only the modern ARMOR MODS socket (0) is editable. The legacy 1.0-mods
    // socket (1), the masterwork socket (2), and the fixed-perk socket (3) are
    // all excluded — the free socket-insert endpoint cannot edit them.
    final bySocket = {for (final c in detail.modColumns) c.socketIndex: c};
    expect(bySocket.keys, unorderedEquals([0]));

    final armorModColumn = bySocket[0]!;
    expect(armorModColumn.plugs.map((p) => p.name),
        containsAll(['Recovery Mod', 'Resilience Mod']));
    expect(armorModColumn.plugs[armorModColumn.activeIndex!].name,
        'Recovery Mod');
    expect(
        armorModColumn.plugs.firstWhere((p) => p.name == 'Resilience Mod')
            .plugHash,
        altMod);

    // Armor never builds weapon-style perk columns.
    expect(detail.perkColumns, isEmpty);
  });

  test('an armor mod shows its real effect and stacking note, not its energy '
      'cost — the cost stat is not a stat effect', () async {
    const armorHash = 9501;
    const armorModsCategory = 590099826;
    const modChestType = 4015518015; // whitelist enhancements.chest → editable
    const equippedMod = 9601; // Void Resistance (equipped)
    const altMod = 9602; // Solar Resistance (alternative)
    const energyCostStat = 3578062600; // "Any Energy Type Cost"
    const voidResistPerk = 20057580;
    const solarResistPerk = 20057581;

    when(() => manifest.getInventoryItem(armorHash)).thenReturn({
      'displayProperties': {'name': 'Test Chest', 'icon': '/i/chest.jpg'},
      'itemType': 2,
      'itemSubType': 28,
      'itemTypeDisplayName': 'Chest Armor',
      'inventory': {'bucketTypeHash': EquipmentBucket.chestArmor.hash},
      'sockets': {
        'socketCategories': [
          {
            'socketCategoryHash': armorModsCategory,
            'socketIndexes': [0],
          },
        ],
        'socketEntries': [
          {'singleInitialItemHash': equippedMod, 'socketTypeHash': modChestType},
        ],
      },
    });
    when(() => manifest.getSocketType(modChestType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'enhancements.chest'}
      ],
    });
    // Void Resistance, mirroring the real manifest shape: an empty own
    // description, an energy-cost investment stat, the real effect on a sandbox
    // perk, and a perk-info stacking note.
    when(() => manifest.getInventoryItem(equippedMod)).thenReturn({
      'displayProperties': {
        'name': 'Void Resistance',
        'icon': '/i/vr.jpg',
        'description': '',
      },
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_chest'},
      'investmentStats': [
        {'statTypeHash': energyCostStat, 'value': 2},
      ],
      'perks': [
        {'perkHash': voidResistPerk}
      ],
      'tooltipNotifications': [
        {
          'displayString':
              'Multiple copies of this mod can be stacked to increase the '
                  'potency of its effect, with diminishing returns for each '
                  'additional copy of the mod.',
          'displayStyle': 'ui_display_style_perk_info',
        }
      ],
    });
    when(() => manifest.getSandboxPerk(voidResistPerk)).thenReturn({
      'isDisplayable': true,
      'displayProperties': {
        'description': 'Reduces incoming Void damage from combatants.',
      },
    });
    when(() => manifest.getInventoryItem(altMod)).thenReturn({
      'displayProperties': {
        'name': 'Solar Resistance',
        'icon': '/i/sr.jpg',
        'description': '',
      },
      'plug': {'plugCategoryIdentifier': 'enhancements.v2_chest'},
      'investmentStats': [
        {'statTypeHash': energyCostStat, 'value': 2},
      ],
      'perks': [
        {'perkHash': solarResistPerk}
      ],
    });
    when(() => manifest.getSandboxPerk(solarResistPerk)).thenReturn({
      'isDisplayable': true,
      'displayProperties': {
        'description': 'Reduces incoming Solar damage from combatants.',
      },
    });
    // The energy-cost stat must resolve to a name (so it would otherwise render
    // as a stat effect) — proving it is excluded by hash, not by a missing def.
    when(() => manifest.getStat(energyCostStat)).thenReturn({
      'displayProperties': {'name': 'Any Energy Type Cost'},
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
                    'itemHash': armorHash,
                    'itemInstanceId': '999',
                    'bucketHash': EquipmentBucket.chestArmor.hash,
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
                // Capacity comes from the instance's energy component. The
                // instance's own energyUsed is deliberately wrong (99) to prove
                // `used` is derived from the equipped mods' costs, not the stale
                // instance field — which is what lets the meter track an
                // optimistic swap before the profile refetches.
                '999': {
                  'primaryStat': {'value': 1800},
                  'energy': {'energyCapacity': 11, 'energyUsed': 99},
                }
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                '999': {
                  'sockets': [
                    {'plugHash': equippedMod, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            'reusablePlugs': {
              'data': {
                '999': {
                  'plugs': {
                    '0': [
                      {'plugItemHash': equippedMod},
                      {'plugItemHash': altMod},
                    ],
                  }
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final armor =
        grid.owners.first.itemsFor(EquipmentBucket.chestArmor.hash).single;
    final detail = repo.resolveDetail(armor, withPerkColumns: true);

    final voidMod = detail.modColumns.single.plugs
        .firstWhere((p) => p.name == 'Void Resistance');
    // The real gameplay effect surfaces (from the sandbox perk), not the empty
    // own description and not the energy cost.
    expect(voidMod.description, 'Reduces incoming Void damage from combatants.');
    // The energy cost is NOT rendered as a stat effect.
    expect(voidMod.statEffects, isEmpty);
    // The stacking note is carried, separately from the effect.
    expect(voidMod.note, contains('Multiple copies of this mod can be stacked'));

    // The mod's energy cost is carried (for the icon badge), sourced from the
    // cost stat that is excluded from the stat effects.
    expect(voidMod.energyCost, 2);

    // The equipped chip (read-only side-panel path) resolves the same way.
    final equippedChip =
        detail.plugsOf(PlugCategory.mod).firstWhere((p) => p.name == 'Void Resistance');
    expect(equippedChip.description,
        'Reduces incoming Void damage from combatants.');
    expect(equippedChip.statEffects, isEmpty);
    expect(equippedChip.note, contains('Multiple copies of this mod'));
    expect(equippedChip.energyCost, 2);

    // The armor energy meter: capacity from the instance, used from the summed
    // mod costs (the single cost-2 mod) — NOT the instance's stale energyUsed
    // (99), so an optimistic swap moves the meter before the refetch.
    expect(detail.armorEnergy, isNotNull);
    expect(detail.armorEnergy!.capacity, 11);
    expect(detail.armorEnergy!.used, 2);
  });

  test('armor mod options exclude artifact-gated, locked, and duplicate-empty '
      'placeholder plugs — keeping the real, insertable mods only', () async {
    const armorHash = 9701;
    const armorModsCategory = 590099826;
    const modHeadType = 968742181; // whitelist enhancements.v2_head
    const setHash = 5555; // the definition reusable plug set for the socket

    // The socket has no live 310 options (as real armor does), so the resolver
    // draws from the definition plug set below.
    const equippedMod = 9805; // Empty Mod Socket (equipped — the real empty)
    const realDup = 9802; // "Hands-On" cost 3 — real, insertable
    const artifactDup = 9803; // "Hands-On" cost 1 — artifact-discounted, gated
    const artifactOnly = 9804; // "Kinetic Charge Siphon" — artifact-only, gated
    const realMod = 9801; // Recovery Mod — a real selectable mod
    const lockedMod = 9806; // "Locked Armor Mod" — rank placeholder, excluded
    const dupEmpty = 9807; // a second "Empty Mod Socket" from the set — collapsed

    when(() => manifest.getInventoryItem(armorHash)).thenReturn({
      'displayProperties': {'name': 'Test Helm', 'icon': '/i/h.jpg'},
      'itemType': 2,
      'itemSubType': 26,
      'itemTypeDisplayName': 'Helmet',
      'inventory': {'bucketTypeHash': EquipmentBucket.helmet.hash},
      'sockets': {
        'socketCategories': [
          {'socketCategoryHash': armorModsCategory, 'socketIndexes': [0]},
        ],
        'socketEntries': [
          {
            'singleInitialItemHash': equippedMod,
            'socketTypeHash': modHeadType,
            'reusablePlugSetHash': setHash,
          },
        ],
      },
    });
    when(() => manifest.getSocketType(modHeadType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'enhancements.v2_head'}
      ],
    });
    when(() => manifest.getPlugSet(setHash)).thenReturn({
      'reusablePlugItems': [
        {'plugItemHash': dupEmpty}, // duplicate empty (from the set) → collapsed
        {'plugItemHash': realMod},
        {'plugItemHash': realDup},
        {'plugItemHash': artifactDup},
        {'plugItemHash': artifactOnly},
        {'plugItemHash': lockedMod}, // rank placeholder → excluded
      ],
    });

    // A plug def with the given name and insertion rules.
    Map<String, dynamic> modDef(String name, List<String> failureMessages) => {
          'displayProperties': {'name': name, 'icon': '/i/$name.jpg'},
          'plug': {
            'plugCategoryIdentifier': 'enhancements.v2_head',
            'insertionRules': [
              for (final m in failureMessages) {'failureMessage': m},
            ],
          },
        };

    // The equipped plug is the real "Empty Mod Socket" (no insertion rules).
    when(() => manifest.getInventoryItem(equippedMod))
        .thenReturn(modDef('Empty Mod Socket', const []));
    // A second empty from the definition pool — same name, must collapse away.
    when(() => manifest.getInventoryItem(dupEmpty))
        .thenReturn(modDef('Empty Mod Socket', const ['']));
    when(() => manifest.getInventoryItem(realMod))
        .thenReturn(modDef('Recovery Mod', const ['Requires Guardian Rank 3']));
    when(() => manifest.getInventoryItem(lockedMod)).thenReturn(modDef(
        'Locked Armor Mod',
        const ['Requires Guardian Rank 7: Threats and Surges']));
    when(() => manifest.getInventoryItem(realDup))
        .thenReturn(modDef('Hands-On', const ['Requires Guardian Rank 3']));
    // The discounted duplicate carries the extra artifact rule → excluded.
    when(() => manifest.getInventoryItem(artifactDup)).thenReturn(modDef(
        'Hands-On', const [
      'Requires Guardian Rank 3',
      'Must Be Selected in the Seasonal Artifact'
    ]));
    // An artifact-only mod (single variant) → also excluded.
    when(() => manifest.getInventoryItem(artifactOnly)).thenReturn(modDef(
        'Kinetic Charge Siphon',
        const ['Must Be Selected in the Seasonal Artifact']));

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
                    'itemHash': armorHash,
                    'itemInstanceId': '1000',
                    'bucketHash': EquipmentBucket.helmet.hash,
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
                '1000': {'primaryStat': {'value': 1800}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                '1000': {
                  'sockets': [
                    {'plugHash': equippedMod, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            // No 310 options for the socket — armor draws from the plug set.
            'reusablePlugs': {'data': {'1000': {'plugs': {}}}},
          },
        });

    final grid = await repo.fetchInventory();
    final armor =
        grid.owners.first.itemsFor(EquipmentBucket.helmet.hash).single;
    final detail = repo.resolveDetail(armor, withPerkColumns: true);

    final names = detail.modColumns.single.plugs.map((p) => p.name).toList();
    // Survivors: the equipped empty socket, the real Recovery Mod, and the real
    // (non-artifact) Hands-On.
    expect(names, containsAll(['Empty Mod Socket', 'Recovery Mod', 'Hands-On']));
    // The artifact-discounted Hands-On duplicate is dropped → only one Hands-On.
    expect(names.where((n) => n == 'Hands-On').length, 1);
    // The duplicate empty socket collapses → only one Empty Mod Socket.
    expect(names.where((n) => n == 'Empty Mod Socket').length, 1);
    // Artifact-only and locked placeholders are excluded entirely.
    expect(names, isNot(contains('Kinetic Charge Siphon')));
    expect(names, isNot(contains('Locked Armor Mod')));
  });

  test('ArmorEnergy.canAffordSwap gates a mod swap on remaining capacity', () {
    // 9 of 11 used, so 2 free. The current socket holds a cost-1 mod.
    const energy = ArmorEnergy(capacity: 11, used: 9);

    // Swap cost-1 → cost-3: net +2 → 11 used, exactly at capacity → allowed.
    expect(
        energy.canAffordSwap(equippedCost: 1, candidateCost: 3), isTrue);
    // Swap cost-1 → cost-4: net +3 → 12 used, over capacity → blocked.
    expect(
        energy.canAffordSwap(equippedCost: 1, candidateCost: 4), isFalse);
    // Swapping for a cheaper mod always fits.
    expect(
        energy.canAffordSwap(equippedCost: 3, candidateCost: 1), isTrue);
    // Re-selecting the same-cost mod is always affordable.
    expect(
        energy.canAffordSwap(equippedCost: 2, candidateCost: 2), isTrue);
  });

  test('rapid swaps on two sockets both persist through an edge-lagged refetch '
      '— a later fetch that has not propagated a swap does not revert it',
      () async {
    // A weapon with two swappable mod sockets (0 and 1).
    const gunHash = 8801;
    const modsCategory = 2685412949;
    // socket 0: 8810 → 8811, socket 1: 8820 → 8821.
    Map<String, dynamic> modDef(int h) => {
          'displayProperties': {'name': 'Mod$h', 'icon': '/i/$h.jpg'},
          'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
        };
    for (final h in [8810, 8811, 8820, 8821]) {
      when(() => manifest.getInventoryItem(h)).thenReturn(modDef(h));
    }
    when(() => manifest.getInventoryItem(gunHash)).thenReturn({
      'displayProperties': {'name': 'Test Gun', 'icon': '/i/g.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'sockets': {
        'socketCategories': [
          {'socketCategoryHash': modsCategory, 'socketIndexes': [0, 1]},
        ],
        'socketEntries': [
          {'singleInitialItemHash': 8810, 'reusablePlugSetHash': 8800},
          {'singleInitialItemHash': 8820, 'reusablePlugSetHash': 8802},
        ],
      },
    });
    when(() => manifest.getPlugSet(8800)).thenReturn({
      'reusablePlugItems': [
        {'plugItemHash': 8810},
        {'plugItemHash': 8811},
      ],
    });
    when(() => manifest.getPlugSet(8802)).thenReturn({
      'reusablePlugItems': [
        {'plugItemHash': 8820},
        {'plugItemHash': 8821},
      ],
    });

    Map<String, dynamic> profile(int s0, int s1, String minted) => {
          'responseMintedTimestamp': minted,
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
                    'itemHash': gunHash,
                    'itemInstanceId': 'w1',
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
                'w1': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                'w1': {
                  'sockets': [
                    {'plugHash': s0, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': s1, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            'reusablePlugs': {'data': {}},
          },
        };

    // 1) initial (T0). 2) after swap A: profile has socket0=8811 but not yet
    // socket1's change, minted T1. 3) after swap B: edge LAGS, same T1 profile
    // (socket1 still 8820) — the swap B optimistic edit must survive it.
    final responses = [
      profile(8810, 8820, '2026-07-01T00:00:00Z'),
      profile(8811, 8820, '2026-07-01T00:00:01Z'),
      profile(8811, 8820, '2026-07-01T00:00:01Z'),
    ];
    var call = 0;
    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async =>
        responses[call < responses.length ? call++ : responses.length - 1]);

    final grid = await repo.fetchInventory();
    final gun =
        grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;

    // Swap A on socket 0, then a refetch (as insertPlug does).
    repo.patchSocketPlug(gun, 0, 8811);
    await repo.fetchInventory(reuseDecoded: true);
    // Swap B on socket 1, then an edge-lagged refetch (no B yet).
    repo.patchSocketPlug(gun, 1, 8821);
    await repo.fetchInventory(reuseDecoded: true);

    final detail = repo.resolveDetail(gun, withPerkColumns: true);
    final active = {
      for (final c in detail.modColumns)
        c.socketIndex: c.plugs[c.activeIndex!].name
    };
    // Both swaps hold: A propagated in the profile, B held by the pending edit.
    expect(active[0], 'Mod8811');
    expect(active[1], 'Mod8821');
  });

  test('the armor stat-tuning trade-off socket is editable, and its equipped '
      '+X/-Y tags the affected stat rows', () async {
    const armorHash = 8901;
    const armorModsCategory = 590099826;
    const tuningType = 2581339086; // whitelist ...tuning.mods
    const tuningSet = 8900;
    const superStat = 1000; // arbitrary test stat hashes
    const healthStat = 1001;
    const equippedTuning = 8910; // +Super / -Health (equipped)
    const altTuning = 8911; // +Health / -Super (alternative)
    const emptyTuning = 8912; // Empty Tuning Mod Socket

    when(() => manifest.getInventoryItem(armorHash)).thenReturn({
      'displayProperties': {'name': 'Test Legs', 'icon': '/i/l.jpg'},
      'itemType': 2,
      'itemSubType': 29,
      'itemTypeDisplayName': 'Leg Armor',
      'inventory': {'bucketTypeHash': EquipmentBucket.legArmor.hash},
      'stats': {
        'stats': {
          '$superStat': {'statHash': superStat},
          '$healthStat': {'statHash': healthStat},
        }
      },
      'sockets': {
        'socketCategories': [
          {'socketCategoryHash': armorModsCategory, 'socketIndexes': [0]},
        ],
        'socketEntries': [
          {'singleInitialItemHash': equippedTuning, 'socketTypeHash': tuningType,
            'reusablePlugSetHash': tuningSet},
        ],
      },
    });
    when(() => manifest.getSocketType(tuningType)).thenReturn({
      'plugWhitelist': [
        {'categoryIdentifier': 'core.gear_systems.armor_tiering.plugs.tuning.mods'}
      ],
    });
    when(() => manifest.getPlugSet(tuningSet)).thenReturn({
      'reusablePlugItems': [
        {'plugItemHash': equippedTuning},
        {'plugItemHash': altTuning},
        {'plugItemHash': emptyTuning},
      ],
    });
    when(() => manifest.getStat(superStat)).thenReturn({
      'displayProperties': {'name': 'Super'}
    });
    when(() => manifest.getStat(healthStat)).thenReturn({
      'displayProperties': {'name': 'Health'}
    });
    Map<String, dynamic> tuningDef(String name, int plus, int minus,
            {List<String> rules = const ['Requires Guardian Rank 3']}) =>
        {
          'displayProperties': {'name': name, 'icon': '/i/tune.jpg'},
          'plug': {
            'plugCategoryIdentifier':
                'core.gear_systems.armor_tiering.plugs.tuning.mods',
            'insertionRules': [for (final m in rules) {'failureMessage': m}],
          },
          'investmentStats': [
            {'statTypeHash': plus, 'value': 5, 'isConditionallyActive': false},
            {'statTypeHash': minus, 'value': -5, 'isConditionallyActive': false},
          ],
        };
    when(() => manifest.getInventoryItem(equippedTuning))
        .thenReturn(tuningDef('+Super / -Health', superStat, healthStat));
    when(() => manifest.getInventoryItem(altTuning))
        .thenReturn(tuningDef('+Health / -Super', healthStat, superStat));
    when(() => manifest.getInventoryItem(emptyTuning)).thenReturn({
      'displayProperties': {'name': 'Empty Tuning Mod Socket', 'icon': '/i/e.jpg'},
      'plug': {
        'plugCategoryIdentifier':
            'core.gear_systems.armor_tiering.plugs.tuning.mods',
        'insertionRules': const [],
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
                    'itemHash': armorHash,
                    'itemInstanceId': 'a9',
                    'bucketHash': EquipmentBucket.legArmor.hash,
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
                'a9': {'primaryStat': {'value': 1800}}
              }
            },
            'stats': {'data': {}},
            'sockets': {
              'data': {
                'a9': {
                  'sockets': [
                    {'plugHash': equippedTuning, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            'reusablePlugs': {'data': {}},
          },
        });

    final grid = await repo.fetchInventory();
    final armor =
        grid.owners.first.itemsFor(EquipmentBucket.legArmor.hash).single;
    final detail = repo.resolveDetail(armor, withPerkColumns: true);

    // The tuning socket is an editable mod column with the +X/-Y options.
    final col = detail.modColumns.single;
    expect(col.plugs.map((p) => p.name),
        containsAll(['+Super / -Health', '+Health / -Super']));
    expect(col.plugs[col.activeIndex!].name, '+Super / -Health');

    // The equipped tuning plug is flagged so the mods row can order it second.
    final equipped = detail
        .plugsOf(PlugCategory.mod)
        .firstWhere((p) => p.name == '+Super / -Health');
    expect(equipped.isTuning, isTrue);

    // Only the boosted stat (Super) is flagged; the reduced stat (Health) and
    // untouched stats are not — the game marks only the boosted side.
    final bySt = {for (final s in detail.stats) s.name: s};
    expect(bySt['Super']!.tuningBoosted, isTrue);
    expect(bySt['Health']!.tuningBoosted, isFalse);
  });

  test('patchSocketPlug applies then reverses a plug + stat change, so an '
      'optimistic insert shows the new plug and a failed one rolls back',
      () async {
    const modWeaponHash = 8001;
    const equippedMod = 8101; // Backup Mag (equipped)
    const altMod = 8102; // Appended Mag (picked)
    const modsCategory = 2685412949;

    const magStatHash = 3871231066;
    const magGroupHash = 8200;
    // The real Chain-of-Command Magazine curve: a step interpolation where
    // investment 0-9 → 30, 10-19 → 35. Magazine is a numeric stat computed from
    // summed investment (the model that fixes the "app 62 vs in-game 66" bug).
    when(() => manifest.getStatGroup(magGroupHash)).thenReturn({
      'scaledStats': [
        {
          'statHash': magStatHash,
          'displayInterpolation': [
            {'value': 0, 'weight': 30},
            {'value': 9, 'weight': 30},
            {'value': 10, 'weight': 35},
            {'value': 19, 'weight': 35},
            {'value': 20, 'weight': 39},
          ],
        }
      ],
    });
    when(() => manifest.getInventoryItem(modWeaponHash)).thenReturn({
      'displayProperties': {'name': 'Patch HC', 'icon': '/i/hc.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      // No base magazine investment; the equipped mod supplies it all.
      'stats': {
        'statGroupHash': magGroupHash,
        'stats': {
          '$magStatHash': {'statHash': magStatHash},
        }
      },
      'sockets': {
        'socketCategories': [
          {
            'socketCategoryHash': modsCategory,
            'socketIndexes': [1],
          }
        ],
        'socketEntries': [
          {'singleInitialItemHash': 0},
          {'singleInitialItemHash': equippedMod},
        ],
      },
    });
    // Backup Mag +5 investment → total 5 → interp 30. Appended Mag +12 → total
    // 12 → interp 35 (the step curve, not a linear +7).
    when(() => manifest.getInventoryItem(equippedMod)).thenReturn({
      'displayProperties': {'name': 'Backup Mag', 'icon': '/i/bm.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
      'investmentStats': [
        {'statTypeHash': magStatHash, 'value': 5},
      ],
    });
    when(() => manifest.getInventoryItem(altMod)).thenReturn({
      'displayProperties': {'name': 'Appended Mag', 'icon': '/i/am.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.plugs.weapons.mods'},
      'investmentStats': [
        {'statTypeHash': magStatHash, 'value': 12},
      ],
    });
    when(() => manifest.getStat(magStatHash)).thenReturn({
      'displayProperties': {'name': 'Magazine'},
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
                    'itemHash': modWeaponHash,
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
                '888': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'sockets': {
              'data': {
                '888': {
                  'sockets': [
                    {'plugHash': 0, 'isEnabled': true, 'isVisible': true},
                    {
                      'plugHash': equippedMod,
                      'isEnabled': true,
                      'isVisible': true
                    },
                  ]
                }
              }
            },
            'reusablePlugs': {
              'data': {
                '888': {
                  'plugs': {
                    '1': [
                      {'plugItemHash': equippedMod},
                      {'plugItemHash': altMod},
                    ]
                  }
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;

    // Before: Backup Mag equipped → magazine investment 5 → interpolated 30.
    final before = repo.resolveDetail(weapon, withPerkColumns: true);
    final beforeCol = before.modColumns.single;
    expect(beforeCol.plugs[beforeCol.activeIndex!].name, 'Backup Mag');
    expect(before.stats.firstWhere((s) => s.name == 'Magazine').value, 30);

    // Patch the socket to the picked mod (what insertPlug does optimistically);
    // it returns the plug previously in the socket, for rollback.
    final oldHash = repo.patchSocketPlug(weapon, 1, altMod);
    expect(oldHash, equippedMod);

    // After: reopening (a fresh resolveDetail) reflects Appended Mag, without a
    // successful refetch — the fix for the "stale mod on reopen" bug.
    final after = repo.resolveDetail(weapon, withPerkColumns: true);
    final afterCol = after.modColumns.single;
    expect(afterCol.plugs[afterCol.activeIndex!].name, 'Appended Mag');
    // And the equipped-plug list (the Mods chips) now shows the new mod.
    expect(after.plugsOf(PlugCategory.mod).single.name, 'Appended Mag');
    // Investment 12 → interpolated 35 (the step curve, NOT a linear +7).
    expect(after.stats.firstWhere((s) => s.name == 'Magazine').value, 35);

    // Rollback (a failed insert): patching back restores investment 5 → 30.
    repo.patchSocketPlug(weapon, 1, oldHash!);
    final rolledBack = repo.resolveDetail(weapon, withPerkColumns: true);
    final rbCol = rolledBack.modColumns.single;
    expect(rbCol.plugs[rbCol.activeIndex!].name, 'Backup Mag');
    expect(
        rolledBack.stats.firstWhere((s) => s.name == 'Magazine').value, 30);
  });

  test('an inverted stat (Heat Generated) — Zealous Ideal: tooltip shows the '
      'raw -10 (beneficial), the bar applies the interpolated -2', () async {
    const heatWeaponHash = 9001;
    const heatMod = 9101;
    const heatStatHash = 3481294762; // Heat Generated
    const statGroupHash = 9200;

    // Zealous Ideal's real Heat Generated curve. Bungie/DIM convention: a knot's
    // `value` is the investment input, `weight` the displayed output — so the
    // curve DECREASES (investment 0 → shown 32, investment 100 → shown 12): a
    // "lower is better" inverted stat. Base investment 18 → shown 28.4; adding
    // the mod's +10 → investment 28 → shown 26.4, an applied change of -2.
    when(() => manifest.getStatGroup(statGroupHash)).thenReturn({
      'scaledStats': [
        {
          'statHash': heatStatHash,
          'displayInterpolation': [
            {'value': 0, 'weight': 32},
            {'value': 100, 'weight': 12},
          ],
        }
      ],
    });
    when(() => manifest.getStat(heatStatHash)).thenReturn({
      'displayProperties': {'name': 'Heat Generated'},
    });

    when(() => manifest.getInventoryItem(heatWeaponHash)).thenReturn({
      'displayProperties': {'name': 'Heat Gun', 'icon': '/i/hg.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      // Def base Heat investment 60 (curve slope -0.2 → shown 20). With the
      // equipped +10 mod the total is 70 → shown 18 (the in-game value).
      'stats': {
        'statGroupHash': statGroupHash,
        'stats': {
          '$heatStatHash': {'statHash': heatStatHash},
        }
      },
      'investmentStats': [
        {'statTypeHash': heatStatHash, 'value': 60},
      ],
      'sockets': {
        'socketCategories': [
          {'socketCategoryHash': 2685412949, 'socketIndexes': [1]}
        ],
        'socketEntries': [
          {'singleInitialItemHash': 0},
          {'singleInitialItemHash': heatMod},
        ],
      },
    });
    when(() => manifest.getInventoryItem(heatMod)).thenReturn({
      'displayProperties': {'name': 'Enhanced Heat Generated', 'icon': '/i/eh.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.weapon.mod_damage'},
      // Raw investment +10 — but on the inverted curve this reduces the stat.
      'investmentStats': [
        {'statTypeHash': heatStatHash, 'value': 10},
      ],
    });
    // A second mod option so the socket renders a picker column (needs 2+).
    const heatMod2 = 9102;
    when(() => manifest.getInventoryItem(heatMod2)).thenReturn({
      'displayProperties': {'name': 'Empty Mod Socket', 'icon': '/i/em.jpg'},
      'plug': {'plugCategoryIdentifier': 'v400.weapon.mod_empty'},
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
                    'itemHash': heatWeaponHash,
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
                '999': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'sockets': {
              'data': {
                '999': {
                  'sockets': [
                    {'plugHash': 0, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': heatMod, 'isEnabled': true, 'isVisible': true},
                  ]
                }
              }
            },
            'reusablePlugs': {
              'data': {
                '999': {
                  'plugs': {
                    '1': [
                      {'plugItemHash': heatMod},
                      {'plugItemHash': heatMod2},
                    ]
                  }
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon, withPerkColumns: true);

    // The stat value stays the base 18; the mod's *applied* effect is -2
    // (interpolated: interp(28) - interp(18) ≈ 26 - 28), captured as a
    // reduction — NOT the raw +10 (which would wrongly read as a big gain).
    final heat = detail.stats.firstWhere((s) => s.name == 'Heat Generated');
    expect(heat.value, 18);
    expect(heat.modBonus, 0);
    expect(heat.masterworkBonus, 0);
    expect(heat.reduction, 2); // applied -2
    // Inverted "lower is better": the numeric badge is net -2 and beneficial
    // (so it renders gold), because the heat dropped.
    expect(heat.inverted, isTrue);
    expect(heat.netEffect, -2);
    expect(heat.netBeneficial, isTrue);

    // The mod-picker option's tooltip carries BOTH the raw investment the game
    // advertises (-10, sign-flipped for the inverted stat) and the actual
    // applied change (-2), flagged beneficial so the UI colours it gold.
    final option = detail.modColumns.single.plugs
        .firstWhere((p) => p.name == 'Enhanced Heat Generated');
    final effect = option.statEffects.single;
    expect(effect.name, 'Heat Generated');
    expect(effect.value, -10); // raw
    expect(effect.applied, -2); // interpolated actual change
    expect(effect.beneficial, isTrue);

    // The OPTIMISTIC patch must use the applied (interpolated) delta, not the
    // raw investment. Removing the heat mod (swap to the empty option) drops its
    // -2 effect, so Heat rises 18 → 20 — NOT the raw +10 that would show 8/28.
    repo.patchSocketPlug(weapon, 1, heatMod2);
    final removed = repo.resolveDetail(weapon, withPerkColumns: true);
    expect(removed.stats.firstWhere((s) => s.name == 'Heat Generated').value,
        20);
    // Re-applying the heat mod brings it back to 18.
    repo.patchSocketPlug(weapon, 1, heatMod);
    final reapplied = repo.resolveDetail(weapon, withPerkColumns: true);
    expect(
        reapplied.stats.firstWhere((s) => s.name == 'Heat Generated').value,
        18);
  });

  test('a fully masterworked tiered weapon (gearTier 5): +tier lifts the '
      'stats its masterwork marks (Range/Magazine), a frame conditional bonus '
      'is live, unmarked Impact is not lifted', () async {
    const tierWeaponHash = 10001;
    const framePlug = 10101; // intrinsic frame (Rufus-style conditional bonus)
    const mwPlug = 10102; // full masterwork with tier marker entries
    const rangeStat = 1240592695; // marked, 1:1
    const magStat = 3871231066; // marked, step curve
    const impactStat = 4043523819; // unmarked → NOT tier-boosted
    const statGroupHash = 10200;

    // Real-shaped magazine step curve; Impact has a shallow curve; Range 1:1
    // (listed in scaledStats — the shown set — but with no interpolation).
    when(() => manifest.getStatGroup(statGroupHash)).thenReturn({
      'scaledStats': [
        {'statHash': rangeStat},
        {
          'statHash': magStat,
          'displayInterpolation': [
            {'value': 0, 'weight': 30},
            {'value': 9, 'weight': 30},
            {'value': 10, 'weight': 35},
            {'value': 19, 'weight': 35},
            {'value': 20, 'weight': 39},
          ],
        },
        {
          'statHash': impactStat,
          'displayInterpolation': [
            {'value': 0, 'weight': 25},
            {'value': 100, 'weight': 65},
          ],
        },
      ],
    });
    when(() => manifest.getStat(rangeStat)).thenReturn({
      'displayProperties': {'name': 'Range'},
    });
    when(() => manifest.getStat(magStat)).thenReturn({
      'displayProperties': {'name': 'Magazine'},
    });
    when(() => manifest.getStat(impactStat)).thenReturn({
      'displayProperties': {'name': 'Impact'},
    });

    when(() => manifest.getInventoryItem(tierWeaponHash)).thenReturn({
      'displayProperties': {'name': 'Tier Gun', 'icon': '/i/tg.jpg'},
      'itemType': 3,
      'itemSubType': 6,
      'itemTypeDisplayName': 'Auto Rifle',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'stats': {
        'statGroupHash': statGroupHash,
        'stats': {
          '$rangeStat': {'statHash': rangeStat},
          '$magStat': {'statHash': magStat},
          '$impactStat': {'statHash': impactStat},
        }
      },
      // Base investment: Range 40, Magazine 5, Impact 100 (→ interp 65).
      'investmentStats': [
        {'statTypeHash': rangeStat, 'value': 40},
        {'statTypeHash': magStat, 'value': 5},
        {'statTypeHash': impactStat, 'value': 100},
      ],
    });
    // The intrinsic frame: an unconditional Range +6 plus a *conditional* Range
    // +2 that is live in-game (frame conditional bonuses are counted).
    when(() => manifest.getInventoryItem(framePlug)).thenReturn({
      'displayProperties': {'name': 'Rapid-Fire Frame', 'icon': '/i/fr.jpg'},
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
      'investmentStats': [
        {'statTypeHash': rangeStat, 'value': 6, 'isConditionallyActive': false},
        {'statTypeHash': rangeStat, 'value': 2, 'isConditionallyActive': true},
      ],
    });
    // The full masterwork: conditionally-active value-0 marker entries name the
    // stats the +gearTier bonus lifts (Range + Magazine here; Impact is
    // unmarked). A tiered masterwork carries `uiPlugLabel: 'masterwork'`.
    when(() => manifest.getInventoryItem(mwPlug)).thenReturn({
      'displayProperties': {'name': 'Masterworked: Range', 'icon': '/i/mw.jpg'},
      'plug': {
        'plugCategoryIdentifier': 'v400.plugs.weapons.masterworks.stat.range',
        'uiPlugLabel': 'masterwork',
      },
      'investmentStats': [
        {'statTypeHash': rangeStat, 'value': 0, 'isConditionallyActive': true},
        {'statTypeHash': magStat, 'value': 0, 'isConditionallyActive': true},
      ],
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
                    'itemHash': tierWeaponHash,
                    'itemInstanceId': '1000',
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
            // gearTier 5 on the instance component drives the +tier bonus.
            'instances': {
              'data': {
                '1000': {
                  'damageType': 1,
                  'primaryStat': {'value': 540},
                  'gearTier': 5,
                }
              }
            },
            'sockets': {
              'data': {
                '1000': {
                  'sockets': [
                    {'plugHash': framePlug, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': mwPlug, 'isEnabled': true, 'isVisible': true},
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
    expect(weapon.gearTier, 5);
    final detail = repo.resolveDetail(weapon);

    // Range (1:1, masterwork-marked): base 40 + frame 6 + frame-conditional 2 +
    // tier 5 = 53.
    expect(detail.stats.firstWhere((s) => s.name == 'Range').value, 53);
    // Magazine (masterwork-marked, step curve): investment 5 + tier 5 = 10 →
    // interp 35 (was 30 at 5). The tier crosses a curve step.
    expect(detail.stats.firstWhere((s) => s.name == 'Magazine').value, 35);
    // Impact is unmarked → NOT tier-boosted: investment 100 → interp 65.
    expect(detail.stats.firstWhere((s) => s.name == 'Impact').value, 65);
  });

  test('a crafted tiered weapon: the enhanced-intrinsic frame drives the tier '
      'lift — its conditional archetype stats resolve to exactly gearTier, its '
      'unconditional stat to value + gearTier', () async {
    // Models The Other Half (crafted tier-4 sword): the "Enhanced Intrinsic"
    // frame lifts Charge Rate to gearTier and Impact by value + gearTier.
    const craftedHash = 11001;
    const framePlug = 11101; // enhanced-intrinsic frame
    const guardPlug = 11102; // a normal perk plug (no tier treatment)
    const bladePlug = 11103; // a normal barrel/blade plug (no tier treatment)
    const impactStat = 4043523819; // frame *unconditional* → value + tier
    const chargeStat = 3022301683; // frame *conditional* → exactly tier
    const statGroupHash = 11200;

    // Impact bars on a {0→40, 100→80} curve (as swords do); Charge Rate is 1:1.
    when(() => manifest.getStatGroup(statGroupHash)).thenReturn({
      'scaledStats': [
        {
          'statHash': impactStat,
          'displayInterpolation': [
            {'value': 0, 'weight': 40},
            {'value': 100, 'weight': 80},
          ],
        },
        {'statHash': chargeStat},
      ],
    });
    when(() => manifest.getStat(impactStat)).thenReturn({
      'displayProperties': {'name': 'Impact'},
    });
    when(() => manifest.getStat(chargeStat)).thenReturn({
      'displayProperties': {'name': 'Charge Rate'},
    });

    when(() => manifest.getInventoryItem(craftedHash)).thenReturn({
      'displayProperties': {'name': 'Crafted Sword', 'icon': '/i/cs.jpg'},
      'itemType': 3,
      'itemSubType': 6,
      'itemTypeDisplayName': 'Sword',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'stats': {
        'statGroupHash': statGroupHash,
        'stats': {
          '$impactStat': {'statHash': impactStat},
          '$chargeStat': {'statHash': chargeStat},
        }
      },
      // Base: Impact 50, Charge Rate 20.
      'investmentStats': [
        {'statTypeHash': impactStat, 'value': 50},
        {'statTypeHash': chargeStat, 'value': 20},
      ],
    });
    // Enhanced-intrinsic frame: unconditional Impact +10, conditional Charge +2
    // (the raw +2 is ignored — a frame conditional resolves to exactly tier).
    when(() => manifest.getInventoryItem(framePlug)).thenReturn({
      'displayProperties': {'name': 'Adaptive Frame', 'icon': '/i/af.jpg'},
      'itemTypeDisplayName': 'Enhanced Intrinsic',
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
      'investmentStats': [
        {'statTypeHash': impactStat, 'value': 10, 'isConditionallyActive': false},
        {'statTypeHash': chargeStat, 'value': 2, 'isConditionallyActive': true},
      ],
    });
    // A normal guard perk: unconditional Charge Rate +10, untouched by tier.
    when(() => manifest.getInventoryItem(guardPlug)).thenReturn({
      'displayProperties': {'name': "Swordmaster's Guard", 'icon': '/i/g.jpg'},
      'plug': {'plugCategoryIdentifier': 'guards'},
      'investmentStats': [
        {'statTypeHash': chargeStat, 'value': 10, 'isConditionallyActive': false},
      ],
    });
    // A normal blade perk: unconditional Impact +10, untouched by tier.
    when(() => manifest.getInventoryItem(bladePlug)).thenReturn({
      'displayProperties': {'name': 'Jagged Edge', 'icon': '/i/b.jpg'},
      'plug': {'plugCategoryIdentifier': 'blades'},
      'investmentStats': [
        {'statTypeHash': impactStat, 'value': 10, 'isConditionallyActive': false},
      ],
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
                    'itemHash': craftedHash,
                    'itemInstanceId': '2000',
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
                '2000': {
                  'damageType': 1,
                  'primaryStat': {'value': 540},
                  'gearTier': 4,
                }
              }
            },
            'sockets': {
              'data': {
                '2000': {
                  'sockets': [
                    {'plugHash': framePlug, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': guardPlug, 'isEnabled': true, 'isVisible': true},
                    {'plugHash': bladePlug, 'isEnabled': true, 'isVisible': true},
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
    expect(weapon.gearTier, 4);
    final detail = repo.resolveDetail(weapon);

    // Charge Rate (1:1): base 20 + guard 10 + frame-conditional → tier 4 = 34.
    expect(detail.stats.firstWhere((s) => s.name == 'Charge Rate').value, 34);
    // Impact: base 50 + blade 10 + frame unconditional (10 + tier 4) = 74 →
    // interp on {0→40, 100→80} = 40 + 0.74·40 = 69.6, rounded to 70.
    expect(detail.stats.firstWhere((s) => s.name == 'Impact').value, 70);
  });

  test('an adept crafted weapon with an Enhancement plug: the frame conditional '
      'keeps its +N and adds tier, and the enhancer stat markers are ignored '
      '(no double tier)', () async {
    // Models Rufus\'s Fury (Adept), gearTier 5: the Enhancement N enhancer lists
    // the same stats the frame lifts, but those are markers — counting them
    // would apply the tier twice.
    const adeptHash = 13001;
    const framePlug = 13101; // enhanced-intrinsic frame
    const enhancerPlug = 13102; // "Enhancement 3" — markers only
    const rangeStat = 1240592695; // frame *conditional* → value + tier (adept)
    const handlingStat = 943549884; // frame *unconditional* → value + tier

    when(() => manifest.getStat(rangeStat)).thenReturn({
      'displayProperties': {'name': 'Range'},
    });
    when(() => manifest.getStat(handlingStat)).thenReturn({
      'displayProperties': {'name': 'Handling'},
    });

    // No stat group → 1:1 stats. isAdept flags the adept branch.
    when(() => manifest.getInventoryItem(adeptHash)).thenReturn({
      'displayProperties': {'name': 'Adept Gun', 'icon': '/i/ag.jpg'},
      'itemType': 3,
      'itemSubType': 6,
      'itemTypeDisplayName': 'Auto Rifle',
      'isAdept': true,
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'stats': {
        'stats': {
          '$rangeStat': {'statHash': rangeStat},
          '$handlingStat': {'statHash': handlingStat},
        }
      },
      'investmentStats': [
        {'statTypeHash': rangeStat, 'value': 34},
        {'statTypeHash': handlingStat, 'value': 41},
      ],
    });
    // Enhanced-intrinsic frame: unconditional Handling +10, conditional Range +2.
    when(() => manifest.getInventoryItem(framePlug)).thenReturn({
      'displayProperties': {'name': 'Rapid-Fire Frame', 'icon': '/i/fr.jpg'},
      'itemTypeDisplayName': 'Enhanced Intrinsic',
      'plug': {'plugCategoryIdentifier': 'intrinsics'},
      'investmentStats': [
        {
          'statTypeHash': handlingStat,
          'value': 10,
          'isConditionallyActive': false
        },
        {'statTypeHash': rangeStat, 'value': 2, 'isConditionallyActive': true},
      ],
    });
    // The Enhancement plug lists Range +10 / Handling +10 conditionally — pure
    // markers that must contribute nothing.
    when(() => manifest.getInventoryItem(enhancerPlug)).thenReturn({
      'displayProperties': {'name': 'Enhancement 3', 'icon': '/i/en.jpg'},
      'plug': {
        'plugCategoryIdentifier': 'crafting.plugs.weapons.mods.enhancers'
      },
      'investmentStats': [
        {'statTypeHash': rangeStat, 'value': 10, 'isConditionallyActive': true},
        {
          'statTypeHash': handlingStat,
          'value': 10,
          'isConditionallyActive': true
        },
      ],
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
                    'itemHash': adeptHash,
                    'itemInstanceId': '3000',
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
                '3000': {
                  'damageType': 1,
                  'primaryStat': {'value': 540},
                  'gearTier': 5,
                }
              }
            },
            'sockets': {
              'data': {
                '3000': {
                  'sockets': [
                    {'plugHash': framePlug, 'isEnabled': true, 'isVisible': true},
                    {
                      'plugHash': enhancerPlug,
                      'isEnabled': true,
                      'isVisible': true
                    },
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
    expect(weapon.gearTier, 5);
    final detail = repo.resolveDetail(weapon);

    // Range (adept frame conditional keeps +2, plus tier 5): 34 + 2 + 5 = 41.
    // The enhancer's Range +10 marker is ignored.
    expect(detail.stats.firstWhere((s) => s.name == 'Range').value, 41);
    // Handling (frame unconditional): 41 + (10 + tier 5) = 56. The enhancer's
    // Handling +10 marker is ignored.
    expect(detail.stats.firstWhere((s) => s.name == 'Handling').value, 56);
  });

  test('a sword shows only its stat-group scaledStats (hidden declared stats '
      'like Zoom/Range dropped), with bars except Ammo Capacity', () async {
    const swordHash = 12001;
    const swingSpeed = 2837207746;
    const chargeRate = 3022301683;
    const guardResistance = 209426660;
    const guardEndurance = 3736848092;
    const ammoCapacity = 925767036;
    const impactStat = 4043523819;
    const zoomStat = 3555269338; // declared but NOT in scaledStats → hidden
    const rangeStat = 1240592695; // declared but NOT in scaledStats → hidden
    const statGroupHash = 12200;

    for (final e in {
      swingSpeed: 'Swing Speed',
      chargeRate: 'Charge Rate',
      guardResistance: 'Guard Resistance',
      guardEndurance: 'Guard Endurance',
      ammoCapacity: 'Ammo Capacity',
      impactStat: 'Impact',
      zoomStat: 'Zoom',
      rangeStat: 'Range',
    }.entries) {
      when(() => manifest.getStat(e.key))
          .thenReturn({'displayProperties': {'name': e.value}});
    }

    // scaledStats = exactly the in-game sword list (order + membership).
    when(() => manifest.getStatGroup(statGroupHash)).thenReturn({
      'scaledStats': [
        {'statHash': impactStat},
        {'statHash': swingSpeed},
        {'statHash': chargeRate},
        {'statHash': guardResistance},
        {'statHash': guardEndurance},
        {'statHash': ammoCapacity},
      ],
    });

    when(() => manifest.getInventoryItem(swordHash)).thenReturn({
      'displayProperties': {'name': 'Test Sword', 'icon': '/i/sw.jpg'},
      'itemType': 3,
      'itemSubType': 18, // sword
      'itemTypeDisplayName': 'Sword',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
      'stats': {
        'statGroupHash': statGroupHash,
        // Declared superset includes hidden Zoom + Range the game omits.
        'stats': {
          '$impactStat': {'statHash': impactStat},
          '$swingSpeed': {'statHash': swingSpeed},
          '$chargeRate': {'statHash': chargeRate},
          '$guardResistance': {'statHash': guardResistance},
          '$guardEndurance': {'statHash': guardEndurance},
          '$ammoCapacity': {'statHash': ammoCapacity},
          '$zoomStat': {'statHash': zoomStat},
          '$rangeStat': {'statHash': rangeStat},
        }
      },
      'investmentStats': [
        {'statTypeHash': impactStat, 'value': 70},
        {'statTypeHash': swingSpeed, 'value': 44},
        {'statTypeHash': chargeRate, 'value': 34},
        {'statTypeHash': guardResistance, 'value': 19},
        {'statTypeHash': guardEndurance, 'value': 40},
        {'statTypeHash': ammoCapacity, 'value': 70},
        {'statTypeHash': zoomStat, 'value': 15},
        {'statTypeHash': rangeStat, 'value': 50},
      ],
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
                    'itemHash': swordHash,
                    'itemInstanceId': '3000',
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
                '3000': {'damageType': 1, 'primaryStat': {'value': 540}}
              }
            },
            'sockets': {'data': {}},
          },
        });

    final grid = await repo.fetchInventory();
    final weapon = grid.owners.first
        .itemsFor(EquipmentBucket.kineticWeapons.hash)
        .single;
    final detail = repo.resolveDetail(weapon);
    final names = detail.stats.map((s) => s.name).toList();

    // Only the scaledStats, in in-game order — Zoom and Range are dropped.
    expect(names, [
      'Impact', 'Swing Speed', 'Charge Rate', 'Guard Resistance',
      'Guard Endurance', 'Ammo Capacity',
    ]);
    // All are bars except Ammo Capacity (numeric).
    for (final s in detail.stats) {
      final expected = s.name == 'Ammo Capacity'
          ? StatDisplay.numeric
          : StatDisplay.bar;
      expect(s.display, expected, reason: '${s.name} display');
    }
  });
}
