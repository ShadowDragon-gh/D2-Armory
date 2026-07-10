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
        // Conditionally active bonuses are not counted.
        {
          'statTypeHash': rangeStatHash,
          'value': 3,
          'isConditionallyActive': true
        },
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
            'stats': {
              'data': {
                '999': {
                  'stats': {
                    '$rangeStatHash': {
                      'statHash': rangeStatHash,
                      'value': 73
                    },
                    '$handlingStatHash': {
                      'statHash': handlingStatHash,
                      'value': 30
                    },
                    // Negative values occur (armor tuning) and must not
                    // invert the bonus clamp range.
                    '4043523819': {'statHash': 4043523819, 'value': -5}
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

    // Stats: the masterwork's +10 Range shows as the gold bonus segment; its
    // conditionally active entry is not counted, and the perk's +7 Range
    // folds into the base bar. Reductions from the mod (-12) and the perk
    // drawback (-4) combine into the red deficit segment.
    final range = detail.stats.firstWhere((s) => s.name == 'Range');
    expect(range.value, 73);
    expect(range.bonus, 10);
    expect(range.reduction, 0);
    final handling = detail.stats.firstWhere((s) => s.name == 'Handling');
    expect(handling.value, 30);
    expect(handling.bonus, 0);
    expect(handling.reduction, 16);
    // A negative stat value resolves without throwing, with no gold segment.
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
}
