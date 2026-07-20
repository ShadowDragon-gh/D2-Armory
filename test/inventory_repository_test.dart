import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/search/item_filter.dart';
import 'package:d2_armory/data/remote/bungie_api.dart';
import 'package:d2_armory/data/repositories/inventory_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/inventory_grid.dart';
import 'package:d2_armory/domain/models/subclass_detail.dart';

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
    // No armor sets by default (the set-facet reverse index is empty), and no
    // sandbox perks — tests that exercise set facets stub these explicitly.
    when(() => manifest.allEquipableItemSets()).thenReturn(const []);
    when(() => manifest.getSandboxPerk(any())).thenReturn(null);
    // No subclass definitions by default, so nothing is injected into the grid;
    // tests that exercise the not-owned-subclass injection stub this.
    when(() => manifest.querySubclasses()).thenReturn(const []);
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

  test('a subclass item decodes into the subclass bucket on its character',
      () async {
    const subclassHash = 5016;
    when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
      'displayProperties': {'name': 'Gunslinger', 'icon': '/icon/sun.jpg'},
      'itemType': 16,
      'classType': 1,
      'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
    });
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
                    'itemHash': subclassHash,
                    'itemInstanceId': '444',
                    'bucketHash': EquipmentBucket.subclass.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          // A subclass instance carries a primaryStat that is NOT a power
          // level; the tile must not surface it as power.
          'itemComponents': {
            'instances': {
              'data': {
                '444': {'primaryStat': {'value': 10}}
              }
            }
          },
        });

    final grid = await repo.fetchInventory();
    final char = grid.owners.firstWhere((o) => !o.isVault);
    final subclasses = char.itemsFor(EquipmentBucket.subclass.hash);
    expect(subclasses.single.name, 'Gunslinger');
    expect(subclasses.single.itemType, 16);
    // Subclasses have no power — its instance primaryStat must not leak through.
    expect(subclasses.single.power, isNull);
    // With no equipped super plug in the sockets, the tile falls back to the
    // subclass definition icon.
    expect(subclasses.single.iconPath, '/icon/sun.jpg');
  });

  group('not-owned subclass injection', () {
    // The character (Hunter, classType 1) owns Gunslinger; the manifest also
    // has an unowned Hunter subclass (Nightstalker), an older Gunslinger
    // generation (same name → suppressed), and a Titan subclass (wrong class).
    const ownedHash = 5016; // Gunslinger (owned, equipped instance)
    const oldGunslingerHash = 5017; // older Gunslinger generation
    const nightstalkerHash = 5018; // unowned Hunter subclass
    const titanHash = 5019; // wrong class

    setUp(() {
      when(() => manifest.getInventoryItem(ownedHash)).thenReturn({
        'displayProperties': {'name': 'Gunslinger', 'icon': '/i/gs.jpg'},
        'itemType': 16,
        'classType': 1,
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
      });
      when(() => manifest.querySubclasses()).thenReturn([
        {'hash': ownedHash, 'name': 'Gunslinger', 'icon': '/i/gs.jpg',
          'classType': 1, 'element': 3, 'idx': 5},
        // Older Gunslinger generation, lower index — same name as the owned one.
        {'hash': oldGunslingerHash, 'name': 'Gunslinger', 'icon': '/i/gs0.jpg',
          'classType': 1, 'element': 3, 'idx': 1},
        {'hash': nightstalkerHash, 'name': 'Nightstalker', 'icon': '/i/ns.jpg',
          'classType': 1, 'element': 4, 'idx': 9},
        {'hash': titanHash, 'name': 'Striker', 'icon': '/i/st.jpg',
          'classType': 0, 'element': 2, 'idx': 9},
      ]);
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 1, // Hunter
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
                      'itemHash': ownedHash,
                      'itemInstanceId': '444',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            'itemComponents': {'instances': {'data': {}}},
          });
    });

    test('unowned subclasses for the class are injected as view-only items',
        () async {
      final grid = await repo.fetchInventory();
      final subs = grid.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash);
      final byName = {for (final s in subs) s.name: s};

      // Owned Gunslinger (has an instance) + unowned Nightstalker (no instance).
      expect(byName.keys, containsAll(['Gunslinger', 'Nightstalker']));
      expect(byName['Gunslinger']!.itemInstanceId, '444'); // the owned instance
      expect(byName['Nightstalker']!.itemInstanceId, isNull); // definition-only
      // The wrong-class Titan subclass is never shown for a Hunter.
      expect(byName.containsKey('Striker'), isFalse);
    });

    test('an owned subclass is not duplicated by an older same-named generation',
        () async {
      final grid = await repo.fetchInventory();
      final subs = grid.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash);
      // Only one Gunslinger — the owned instance, not the older def generation.
      final gunslingers = subs.where((s) => s.name == 'Gunslinger').toList();
      expect(gunslingers.length, 1);
      expect(gunslingers.single.itemInstanceId, '444');
    });

    test('a definition-only subclass resolves detail with all options view-only',
        () async {
      // A def-only subclass with one super socket drawing from a plug set. With
      // no instance and no plug-set ownership, every option is view-only.
      const superSetHash = 6600;
      const superA = 6601;
      const superB = 6602;
      when(() => manifest.getInventoryItem(nightstalkerHash)).thenReturn({
        'displayProperties': {'name': 'Nightstalker', 'icon': '/i/ns.jpg'},
        'itemType': 16,
        'classType': 1,
        'talentGrid': {'hudDamageType': 4},
        'screenshot': '/shots/ns.jpg',
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': 457473665, 'socketIndexes': [0]},
          ],
          'socketEntries': [
            {'reusablePlugSetHash': superSetHash},
          ],
        },
      });
      when(() => manifest.getSocketCategory(457473665)).thenReturn({
        'displayProperties': {'name': 'SUPER'}
      });
      when(() => manifest.getPlugSet(superSetHash)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': superA},
          {'plugItemHash': superB},
        ],
      });
      when(() => manifest.getInventoryItem(superA)).thenReturn({
        'displayProperties': {'name': 'Shadowshot: Deadfall', 'icon': '/i/a.png'},
        'plug': {'plugCategoryIdentifier': 'hunter.void.supers'},
        'investmentStats': const [],
      });
      when(() => manifest.getInventoryItem(superB)).thenReturn({
        'displayProperties': {'name': 'Shadowshot: Moebius', 'icon': '/i/b.png'},
        'plug': {'plugCategoryIdentifier': 'hunter.void.supers'},
        'investmentStats': const [],
      });

      final grid = await repo.fetchInventory();
      final nightstalker = grid.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .firstWhere((s) => s.name == 'Nightstalker');
      final detail = repo.resolveSubclassDetail(nightstalker)!;

      final superGroup = detail.groups.firstWhere((g) => g.label == 'SUPER');
      final socket = superGroup.sockets.single;
      // Nothing equipped, and every option is view-only (locked) — the def-only
      // subclass is fully unequippable.
      expect(socket.equipped, isNull);
      for (final option in socket.options) {
        expect(socket.canEquip(option), isFalse);
        expect(socket.optionState(option), SubclassOptionState.locked);
      }
    });
  });

  group('pending equip survives an edge-lagged refetch', () {
    // A Hunter with two subclasses: the STALE one is equipped in the profile,
    // the TARGET one is unequipped. We optimistically equipped the target, so
    // markPendingEquip is set — a refetch that still reports the stale one
    // equipped (Bungie edge lag) must NOT revert the grid.
    const staleHash = 5100;
    const targetHash = 5101;

    void stubSubclass(int hash, String name) {
      when(() => manifest.getInventoryItem(hash)).thenReturn({
        'displayProperties': {'name': name, 'icon': '/i/$hash.jpg'},
        'itemType': 16,
        'classType': 1,
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
      });
    }

    // A profile where [equippedHash]/[equippedInstance] is in characterEquipment
    // and the other subclass is unequipped in characterInventories.
    Map<String, dynamic> profileWithEquipped(
        int equippedHash, String equippedInstance,
        {required int otherHash, required String otherInstance}) {
      return {
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
                  'itemHash': equippedHash,
                  'itemInstanceId': equippedInstance,
                  'bucketHash': EquipmentBucket.subclass.hash,
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
                  'itemHash': otherHash,
                  'itemInstanceId': otherInstance,
                  'bucketHash': EquipmentBucket.subclass.hash,
                  'state': 0,
                }
              ]
            }
          }
        },
        'profileInventory': {'data': {'items': []}},
        'itemComponents': {'instances': {'data': {}}},
      };
    }

    setUp(() {
      stubSubclass(staleHash, 'Revenant'); // stasis (stale)
      stubSubclass(targetHash, 'Arcstrider'); // arc (target)
    });

    test('a refetch still reporting the stale subclass equipped keeps the '
        'optimistically-equipped one', () async {
      // Fetch #1: the profile shows the stale (Revenant) equipped, target
      // (Arcstrider) unequipped.
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => profileWithEquipped(
              staleHash, 'stale-1',
              otherHash: targetHash, otherInstance: 'target-1'));
      final grid1 = await repo.fetchInventory();
      final char1 = grid1.owners.firstWhere((o) => !o.isVault);
      // Sanity: Revenant is equipped from the profile.
      expect(
          char1
              .itemsFor(EquipmentBucket.subclass.hash)
              .firstWhere((i) => i.isEquipped)
              .name,
          'Revenant');

      // The user equips Arcstrider (target-1): record the optimistic equip.
      final target = char1
          .itemsFor(EquipmentBucket.subclass.hash)
          .firstWhere((i) => i.itemInstanceId == 'target-1');
      repo.markPendingEquip(target, 'char1');

      // Fetch #2 (background poll): Bungie's edge cache STILL reports Revenant
      // equipped (the equip has not propagated). The re-apply must show
      // Arcstrider equipped, not revert to Revenant.
      final grid2 = await repo.fetchInventory(reuseDecoded: true);
      final equipped2 = grid2.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .firstWhere((i) => i.isEquipped);
      expect(equipped2.itemInstanceId, 'target-1');
      expect(equipped2.name, 'Arcstrider');
    });

    test('once the profile reports the equip, the pending state is dropped',
        () async {
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => profileWithEquipped(
              staleHash, 'stale-1',
              otherHash: targetHash, otherInstance: 'target-1'));
      final grid1 = await repo.fetchInventory();
      final target = grid1.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .firstWhere((i) => i.itemInstanceId == 'target-1');
      repo.markPendingEquip(target, 'char1');

      // Fetch #2: the profile now correctly reports Arcstrider equipped →
      // the pending equip propagated and is dropped.
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => profileWithEquipped(
              targetHash, 'target-1',
              otherHash: staleHash, otherInstance: 'stale-1'));
      await repo.fetchInventory(reuseDecoded: true);

      // Fetch #3: the user has re-equipped the stale one IN GAME. With the
      // pending equip dropped, the fresh profile wins (no stale re-apply).
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => profileWithEquipped(
              staleHash, 'stale-1',
              otherHash: targetHash, otherInstance: 'target-1'));
      final grid3 = await repo.fetchInventory(reuseDecoded: true);
      final equipped3 = grid3.owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .firstWhere((i) => i.isEquipped);
      expect(equipped3.itemInstanceId, 'stale-1'); // profile wins; not re-applied
    });
  });

  test('a subclass tile shows its equipped super icon, not the base icon',
      () async {
    const subclassHash = 5016;
    const superHash = 7010; // the equipped super plug (.supers)
    when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
      'displayProperties': {'name': 'Gunslinger', 'icon': '/icon/sun.jpg'},
      'itemType': 16,
      'classType': 1,
      'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
    });
    when(() => manifest.getInventoryItem(superHash)).thenReturn({
      'displayProperties': {'name': 'Golden Gun', 'icon': '/icon/gg.jpg'},
      'plug': {'plugCategoryIdentifier': 'hunter.solar.supers'},
    });
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
                    'itemHash': subclassHash,
                    'itemInstanceId': '444',
                    'bucketHash': EquipmentBucket.subclass.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'itemComponents': {
            'instances': {'data': {}},
            'sockets': {
              'data': {
                '444': {
                  'sockets': [
                    {'plugHash': 1, 'isVisible': true}, // some ability
                    {'plugHash': superHash, 'isVisible': true}, // the super
                  ]
                }
              }
            },
          },
        });
    // The non-super socket plug (hash 1) has no super category.
    when(() => manifest.getInventoryItem(1)).thenReturn({
      'displayProperties': {'name': 'Class Ability', 'icon': '/i/1.png'},
      'plug': {'plugCategoryIdentifier': 'hunter.solar.class_abilities'},
    });

    final grid = await repo.fetchInventory();
    final subclass = grid.owners
        .firstWhere((o) => !o.isVault)
        .itemsFor(EquipmentBucket.subclass.hash)
        .single;
    // The tile icon is the equipped super's, not the subclass definition icon.
    expect(subclass.iconPath, '/icon/gg.jpg');
    // A non-Prismatic subclass has no background plate, so no composite — the
    // flat super icon (with its correct element plate) is used as-is.
    expect(subclass.rarityPlatePath, isNull);
    expect(subclass.ornamentForegroundPath, isNull);
  });

  test('a Prismatic subclass composites the super glyph over the prism plate',
      () async {
    const subclassHash = 5020;
    const subIconHash = 3893112950; // its layered icon (has a background plate)
    const superHash = 7020; // the equipped super
    const superIconHash = 7021; // the super's layered icon (transparent glyph)
    when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
      'displayProperties': {
        'name': 'Prismatic Warlock',
        'icon': '/icon/prism.jpg',
        'iconHash': subIconHash,
      },
      'itemType': 16,
      'classType': 2,
      'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
    });
    // The Prismatic subclass's layered icon carries the pink prism plate as its
    // background (only Prismatic defs do).
    when(() => manifest.getIcon(subIconHash)).thenReturn({
      'foreground': '/icon/prism_fg.png',
      'background': '/icon/build_prism_background.png',
    });
    when(() => manifest.getInventoryItem(superHash)).thenReturn({
      'displayProperties': {
        'name': 'Song of Flame',
        'icon': '/icon/solar_super.jpg', // flat icon = wrong (orange) plate
        'iconHash': superIconHash,
      },
      'plug': {'plugCategoryIdentifier': 'warlock.solar.supers'},
    });
    // The super's layered icon: a transparent foreground glyph.
    when(() => manifest.getIcon(superIconHash)).thenReturn({
      'foreground': '/icon/song_of_flame_fg.png',
      'background': '/icon/talent_node_super_solar.png',
    });
    when(() => api.getProfile(
          membershipType: any(named: 'membershipType'),
          membershipId: any(named: 'membershipId'),
          components: any(named: 'components'),
        )).thenAnswer((_) async => {
          'characters': {
            'data': {
              'char1': {
                'characterId': 'char1',
                'classType': 2,
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
                    'itemHash': subclassHash,
                    'itemInstanceId': '445',
                    'bucketHash': EquipmentBucket.subclass.hash,
                    'state': 0,
                  }
                ]
              }
            }
          },
          'characterInventories': {'data': {}},
          'profileInventory': {'data': {'items': []}},
          'itemComponents': {
            'instances': {'data': {}},
            'sockets': {
              'data': {
                '445': {
                  'sockets': [
                    {'plugHash': superHash, 'isVisible': true},
                  ]
                }
              }
            },
          },
        });

    final grid = await repo.fetchInventory();
    final subclass = grid.owners
        .firstWhere((o) => !o.isVault)
        .itemsFor(EquipmentBucket.subclass.hash)
        .single;
    // The prism plate is the composite background; the super's transparent
    // foreground glyph is drawn over it (so the tile reads pink, not orange).
    expect(subclass.rarityPlatePath, '/icon/build_prism_background.png');
    expect(subclass.ornamentForegroundPath, '/icon/song_of_flame_fg.png');
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

  group('resolveSubclassDetail', () {
    const subclassHash = 5016;
    // Socket categories: ABILITIES (0), SUPER (1), FRAGMENTS (2).
    const abilitiesCat = 309722977;
    const superCat = 457473665;
    const fragmentsCat = 1313488945;
    // Plugs.
    const classAbilityHash = 6010; // equipped in socket 0 (unlocked)
    const classAbilityAltHash = 6011; // a 310 (unlocked) option for socket 0
    const classAbilityLockedHash = 6012; // in the def set but NOT in 310
    const abilitySetHash = 7600; // socket 0's definition plug set
    const superHash = 6020; // equipped in socket 1
    const fragmentHash = 6030; // equipped in socket 2 (via def plug set)
    const fragmentSetHash = 7700;
    const discHash = 6040; // Discipline stat
    const fragCostHash = 6050; // "Fragment Cost" — a socket cost, not a stat

    void stubPlug(int hash, String name,
        {String category = 'shared.solar.fragments',
        List<Map<String, dynamic>> investmentStats = const [],
        int? iconHash,
        String? foreground,
        String? background}) {
      when(() => manifest.getInventoryItem(hash)).thenReturn({
        'displayProperties': {
          'name': name,
          'icon': '/p/$hash.png',
          'iconHash': ?iconHash,
        },
        'plug': {'plugCategoryIdentifier': category},
        'investmentStats': investmentStats,
      });
      if (iconHash != null) {
        when(() => manifest.getIcon(iconHash)).thenReturn({
          'foreground': ?foreground,
          'background': ?background,
        });
      }
    }

    setUp(() {
      when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
        'displayProperties': {'name': 'Dawnblade', 'icon': '/sc.png'},
        'itemType': 16,
        'classType': 2,
        'screenshot': '/shots/dawnblade.jpg',
        'talentGrid': {'hudDamageType': 3}, // Solar
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': abilitiesCat, 'socketIndexes': [0]},
            {'socketCategoryHash': superCat, 'socketIndexes': [1]},
            {'socketCategoryHash': fragmentsCat, 'socketIndexes': [2]},
          ],
          'socketEntries': [
            // Socket 0's full pool comes from this def set (owned + unowned).
            {'reusablePlugSetHash': abilitySetHash},
            {'reusablePlugSetHash': 0},
            // Socket 2's pool is this def set.
            {'reusablePlugSetHash': fragmentSetHash},
          ],
        },
      });

      // Socket-category labels.
      when(() => manifest.getSocketCategory(abilitiesCat)).thenReturn({
        'displayProperties': {'name': 'ABILITIES'}
      });
      when(() => manifest.getSocketCategory(superCat)).thenReturn({
        'displayProperties': {'name': 'SUPER'}
      });
      when(() => manifest.getSocketCategory(fragmentsCat)).thenReturn({
        'displayProperties': {'name': 'FRAGMENTS'}
      });

      // The class-ability plug has a transparent glyph but its baked plate is
      // the (wrong) generic one — the resolver should recomposite its glyph
      // over the subclass element plate (from the fragment below).
      stubPlug(classAbilityHash, 'Phoenix Dive',
          category: 'warlock.solar.class_abilities',
          iconHash: 4100,
          foreground: '/fg/phoenix.png',
          background: '/plate/generic_stasis.png');
      stubPlug(classAbilityAltHash, 'Healing Rift',
          category: 'warlock.solar.class_abilities');
      stubPlug(classAbilityLockedHash, 'Icarus Dash',
          category: 'warlock.solar.class_abilities');
      stubPlug(superHash, 'Daybreak', category: 'warlock.solar.supers');

      // Socket 0's definition pool: all three abilities (the full list).
      when(() => manifest.getPlugSet(abilitySetHash)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': classAbilityHash},
          {'plugItemHash': classAbilityAltHash},
          {'plugItemHash': classAbilityLockedHash},
        ],
      });
      // The fragment carries a -10 Discipline investment stat plus a
      // "+1 Fragment Cost" socket-cost stat (which must be filtered out). Its
      // layered icon's background is the correct element plate — the source the
      // class-ability recomposite draws over.
      stubPlug(fragmentHash, 'Ember of Torches',
          category: 'shared.solar.fragments',
          iconHash: 4200,
          foreground: '/fg/torches.png',
          background: '/plate/solar.png',
          investmentStats: [
            {'statTypeHash': discHash, 'value': -10},
            {'statTypeHash': fragCostHash, 'value': 1},
          ]);
      when(() => manifest.getStat(discHash)).thenReturn({
        'displayProperties': {'name': 'Discipline', 'icon': '/stat/disc.png'}
      });
      when(() => manifest.getStat(fragCostHash)).thenReturn({
        'displayProperties': {'name': 'Fragment Cost', 'icon': '/stat/fc.png'}
      });

      // The fragment socket's definition plug set (the 310 fallback).
      when(() => manifest.getPlugSet(fragmentSetHash)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': fragmentHash},
        ],
      });

      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 2,
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
                      'itemHash': subclassHash,
                      'itemInstanceId': '444',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            // Ownership signal: the plug-set component. Socket 0's set (7600)
            // has Phoenix Dive + Healing Rift unlocked (canInsert:true) but NOT
            // Icarus Dash (locked). The equipped plug is canInsert:false (it is
            // socketed) — the resolver treats the equipped plug as equippable
            // regardless.
            'profilePlugSets': {
              'data': {
                'plugs': {
                  '$abilitySetHash': [
                    {'plugItemHash': classAbilityAltHash, 'canInsert': true},
                    {'plugItemHash': classAbilityLockedHash, 'canInsert': false},
                    {'plugItemHash': classAbilityHash, 'canInsert': false},
                  ],
                }
              }
            },
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '444': {
                    'sockets': [
                      {
                        'plugHash': classAbilityHash,
                        'isEnabled': true,
                        'isVisible': true
                      },
                      {
                        'plugHash': superHash,
                        'isEnabled': true,
                        'isVisible': true
                      },
                      {
                        'plugHash': fragmentHash,
                        'isEnabled': true,
                        'isVisible': true
                      },
                    ]
                  }
                }
              },
              // 310 is empty for subclass sockets (as observed live); ownership
              // comes from profilePlugSets above, not here.
              'reusablePlugs': {
                'data': {
                  '444': {'plugs': <String, dynamic>{}}
                }
              },
            },
          });
    });

    DestinyItem theSubclass(grid) =>
        grid.owners.firstWhere((o) => !o.isVault).itemsFor(
            EquipmentBucket.subclass.hash).single;

    test('groups sockets in category order with labels, element and art',
        () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      expect(detail.element, 3); // Solar
      expect(detail.screenshotPath, '/shots/dawnblade.jpg');
      expect(detail.groups.map((g) => g.label).toList(),
          ['ABILITIES', 'SUPER', 'FRAGMENTS']);
    });

    test('a socket lists its full def pool; the plug-set canInsert flags mark '
        'the equippable (owned) subset, unowned options are view-only',
        () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      final abilities = detail.groups.first.sockets.single;
      expect(abilities.equipped?.name, 'Phoenix Dive');
      // The full definition pool shows — including the unowned option.
      expect(abilities.options.map((p) => p.name),
          containsAll(['Phoenix Dive', 'Healing Rift', 'Icarus Dash']));

      // profilePlugSets marks Healing Rift canInsert:true (unlocked); Phoenix
      // Dive is equipped (always equippable). Icarus Dash is in the def pool but
      // canInsert:false and unowned → view-only (locked).
      final byName = {for (final p in abilities.options) p.name: p};
      expect(abilities.canEquip(byName['Phoenix Dive']!), isTrue);
      expect(abilities.canEquip(byName['Healing Rift']!), isTrue);
      expect(abilities.canEquip(byName['Icarus Dash']!), isFalse);
      expect(abilities.optionState(byName['Icarus Dash']!),
          SubclassOptionState.locked);
    });

    test('a socket lists its full def pool from the definition plug set',
        () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      final fragments = detail.groups.last.sockets.single;
      expect(fragments.equipped?.name, 'Ember of Torches');
      expect(fragments.options.map((p) => p.name), contains('Ember of Torches'));
    });

    test('a fragment carries its stat effects (-10 Discipline)', () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      final fragment = detail.groups.last.sockets.single.equipped!;
      final disc =
          fragment.statEffects.firstWhere((e) => e.name == 'Discipline');
      expect(disc.value, -10);
      // "Fragment Cost" is a socket cost, not a gameplay stat — never surfaced.
      expect(fragment.statEffects.any((e) => e.name == 'Fragment Cost'),
          isFalse);
    });

    test('the fragment stat summary nets the equipped fragments\' stat changes '
        'and excludes Fragment Cost', () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      // One equipped fragment: Ember of Torches (-10 Discipline). The "+1
      // Fragment Cost" it also carries is a socket cost, not a stat, so the
      // summary has exactly one entry (Discipline), not two.
      expect(detail.fragmentStatSummary.length, 1);
      final disc = detail.fragmentStatSummary.single;
      expect(disc.name, 'Discipline');
      expect(disc.value, -10);
      expect(disc.beneficial, isFalse);
      expect(disc.iconUrl, contains('/stat/disc.png'));
    });

    test('a class-ability plug recomposites its glyph over the element plate '
        '(not its wrong baked plate)', () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;

      final ability = detail.groups
          .firstWhere((g) => g.label == 'ABILITIES')
          .sockets
          .single
          .equipped!;
      // The plate is the element plate (from the fragment's background), and the
      // foreground is the class-ability's own transparent glyph — so the modal
      // composites green over blue instead of the baked Stasis plate.
      expect(ability.plateUrl, contains('/plate/solar.png'));
      expect(ability.foregroundUrl, contains('/fg/phoenix.png'));
    });

    test('the SUPER group is flagged isSuper (diamond in the modal)', () async {
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;
      final superGroup = detail.groups.firstWhere((g) => g.label == 'SUPER');
      expect(superGroup.isSuper, isTrue);
      // The other groups are not supers.
      expect(detail.groups.where((g) => g.isSuper).length, 1);
    });

    test('a non-Prismatic super is not recomposited (no def background plate)',
        () async {
      // The base Dawnblade def has no background layer, so the super keeps its
      // flat element icon (no prism composite).
      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;
      final superPlug = detail.groups
          .firstWhere((g) => g.label == 'SUPER')
          .sockets
          .single
          .equipped!;
      expect(superPlug.plateUrl, isNull);
      expect(superPlug.foregroundUrl, isNull);
    });

    test('a Prismatic super composites its glyph over the prism plate',
        () async {
      // Re-stub the subclass def with a background (the pink prism plate) and
      // the super plug with a transparent foreground glyph — the Prismatic case.
      when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
        'displayProperties': {
          'name': 'Dawnblade',
          'icon': '/sc.png',
          'iconHash': 9001,
        },
        'itemType': 16,
        'classType': 2,
        'talentGrid': {'hudDamageType': 3},
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': abilitiesCat, 'socketIndexes': [0]},
            {'socketCategoryHash': superCat, 'socketIndexes': [1]},
            {'socketCategoryHash': fragmentsCat, 'socketIndexes': [2]},
          ],
          'socketEntries': [
            {'reusablePlugSetHash': abilitySetHash},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': fragmentSetHash},
          ],
        },
      });
      when(() => manifest.getIcon(9001)).thenReturn({
        'background': '/plate/prism.png',
      });
      stubPlug(superHash, 'Daybreak',
          category: 'warlock.solar.supers',
          iconHash: 9002,
          foreground: '/fg/daybreak.png',
          background: '/plate/solar_super.png');

      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;
      final superPlug = detail.groups
          .firstWhere((g) => g.label == 'SUPER')
          .sockets
          .single
          .equipped!;
      // Composited over the PRISM plate (def background), not the super's own
      // solar plate.
      expect(superPlug.plateUrl, contains('/plate/prism.png'));
      expect(superPlug.foregroundUrl, contains('/fg/daybreak.png'));
    });

    test('an aspect keeps its sandbox-perk description despite a stat effect',
        () async {
      // Aspects (e.g. Soul Siphon) carry BOTH a stat effect (+3 Aspect Energy
      // Capacity) and real prose in a sandbox perk — no direct description on
      // the plug. The stat-effect suppression that stops a mod from restating
      // "+10 Stability" must NOT hide the aspect's prose.
      const perkHash = 6099;
      when(() => manifest.getInventoryItem(superHash)).thenReturn({
        // No displayProperties.description — prose lives in the sandbox perk.
        'displayProperties': {'name': 'Soul Siphon', 'icon': '/p/6020.png'},
        'plug': {'plugCategoryIdentifier': 'warlock.void.aspects'},
        'investmentStats': [
          {'statTypeHash': discHash, 'value': 3},
        ],
        'perks': [
          {'perkHash': perkHash},
        ],
      });
      when(() => manifest.getSandboxPerk(perkHash)).thenReturn({
        'isDisplayable': true,
        'displayProperties': {
          'description': 'Defeating targets with abilities creates Void Breaches.'
        },
      });

      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;
      final aspect = detail.groups
          .firstWhere((g) => g.label == 'SUPER')
          .sockets
          .single
          .equipped!;
      expect(aspect.description,
          'Defeating targets with abilities creates Void Breaches.');
      // The stat effect is still present alongside the prose.
      expect(aspect.statEffects, isNotEmpty);
    });

    test('an invisible socket is skipped', () async {
      // Make socket 1 (SUPER) invisible; its group should vanish.
      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 2,
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
                      'itemHash': subclassHash,
                      'itemInstanceId': '444',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '444': {
                    'sockets': [
                      {'plugHash': classAbilityHash, 'isVisible': true},
                      {'plugHash': superHash, 'isVisible': false},
                      {'plugHash': fragmentHash, 'isVisible': true},
                    ]
                  }
                }
              },
              'reusablePlugs': {'data': {}},
            },
          });

      final subclass = theSubclass(await repo.fetchInventory());
      final detail = repo.resolveSubclassDetail(subclass)!;
      // SUPER's only socket was invisible, so that group is gone.
      expect(detail.groups.map((g) => g.label), isNot(contains('SUPER')));
      expect(detail.groups.map((g) => g.label), contains('ABILITIES'));
    });
  });

  group('resolveSubclassDetail — fragment slot capacity', () {
    const subclassHash = 5017;
    const aspectsCat = 2140934067;
    const fragmentsCat = 1313488945;
    const aspectHash = 8000; // grants +2 Aspect Energy Capacity
    const emptyAspectHash = 8001; // an empty aspect socket (grants nothing)
    const capacityStat = 8100; // "Aspect Energy Capacity"
    const fragA = 8200; // a real, socketed fragment
    const emptyFragHash = 8300; // "Empty Fragment Socket" placeholder

    setUp(() {
      when(() => manifest.getInventoryItem(subclassHash)).thenReturn({
        'displayProperties': {'name': 'Voidwalker', 'icon': '/sc.png'},
        'itemType': 16,
        'classType': 2,
        'screenshot': '/shots/void.jpg',
        'talentGrid': {'hudDamageType': 4}, // Void
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': aspectsCat, 'socketIndexes': [0, 1]},
            // Four fragment sockets (indexes 2..5).
            {'socketCategoryHash': fragmentsCat, 'socketIndexes': [2, 3, 4, 5]},
          ],
          'socketEntries': [
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
          ],
        },
      });
      when(() => manifest.getSocketCategory(aspectsCat)).thenReturn({
        'displayProperties': {'name': 'ASPECTS'}
      });
      when(() => manifest.getSocketCategory(fragmentsCat)).thenReturn({
        'displayProperties': {'name': 'FRAGMENTS'}
      });

      // Aspect granting +2 fragment slots (the "Aspect Energy Capacity" stat).
      when(() => manifest.getInventoryItem(aspectHash)).thenReturn({
        'displayProperties': {'name': 'Chaos Accelerant', 'icon': '/a.png'},
        'plug': {'plugCategoryIdentifier': 'warlock.void.aspects'},
        'investmentStats': [
          {'statTypeHash': capacityStat, 'value': 2},
        ],
      });
      when(() => manifest.getInventoryItem(emptyAspectHash)).thenReturn({
        'displayProperties': {'name': 'Empty Aspect Socket', 'icon': '/ea.png'},
        'plug': {'plugCategoryIdentifier': 'warlock.void.aspects'},
        'investmentStats': const [],
      });
      when(() => manifest.getStat(capacityStat)).thenReturn({
        'displayProperties': {'name': 'Aspect Energy Capacity'}
      });
      when(() => manifest.getInventoryItem(fragA)).thenReturn({
        'displayProperties': {'name': 'Echo of Persistence', 'icon': '/f.png'},
        'plug': {'plugCategoryIdentifier': 'shared.void.fragments'},
        'investmentStats': const [],
      });
      when(() => manifest.getInventoryItem(emptyFragHash)).thenReturn({
        'displayProperties': {
          'name': 'Empty Fragment Socket',
          'icon': '/ef.png'
        },
        'plug': {'plugCategoryIdentifier': 'shared.void.fragments'},
        'investmentStats': const [],
      });

      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 2,
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
                      'itemHash': subclassHash,
                      'itemInstanceId': '555',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '555': {
                    'sockets': [
                      // One aspect equipped (+2), one empty aspect socket.
                      {'plugHash': aspectHash, 'isVisible': true},
                      {'plugHash': emptyAspectHash, 'isVisible': true},
                      // Fragment sockets: one filled, three empty.
                      {'plugHash': fragA, 'isVisible': true},
                      {'plugHash': emptyFragHash, 'isVisible': true},
                      {'plugHash': emptyFragHash, 'isVisible': true},
                      {'plugHash': emptyFragHash, 'isVisible': true},
                    ]
                  }
                }
              },
              'reusablePlugs': {'data': {}},
            },
          });
    });

    test('empty fragment sockets beyond the aspects\' granted capacity are '
        'disabled', () async {
      final subclass = (await repo.fetchInventory())
          .owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .single;
      final detail = repo.resolveSubclassDetail(subclass)!;
      final fragments =
          detail.groups.firstWhere((g) => g.label == 'FRAGMENTS').sockets;

      // Capacity is 2 (one aspect grants +2). Sockets in order: filled (always
      // available, uses slot 1), empty (available, uses slot 2), empty (over
      // capacity → disabled), empty (disabled).
      expect(fragments.map((s) => s.available).toList(),
          [true, true, false, false]);
    });

    test('a second aspect raises the capacity and re-enables slots', () async {
      // Swap the empty aspect socket for a second capacity-granting aspect so
      // total capacity is 4 — all four fragment sockets become available.
      when(() => manifest.getInventoryItem(emptyAspectHash)).thenReturn({
        'displayProperties': {'name': 'Feed the Void', 'icon': '/a2.png'},
        'plug': {'plugCategoryIdentifier': 'warlock.void.aspects'},
        'investmentStats': [
          {'statTypeHash': capacityStat, 'value': 2},
        ],
      });

      final subclass = (await repo.fetchInventory())
          .owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .single;
      final detail = repo.resolveSubclassDetail(subclass)!;
      final fragments =
          detail.groups.firstWhere((g) => g.label == 'FRAGMENTS').sockets;

      expect(fragments.every((s) => s.available), isTrue);
    });

    test('Stasis capacity is constrained via .totems/.trinkets plug categories',
        () async {
      // Stasis pre-dates the 3.0 naming: aspects are `.totems`, fragments are
      // `.trinkets`, and its socket-category hashes differ from the Light
      // subclasses. The constraint must still apply — identified by plug
      // category, not socket-category hash. Uses arbitrary (unstubbed) socket
      // hashes to prove the hash is irrelevant.
      const stasisSub = 5018;
      const stasisAspectsCat = 111111; // arbitrary, deliberately not the Light hash
      const stasisFragmentsCat = 222222;
      const totemHash = 9000; // a stasis aspect (.totems) granting +1
      const trinketHash = 9100; // a socketed stasis fragment (.trinkets)
      const emptyTrinketHash = 9200; // "Empty Fragment Socket" (.trinkets)
      const capStat = 9300;

      when(() => manifest.getInventoryItem(stasisSub)).thenReturn({
        'displayProperties': {'name': 'Behemoth', 'icon': '/sc.png'},
        'itemType': 16,
        'classType': 0,
        'talentGrid': {'hudDamageType': 6}, // Stasis
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': stasisAspectsCat, 'socketIndexes': [0]},
            {'socketCategoryHash': stasisFragmentsCat, 'socketIndexes': [1, 2, 3]},
          ],
          'socketEntries': [
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': 0},
          ],
        },
      });
      // Socket categories intentionally NOT stubbed (labels come out empty).
      when(() => manifest.getInventoryItem(totemHash)).thenReturn({
        'displayProperties': {'name': 'Cryoclasm', 'icon': '/t.png'},
        'plug': {'plugCategoryIdentifier': 'titan.stasis.totems'},
        'investmentStats': [
          {'statTypeHash': capStat, 'value': 1},
        ],
      });
      when(() => manifest.getStat(capStat)).thenReturn({
        'displayProperties': {'name': 'Aspect Energy Capacity'}
      });
      when(() => manifest.getInventoryItem(trinketHash)).thenReturn({
        'displayProperties': {'name': 'Whisper of Rime', 'icon': '/tr.png'},
        'plug': {'plugCategoryIdentifier': 'shared.stasis.trinkets'},
        'investmentStats': const [],
      });
      when(() => manifest.getInventoryItem(emptyTrinketHash)).thenReturn({
        'displayProperties': {
          'name': 'Empty Fragment Socket',
          'icon': '/etr.png'
        },
        'plug': {'plugCategoryIdentifier': 'shared.stasis.trinkets'},
        'investmentStats': const [],
      });

      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 0,
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
                      'itemHash': stasisSub,
                      'itemInstanceId': '666',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '666': {
                    'sockets': [
                      {'plugHash': totemHash, 'isVisible': true}, // +1 capacity
                      {'plugHash': trinketHash, 'isVisible': true}, // filled
                      {'plugHash': emptyTrinketHash, 'isVisible': true}, // empty
                      {'plugHash': emptyTrinketHash, 'isVisible': true}, // empty
                    ]
                  }
                }
              },
              'reusablePlugs': {'data': {}},
            },
          });

      final subclass = (await repo.fetchInventory())
          .owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .single;
      final detail = repo.resolveSubclassDetail(subclass)!;
      // The fragment group is the one whose plugs are `.trinkets` (label empty,
      // so find it by its socketed fragment name instead).
      final fragments = detail.groups
          .firstWhere((g) =>
              g.sockets.any((s) => s.equipped?.name == 'Whisper of Rime'))
          .sockets;

      // Capacity 1: the filled trinket uses the single slot, so both empty
      // trinket sockets are over capacity and disabled.
      expect(fragments.map((s) => s.available).toList(), [true, false, false]);
    });
  });

  group('resolveSubclassDetail — empty socket placeholder', () {
    // A subclass with an aspect granting capacity 2 and two fragment sockets
    // both currently EMPTY (holding the shared "Empty Fragment Socket"
    // placeholder). The placeholder must stay equippable in every slot and must
    // never read as "equipped in another slot", even though it is present in
    // both sockets' live 305.
    const sub = 5019;
    const aspectsCat = 2140934067;
    const fragmentsCat = 1313488945;
    const aspectHash = 9500; // grants +2
    const capStat = 9600;
    const emptyFragHash = 9700; // shared placeholder in both fragment sockets
    const realFragHash = 9800; // an unlocked (canInsert) fragment option
    const fragSetHash = 9900;

    setUp(() {
      when(() => manifest.getInventoryItem(sub)).thenReturn({
        'displayProperties': {'name': 'Voidwalker', 'icon': '/sc.png'},
        'itemType': 16,
        'classType': 2,
        'talentGrid': {'hudDamageType': 4},
        'inventory': {'bucketTypeHash': EquipmentBucket.subclass.hash},
        'sockets': {
          'socketCategories': [
            {'socketCategoryHash': aspectsCat, 'socketIndexes': [0]},
            {'socketCategoryHash': fragmentsCat, 'socketIndexes': [1, 2]},
          ],
          'socketEntries': [
            {'reusablePlugSetHash': 0},
            {'reusablePlugSetHash': fragSetHash},
            {'reusablePlugSetHash': fragSetHash},
          ],
        },
      });
      when(() => manifest.getSocketCategory(aspectsCat)).thenReturn({
        'displayProperties': {'name': 'ASPECTS'}
      });
      when(() => manifest.getSocketCategory(fragmentsCat)).thenReturn({
        'displayProperties': {'name': 'FRAGMENTS'}
      });
      when(() => manifest.getInventoryItem(aspectHash)).thenReturn({
        'displayProperties': {'name': 'Chaos Accelerant', 'icon': '/a.png'},
        'plug': {'plugCategoryIdentifier': 'warlock.void.aspects'},
        'investmentStats': [
          {'statTypeHash': capStat, 'value': 2},
        ],
      });
      when(() => manifest.getStat(capStat)).thenReturn({
        'displayProperties': {'name': 'Aspect Energy Capacity'}
      });
      when(() => manifest.getInventoryItem(emptyFragHash)).thenReturn({
        'displayProperties': {'name': 'Empty Fragment Socket', 'icon': '/e.png'},
        'plug': {'plugCategoryIdentifier': 'shared.void.fragments'},
        'investmentStats': const [],
      });
      when(() => manifest.getInventoryItem(realFragHash)).thenReturn({
        'displayProperties': {'name': 'Echo of Persistence', 'icon': '/f.png'},
        'plug': {'plugCategoryIdentifier': 'shared.void.fragments'},
        'investmentStats': const [],
      });
      when(() => manifest.getPlugSet(fragSetHash)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': emptyFragHash},
          {'plugItemHash': realFragHash},
        ],
      });

      when(() => api.getProfile(
            membershipType: any(named: 'membershipType'),
            membershipId: any(named: 'membershipId'),
            components: any(named: 'components'),
          )).thenAnswer((_) async => {
            'characters': {
              'data': {
                'char1': {
                  'characterId': 'char1',
                  'classType': 2,
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
                      'itemHash': sub,
                      'itemInstanceId': '777',
                      'bucketHash': EquipmentBucket.subclass.hash,
                      'state': 0,
                    }
                  ]
                }
              }
            },
            'characterInventories': {'data': {}},
            'profileInventory': {'data': {'items': []}},
            // The placeholder and the real fragment are both canInsert:true.
            'profilePlugSets': {
              'data': {
                'plugs': {
                  '$fragSetHash': [
                    {'plugItemHash': emptyFragHash, 'canInsert': true},
                    {'plugItemHash': realFragHash, 'canInsert': true},
                  ],
                }
              }
            },
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '777': {
                    'sockets': [
                      {'plugHash': aspectHash, 'isVisible': true},
                      // Both fragment sockets hold the SAME empty placeholder.
                      {'plugHash': emptyFragHash, 'isVisible': true},
                      {'plugHash': emptyFragHash, 'isVisible': true},
                    ]
                  }
                }
              },
              'reusablePlugs': {
                'data': {
                  '777': {'plugs': <String, dynamic>{}}
                }
              },
            },
          });
    });

    test('the empty placeholder stays equippable and is never '
        '"equipped in another slot", despite being in both live sockets',
        () async {
      final subclass = (await repo.fetchInventory())
          .owners
          .firstWhere((o) => !o.isVault)
          .itemsFor(EquipmentBucket.subclass.hash)
          .single;
      final detail = repo.resolveSubclassDetail(subclass)!;
      final fragments =
          detail.groups.firstWhere((g) => g.label == 'FRAGMENTS').sockets;

      for (final socket in fragments) {
        final empty =
            socket.options.firstWhere((p) => p.plugHash == emptyFragHash);
        expect(socket.optionState(empty), SubclassOptionState.equippable,
            reason: 'the empty placeholder must be equippable everywhere');
        expect(socket.equippedElsewhereHashes, isNot(contains(emptyFragHash)),
            reason: 'the placeholder must never be treated as equipped-elsewhere');
        // The real (unlocked) fragment is also equippable.
        final real =
            socket.options.firstWhere((p) => p.plugHash == realFragHash);
        expect(socket.optionState(real), SubclassOptionState.equippable);
      }
    });
  });

  group('inventoryFacetsFor', () {
    const perkPlugHash = 5001;
    const incandescentHash = 5002; // a column-1 option this copy did not equip
    const killClipHash = 5003; // the column-2 option
    const statHash = 6001;
    const collectibleHash = 7001;
    const traitSocketType = 8801; // socket type whose whitelist is `frames`

    setUp(() {
      // A weapon definition carrying two random trait sockets (perk 1 / perk 2)
      // under the WEAPON PERKS category, a stat, a collectible source, and
      // description/flavor text.
      when(() => manifest.getInventoryItem(kineticHash)).thenReturn({
        'displayProperties': {
          'name': 'Test Rifle',
          'icon': '/icon/rifle.jpg',
          'description': 'A precise rifle.',
        },
        'flavorText': 'Forged in the Light.',
        'itemType': 3,
        'collectibleHash': collectibleHash,
        'inventory': {'bucketTypeHash': EquipmentBucket.kineticWeapons.hash},
        // Range 65 from the definition (no stat group → 1:1), so the searchable
        // `stat:` facet resolves it from investment (the DIM model).
        'stats': {
          'stats': {
            '$statHash': {'statHash': statHash},
          }
        },
        'investmentStats': [
          {'statTypeHash': statHash, 'value': 65},
        ],
        'sockets': {
          'socketCategories': [
            {
              'socketCategoryHash': 4241085061, // WEAPON PERKS
              'socketIndexes': [0, 1],
            }
          ],
          'socketEntries': [
            {'socketTypeHash': traitSocketType},
            {'socketTypeHash': traitSocketType},
          ],
        },
      });
      // Both trait sockets use a type whitelisting `frames` → trait columns.
      when(() => manifest.getSocketType(traitSocketType)).thenReturn({
        'plugWhitelist': [
          {'categoryIdentifier': 'frames'}
        ],
      });
      // The socketed (equipped) perk plug and the column options.
      when(() => manifest.getInventoryItem(perkPlugHash)).thenReturn({
        'displayProperties': {'name': 'Rampage', 'icon': '/p.png'},
        'plug': {'plugCategoryIdentifier': 'frames.traits'},
      });
      when(() => manifest.getInventoryItem(incandescentHash)).thenReturn({
        'displayProperties': {'name': 'Incandescent', 'icon': '/i.png'},
        'plug': {'plugCategoryIdentifier': 'frames.traits'},
      });
      when(() => manifest.getInventoryItem(killClipHash)).thenReturn({
        'displayProperties': {'name': 'Kill Clip', 'icon': '/k.png'},
        'plug': {'plugCategoryIdentifier': 'frames.traits'},
      });
      when(() => manifest.getStat(statHash)).thenReturn({
        'displayProperties': {'name': 'Range'}
      });
      when(() => manifest.getCollectible(collectibleHash)).thenReturn({
        'sourceString': 'Source: Season of the Seraph',
      });
      // No catalyst record for this item.
      when(() => manifest.catalystRecordHashFor(kineticHash)).thenReturn(null);
      when(() => manifest.findCatalystRecord(any())).thenReturn(null);
      when(() => manifest.getBreakerType(any())).thenReturn(null);

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
                      'itemInstanceId': '111',
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
                  '111': {'primaryStat': {'value': 540}}
                }
              },
              'sockets': {
                'data': {
                  '111': {
                    'sockets': [
                      {'plugHash': perkPlugHash, 'isEnabled': true, 'isVisible': true}
                    ]
                  }
                }
              },
              // This copy's rolled options per socket: column 1 can roll
              // Rampage or Incandescent (only Rampage equipped); column 2 rolls
              // Kill Clip.
              'reusablePlugs': {
                'data': {
                  '111': {
                    'plugs': {
                      '0': [
                        {'plugItemHash': perkPlugHash},
                        {'plugItemHash': incandescentHash},
                      ],
                      '1': [
                        {'plugItemHash': killClipHash},
                      ],
                    }
                  }
                }
              },
            },
          });
    });

    test('resolves perks/stats/source/description from the live instance',
        () async {
      final grid = await repo.fetchInventory();
      final item =
          grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;

      final facets = repo.inventoryFacetsFor(item);
      expect(facets.perks, contains('rampage'));
      expect(facets.stats['range'], 65);
      expect(facets.sources, {'source: season of the seraph'});
      expect(facets.description, 'a precise rifle. forged in the light.');
      // No catalyst record → null state.
      expect(facets.catalyst, isNull);
    });

    test('perk columns hold this copy\'s rolled options, so perk1:/perk2: '
        'match unequipped options', () async {
      final grid = await repo.fetchInventory();
      final item =
          grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;

      final facets = repo.inventoryFacetsFor(item);
      // Column 1 = its rolled options (equipped Rampage + unequipped
      // Incandescent); column 2 = Kill Clip.
      expect(facets.perkColumns, [
        {'rampage', 'incandescent'},
        {'kill clip'},
      ]);

      // The reported bug: perk1:incandescent must match a copy that can roll
      // Incandescent in column 1 even though Rampage is equipped.
      SearchFacets? facetsOf(item) => repo.inventoryFacetsFor(item);
      expect(compileQuery('perk1:incandescent', facetsOf: facetsOf).matches(item),
          isTrue);
      // Column is respected: Kill Clip is column 2, not column 1. (Multi-word
      // perk values must be quoted, else the space splits into two terms.)
      expect(compileQuery('perk1:"kill clip"', facetsOf: facetsOf).matches(item),
          isFalse);
      expect(compileQuery('perk2:"kill clip"', facetsOf: facetsOf).matches(item),
          isTrue);
    });

    test('caches facets by instance id (same object on repeat calls)',
        () async {
      final grid = await repo.fetchInventory();
      final item =
          grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;
      final first = repo.inventoryFacetsFor(item);
      final second = repo.inventoryFacetsFor(item);
      expect(identical(first, second), isTrue);
    });

    test('resolves set facets so set:/set2:/set4: match on the Inventory tab',
        () async {
      // Put the loaded item in a set with a 2-piece and 4-piece bonus. This is
      // the Inventory-tab half of the plan's "both tabs" criterion (the Database
      // tab is covered by buildSetSearchIndex / setEffectOptions tests).
      const perk2 = 9101;
      const perk4 = 9102;
      when(() => manifest.allEquipableItemSets()).thenReturn([
        {
          'hash': 9100,
          'displayProperties': {'name': 'Thriving Survivor'},
          'setItems': [kineticHash],
          'setPerks': [
            {'requiredSetCount': 2, 'sandboxPerkHash': perk2},
            {'requiredSetCount': 4, 'sandboxPerkHash': perk4},
          ],
        },
      ]);
      when(() => manifest.getSandboxPerk(perk2)).thenReturn({
        'displayProperties': {'name': 'Opening Act'}
      });
      when(() => manifest.getSandboxPerk(perk4)).thenReturn({
        'displayProperties': {'name': 'Radiant Orbs'}
      });

      final grid = await repo.fetchInventory();
      final item =
          grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;
      SearchFacets? facetsOf(i) => repo.inventoryFacetsFor(i);

      expect(compileQuery('set:thriving', facetsOf: facetsOf).matches(item),
          isTrue);
      expect(compileQuery('set2:"opening act"', facetsOf: facetsOf).matches(item),
          isTrue);
      expect(compileQuery('set4:"radiant orbs"', facetsOf: facetsOf).matches(item),
          isTrue);
      // Cross-count: the 4-piece name must not match set2:.
      expect(compileQuery('set2:"radiant orbs"', facetsOf: facetsOf).matches(item),
          isFalse);
    });

    test('warmFacets pre-populates the cache so later lookups do no work',
        () async {
      final grid = await repo.fetchInventory();
      final items = [
        for (final owner in grid.owners)
          for (final list in owner.itemsByBucket.values) ...list,
      ];
      await repo.warmFacets(items);

      // The warm resolved every item. A lookup afterwards must hit the cache —
      // touching the manifest again would mean the warm missed it.
      clearInteractions(manifest);
      final item =
          grid.owners.first.itemsFor(EquipmentBucket.kineticWeapons.hash).single;
      final facets = repo.inventoryFacetsFor(item);
      expect(facets.perks, contains('rampage')); // warmed correctly
      verifyNever(() => manifest.getInventoryItem(any()));
    });

    test('warmFacets yields once per item (one heavy decode between frames)',
        () async {
      final grid = await repo.fetchInventory();
      final items = [
        for (final owner in grid.owners)
          for (final list in owner.itemsByBucket.values) ...list,
      ];
      expect(items, isNotEmpty);

      var yields = 0;
      await repo.warmFacets(items, onYield: () async => yields++);

      // One yield per item — the throttle resolves a single item then waits, so
      // no stretch of heavy decodes runs back-to-back without a frame gap.
      expect(yields, items.length);
    });

    test('warmFacets stops early when superseded (isCancelled true)', () async {
      final grid = await repo.fetchInventory();
      final items = [
        for (final owner in grid.owners)
          for (final list in owner.itemsByBucket.values) ...list,
        // Pad with copies so there is more than one iteration to cancel across.
        for (final owner in grid.owners)
          for (final list in owner.itemsByBucket.values) ...list,
      ];
      expect(items.length, greaterThan(1));

      var iterations = 0;
      // Cancel after the first item is processed.
      await repo.warmFacets(
        items,
        onYield: () async => iterations++,
        isCancelled: () => iterations >= 1,
      );

      // It stopped at the first cancel check after one item, not the full list.
      expect(iterations, 1);
      expect(iterations, lessThan(items.length));
    });
  });

  group('applied ornament composite', () {
    const exoticHelmHash = 3003;
    const legendaryHelmHash = 4004;
    const ornamentPlugHash = 8001;
    const ornamentIconHash = 9001; // ornament's layered icon def
    const exoticIconHash = 9002; // exotic item's layered icon def

    void stubProfileWith(int itemHash) {
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
                  {
                    'itemHash': itemHash,
                    'itemInstanceId': '900',
                    'bucketHash': EquipmentBucket.helmet.hash,
                    'state': 0,
                  }
                ]
              }
            },
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '900': {
                    'sockets': [
                      {'plugHash': ornamentPlugHash, 'isEnabled': true}
                    ]
                  }
                }
              },
            },
          });
    }

    setUp(() {
      // An applied armor ornament plug (itemSubType 21 → recognized override),
      // carrying an iconHash to its layered icon definition.
      when(() => manifest.getInventoryItem(ornamentPlugHash)).thenReturn({
        'displayProperties': {
          'name': 'Fancy Helm Skin',
          'icon': '/orn.jpg',
          'iconHash': ornamentIconHash,
        },
        'itemSubType': 21,
        'plug': {'plugCategoryIdentifier': 'armor_skins_warlock_head'},
      });
      // The ornament's layered icon: transparent foreground + legendary plate.
      when(() => manifest.getIcon(ornamentIconHash)).thenReturn({
        'foreground': '/orn_fg.png',
        'background': '/rarity_legendary.png',
      });
      // The exotic item's layered icon: its own gold rarity plate.
      when(() => manifest.getIcon(exoticIconHash)).thenReturn({
        'foreground': '/exotic_fg.png',
        'background': '/rarity_exotic.png',
      });
    });

    test('exotic + ornament composites the exotic plate with ornament art',
        () async {
      when(() => manifest.getInventoryItem(exoticHelmHash)).thenReturn({
        'displayProperties': {
          'name': 'Exotic Helm',
          'icon': '/e.jpg',
          'iconHash': exoticIconHash,
        },
        'itemType': 2,
        'inventory': {
          'bucketTypeHash': EquipmentBucket.helmet.hash,
          'tierType': 6,
        },
      });
      stubProfileWith(exoticHelmHash);

      final grid = await repo.fetchInventory();
      final helm =
          grid.owners.single.itemsFor(EquipmentBucket.helmet.hash).single;
      // Ornament art foreground over the EXOTIC plate (not the ornament's own
      // legendary plate).
      expect(helm.ornamentForegroundUrl, 'https://www.bungie.net/orn_fg.png');
      expect(helm.rarityPlateUrl, 'https://www.bungie.net/rarity_exotic.png');
    });

    test('legendary + ornament does not composite (flat icon retained)',
        () async {
      when(() => manifest.getInventoryItem(legendaryHelmHash)).thenReturn({
        'displayProperties': {
          'name': 'Legendary Helm',
          'icon': '/l.jpg',
          'iconHash': exoticIconHash,
        },
        'itemType': 2,
        'inventory': {
          'bucketTypeHash': EquipmentBucket.helmet.hash,
          'tierType': 5,
        },
      });
      stubProfileWith(legendaryHelmHash);

      final grid = await repo.fetchInventory();
      final helm =
          grid.owners.single.itemsFor(EquipmentBucket.helmet.hash).single;
      // No composite for non-exotics: the flat ornament icon still overrides.
      expect(helm.ornamentForegroundUrl, isNull);
      expect(helm.rarityPlateUrl, isNull);
      expect(helm.ornamentIconUrl, 'https://www.bungie.net/orn.jpg');
    });
  });

  group('refresh decode reuse (poll diffing)', () {
    // A single vault helmet whose raw item map is mutated between fetches to
    // simulate an in-game change. Object identity of the resulting DestinyItem
    // proves reuse (same instance) vs. re-decode (new instance).
    late Map<String, dynamic> rawHelm;

    Map<String, dynamic> helmItem() => {
          'itemHash': helmetHash,
          'itemInstanceId': '333',
          'bucketHash': EquipmentBucket.helmet.hash,
          'state': 0,
        };

    setUp(() {
      rawHelm = helmItem();
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
                'items': [rawHelm]
              }
            },
            'itemComponents': {'instances': {'data': {}}},
          });
    });

    DestinyItem theHelm(InventoryGrid grid) =>
        grid.owners.single.itemsFor(EquipmentBucket.helmet.hash).single;

    test('an unchanged item is reused (same instance) on a reuse refresh',
        () async {
      final first = theHelm(await repo.fetchInventory());
      final second = theHelm(await repo.fetchInventory(reuseDecoded: true));
      expect(identical(first, second), isTrue);
    });

    test('the initial load never reuses (always decodes fresh)', () async {
      final first = theHelm(await repo.fetchInventory());
      // A second plain fetch (reuseDecoded defaults false) re-decodes.
      final second = theHelm(await repo.fetchInventory());
      expect(identical(first, second), isFalse);
    });

    test('a state change (e.g. newly locked) re-decodes rather than reusing',
        () async {
      final first = theHelm(await repo.fetchInventory());
      // The item is now locked in game (ItemState bit 1).
      rawHelm['state'] = 1;
      final second = theHelm(await repo.fetchInventory(reuseDecoded: true));
      expect(identical(first, second), isFalse);
      expect(second.isLocked, isTrue); // the fresh decode reflects the change
    });

    test('a re-ornament (socket plug change) re-decodes rather than reusing',
        () async {
      // Give the helmet a socket with an ornament plug, then change it. The
      // ornament icon is part of the decode, so the signature must catch it.
      const ornamentA = 8001;
      const ornamentB = 8002;
      when(() => manifest.getInventoryItem(ornamentA)).thenReturn({
        'displayProperties': {'name': 'Skin A', 'icon': '/a.jpg'},
        'itemSubType': 21,
        'plug': {'plugCategoryIdentifier': 'armor_skins'},
      });
      when(() => manifest.getInventoryItem(ornamentB)).thenReturn({
        'displayProperties': {'name': 'Skin B', 'icon': '/b.jpg'},
        'itemSubType': 21,
        'plug': {'plugCategoryIdentifier': 'armor_skins'},
      });
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
                'items': [rawHelm]
              }
            },
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '333': {
                    'sockets': [
                      {'plugHash': ornamentA, 'isEnabled': true}
                    ]
                  }
                }
              },
            },
          });

      final first = theHelm(await repo.fetchInventory());
      expect(first.ornamentIconUrl, 'https://www.bungie.net/a.jpg');

      // Swap the socketed ornament plug to B.
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
                'items': [rawHelm]
              }
            },
            'itemComponents': {
              'instances': {'data': {}},
              'sockets': {
                'data': {
                  '333': {
                    'sockets': [
                      {'plugHash': ornamentB, 'isEnabled': true}
                    ]
                  }
                }
              },
            },
          });

      final second = theHelm(await repo.fetchInventory(reuseDecoded: true));
      expect(identical(first, second), isFalse);
      expect(second.ornamentIconUrl, 'https://www.bungie.net/b.jpg');
    });

    test('an unchanged item keeps its warmed facets across a reuse-refresh',
        () async {
      final first = theHelm(await repo.fetchInventory());
      // Warm this item's facets (populates the per-instance facet cache).
      final facetsBefore = repo.inventoryFacetsFor(first);

      // A reuse-refresh with the item unchanged must NOT drop its facets.
      final refreshed = theHelm(await repo.fetchInventory(reuseDecoded: true));
      // Looking the facets up again does no manifest work — they were kept.
      clearInteractions(manifest);
      final facetsAfter = repo.inventoryFacetsFor(refreshed);
      expect(identical(facetsBefore, facetsAfter), isTrue,
          reason: 'facets should survive the poll for an unchanged item');
      verifyNever(() => manifest.getInventoryItem(any()));
    });

    test('a changed item drops its facets so they re-resolve', () async {
      final first = theHelm(await repo.fetchInventory());
      final facetsBefore = repo.inventoryFacetsFor(first);

      // The item is newly locked → its decode (and thus facets) may change.
      rawHelm['state'] = 1;
      final refreshed = theHelm(await repo.fetchInventory(reuseDecoded: true));
      final facetsAfter = repo.inventoryFacetsFor(refreshed);
      expect(identical(facetsBefore, facetsAfter), isFalse,
          reason: 'a re-decoded item must re-resolve its facets, not reuse');
    });
  });
}
