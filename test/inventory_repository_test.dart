import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/core/search/item_filter.dart';
import 'package:d2_armory/data/remote/bungie_api.dart';
import 'package:d2_armory/data/repositories/inventory_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/destiny_item.dart';
import 'package:d2_armory/domain/models/inventory_grid.dart';

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
