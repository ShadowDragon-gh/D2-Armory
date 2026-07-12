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

    // Stats: the masterwork's +10 Range is the gold segment and the mod's +5
    // Range is the blue segment (split by source); its conditionally active
    // entry is not counted, and the perk's +7 Range folds into the base bar.
    // Reductions from the mod (-12) and the perk drawback (-4) combine into the
    // red deficit segment.
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

  test('patchSocketPlug applies then reverses a plug + stat change, so an '
      'optimistic insert shows the new plug and a failed one rolls back',
      () async {
    const modWeaponHash = 8001;
    const equippedMod = 8101; // Backup Mag (equipped)
    const altMod = 8102; // Appended Mag (picked)
    const modsCategory = 2685412949;

    when(() => manifest.getInventoryItem(modWeaponHash)).thenReturn({
      'displayProperties': {'name': 'Patch HC', 'icon': '/i/hc.jpg'},
      'itemType': 3,
      'itemSubType': 9,
      'itemTypeDisplayName': 'Hand Cannon',
      'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
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
    // The two mods add different magazine stats, so switching between them must
    // shift the cached base stat value by the delta (+5 → +12 = +7).
    const magStatHash = 3871231066;
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
            // Bungie's stored value bakes in the equipped Backup Mag (+5).
            'stats': {
              'data': {
                '888': {
                  'stats': {
                    '$magStatHash': {'statHash': magStatHash, 'value': 30}
                  }
                }
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

    // Before: the equipped mod is Backup Mag, magazine reads Bungie's 30.
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
    // The stat bar reconciles by the +5 → +12 delta: 30 + 7 = 37.
    expect(after.stats.firstWhere((s) => s.name == 'Magazine').value, 37);

    // Rollback (a failed insert): patching back to the old plug restores the
    // socket and reverses the stat delta — 37 - 7 = 30.
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
      'stats': {'statGroupHash': statGroupHash},
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
            // Base Heat Generated investment = 18 (as shown on Zealous Ideal).
            'stats': {
              'data': {
                '999': {
                  'stats': {
                    '$heatStatHash': {'statHash': heatStatHash, 'value': 18}
                  }
                }
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
}
