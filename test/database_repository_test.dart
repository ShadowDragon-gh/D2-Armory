import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/data/repositories/database_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/item_detail.dart';

class _MockManifest extends Mock implements ManifestRepository {}

/// Socket-category hashes as they appear in real definitions.
const _weaponPerksCategory = 4241085061;

/// A minimal plug (perk/frame) definition. [typeName] sets itemTypeDisplayName
/// (e.g. "Enhanced Trait"); [enhancedViaTooltip] instead marks it enhanced only
/// through the game's enhanced tooltip style — the way enhanced origin traits
/// are flagged while their itemTypeDisplayName stays a plain "Origin Trait".
Map<String, dynamic> _plug(String name,
        {String category = 'frames',
        String? typeName,
        bool enhancedViaTooltip = false}) =>
    {
      'displayProperties': {'name': name, 'icon': '/i/$name.png'},
      'plug': {'plugCategoryIdentifier': category},
      'itemTypeDisplayName': ?typeName,
      if (enhancedViaTooltip)
        'tooltipNotifications': [
          {'displayStyle': 'ui_display_style_enhanced_perk'}
        ],
    };

void main() {
  late _MockManifest manifest;
  late DatabaseRepository repo;

  setUpAll(() => registerFallbackValue(GearKind.weapon));

  setUp(() {
    manifest = _MockManifest();
    repo = DatabaseRepository(manifest: manifest);
  });

  /// A projected summary row as queryGearSummaries returns it.
  Map<String, Object?> row({
    required int hash,
    required String name,
    String icon = '/i.png',
    int tierType = 5,
    int itemType = 3,
    int itemSubType = 9,
    int classType = 3,
    int damageType = 1,
    int index = 0,
  }) =>
      {
        'hash': hash,
        'name': name,
        'icon': icon,
        'tierType': tierType,
        'itemType': itemType,
        'itemSubType': itemSubType,
        'itemTypeDisplayName': '',
        'classType': classType,
        'damageType': damageType,
        'damageTypeHash': null,
        'ammoType': 1,
        'bucketHash': 1498876634,
        'idx': index,
      };

  group('listGear dedupe', () {
    test('dedupes by name, keeping the highest manifest index (newest)', () {
      when(() => manifest.queryGearSummaries(GearKind.weapon)).thenReturn([
        row(hash: 1, name: 'Fatebringer', icon: '/old.png', index: 10),
        row(hash: 2, name: 'Fatebringer', icon: '/new.png', index: 42),
        row(hash: 3, name: 'Palindrome', icon: '/p.png', index: 5),
      ]);

      final rows = repo.listGear(const GearFilter(kind: GearKind.weapon));
      final byName = {for (final r in rows) r.name: r};

      expect(byName.keys.toSet(), {'Fatebringer', 'Palindrome'});
      // The newer (index 42) Fatebringer wins: its hash and icon are kept.
      expect(byName['Fatebringer']!.itemHash, 2);
      expect(byName['Fatebringer']!.iconPath, '/new.png');
    });

    test('caches the per-kind index — the manifest scan runs once', () {
      when(() => manifest.queryGearSummaries(GearKind.weapon))
          .thenReturn([row(hash: 1, name: 'RealHC')]);

      repo.listGear(const GearFilter(kind: GearKind.weapon));
      repo.listGear(const GearFilter(kind: GearKind.weapon, tierType: 6));
      repo.listGear(const GearFilter(kind: GearKind.weapon));

      verify(() => manifest.queryGearSummaries(GearKind.weapon)).called(1);
    });
  });

  group('listGear facet filters', () {
    setUp(() {
      when(() => manifest.queryGearSummaries(GearKind.weapon)).thenReturn([
        row(hash: 1, name: 'ExoticSolarHC', tierType: 6, damageType: 3),
        row(hash: 2, name: 'LegendaryVoidAR', itemSubType: 6, damageType: 4),
        row(hash: 3, name: 'LegendarySolarHC', damageType: 3),
      ]);
    });

    test('tier filter keeps only the matching rarity', () {
      final rows = repo
          .listGear(const GearFilter(kind: GearKind.weapon, tierType: 6));
      expect(rows.map((r) => r.name), ['ExoticSolarHC']);
    });

    test('subtype filter keeps only the matching weapon type', () {
      final rows = repo
          .listGear(const GearFilter(kind: GearKind.weapon, itemSubType: 6));
      expect(rows.map((r) => r.name), ['LegendaryVoidAR']);
    });

    test('damage filter keeps only the matching element', () {
      final rows = repo
          .listGear(const GearFilter(kind: GearKind.weapon, damageType: 3));
      expect(rows.map((r) => r.name).toSet(),
          {'ExoticSolarHC', 'LegendarySolarHC'});
    });
  });

  group('resolveGearDetail — weapon perk columns', () {
    setUp(() {
      // resolveGearDetail resolves versions via the cached index; no reissues
      // needed here, so the summaries scan returns empty.
      when(() => manifest.queryGearSummaries(any())).thenReturn([]);
      when(() => manifest.getSocketType(any())).thenReturn(null);

      // A weapon with one WEAPON PERKS socket (index 1) drawing from a
      // randomized plug set. Socket index 0 is a non-perk intrinsic frame.
      when(() => manifest.getInventoryItem(100)).thenReturn({
        'hash': 100,
        'displayProperties': {'name': 'Test Cannon', 'icon': '/tc.png'},
        'itemType': 3,
        'itemSubType': 9,
        'defaultDamageType': 1,
        'flavorText': 'A test.',
        'screenshot': '/shot/tc.jpg',
        'inventory': {'tierType': 5, 'bucketTypeHash': 1498876634},
        'stats': {
          'stats': {
            '1': {'statHash': 111, 'value': 60},
            '2': {'statHash': 222, 'value': 30},
          }
        },
        'sockets': {
          'socketCategories': [
            {
              'socketCategoryHash': _weaponPerksCategory,
              'socketIndexes': [1]
            },
          ],
          'socketEntries': [
            {'singleInitialItemHash': 900}, // frame intrinsic (index 0)
            {'randomizedPlugSetHash': 555}, // perk column (index 1)
          ],
        },
      });

      // Stat definitions.
      when(() => manifest.getStat(111)).thenReturn({
        'displayProperties': {'name': 'Range'}
      });
      when(() => manifest.getStat(222)).thenReturn({
        'displayProperties': {'name': 'Magazine'}
      });

      // The intrinsic frame plug.
      when(() => manifest.getInventoryItem(900))
          .thenReturn(_plug('Adaptive Frame', category: 'intrinsics'));

      // The perk column's plug set: a base perk, an enhanced trait, an enhanced
      // barrel, an enhanced-via-tooltip copy of the base perk (same name, as
      // enhanced origin traits appear), an empty placeholder with no name, and
      // a crafted-weapon empty-socket placeholder (a NAMED "Empty Traits
      // Socket").
      when(() => manifest.getPlugSet(555)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': 801},
          {'plugItemHash': 802},
          {'plugItemHash': 804},
          {'plugItemHash': 805}, // enhanced "Rampage" via tooltip → NOT deduped
          {'plugItemHash': 803}, // placeholder (no display name) → dropped
          {'plugItemHash': 806}, // crafting empty-socket placeholder → dropped
          {'plugItemHash': 807}, // 2nd base "Rampage" hash → deduped to one
        ]
      });
      when(() => manifest.getInventoryItem(801))
          .thenReturn(_plug('Rampage', category: 'frames.traits'));
      when(() => manifest.getInventoryItem(802)).thenReturn(
          _plug('Kill Clip', category: 'frames.traits', typeName: 'Enhanced Trait'));
      // An enhanced barrel — enhanced via itemTypeDisplayName, not a trait.
      when(() => manifest.getInventoryItem(804)).thenReturn(
          _plug('Fluted Barrel', category: 'barrels', typeName: 'Enhanced Barrel'));
      // The enhanced Rampage: same name as 801, flagged only by the enhanced
      // tooltip style (its itemTypeDisplayName stays plain).
      when(() => manifest.getInventoryItem(805)).thenReturn(
          _plug('Rampage', category: 'frames.traits', enhancedViaTooltip: true));
      // Placeholder plug with no name.
      when(() => manifest.getInventoryItem(803)).thenReturn({
        'displayProperties': {'name': ''},
        'plug': {'plugCategoryIdentifier': 'frames.traits'},
      });
      // A crafted-weapon empty-socket placeholder: it HAS a display name
      // ("Empty Traits Socket") but its crafting.recipes.empty_socket category
      // marks it as the unfilled-socket default, not a real perk.
      when(() => manifest.getInventoryItem(806)).thenReturn({
        'displayProperties': {'name': 'Empty Traits Socket'},
        'plug': {'plugCategoryIdentifier': 'crafting.recipes.empty_socket'},
      });
      // A second base "Rampage" under a different hash — the game ships more
      // than one hash for the same perk. It must collapse into the one base
      // Rampage chip (801), not show a duplicate.
      when(() => manifest.getInventoryItem(807))
          .thenReturn(_plug('Rampage', category: 'frames.traits'));
      when(() => manifest.getBreakerType(any())).thenReturn(null);
    });

    test('stats come from the definition with no instance bonus/reduction', () {
      final detail = repo.resolveGearDetail(100)!;
      final range = detail.stats.firstWhere((s) => s.name == 'Range');
      expect(range.value, 60);
      expect(range.bonus, 0);
      expect(range.reduction, 0);
      // Magazine is a numeric stat (bare number, not a bar).
      final mag = detail.stats.firstWhere((s) => s.name == 'Magazine');
      expect(mag.display, StatDisplay.numeric);
    });

    test('flavor text and screenshot are carried through', () {
      final detail = repo.resolveGearDetail(100)!;
      expect(detail.flavorText, 'A test.');
      expect(detail.screenshotPath, '/shot/tc.jpg');
    });

    test('perk column lists every candidate, dropping empty placeholders', () {
      final plugs = repo.resolveGearDetail(100)!.perkColumns.single.plugs;
      // 803 (no name) and 806 (crafting empty-socket) both dropped. The base and
      // enhanced Rampage are both kept — same-named base/enhanced rolls are
      // distinct, real options and are never deduped.
      expect(plugs.length, 4);
      expect(plugs.map((p) => p.name).toSet(),
          {'Rampage', 'Kill Clip', 'Fluted Barrel'});
      expect(plugs.where((p) => p.name == 'Rampage').length, 2);
    });

    test('crafted-weapon empty-socket placeholders are not shown as perks', () {
      final plugs = repo.resolveGearDetail(100)!.perkColumns.single.plugs;
      // The named "Empty Traits Socket" placeholder (crafting.recipes.
      // empty_socket) must never appear as a selectable perk.
      expect(plugs.where((p) => p.name == 'Empty Traits Socket'), isEmpty);
    });

    test('display-identical perks (same name + enhancement) are deduped', () {
      final plugs = repo.resolveGearDetail(100)!.perkColumns.single.plugs;
      // Hashes 801 and 807 are both base "Rampage" — they collapse to one chip.
      // The enhanced Rampage (805) is a distinct option and survives, so there
      // are exactly two Rampages: one base, one enhanced.
      final rampages = plugs.where((p) => p.name == 'Rampage').toList();
      expect(rampages.length, 2);
      expect(rampages.where((p) => p.isEnhanced).length, 1);
      expect(rampages.where((p) => !p.isEnhanced).length, 1);
    });

    test('enhanced plugs are ordered before base plugs in a column', () {
      final plugs = repo.resolveGearDetail(100)!.perkColumns.single.plugs;
      // All three enhanced (Kill Clip, Fluted Barrel, enhanced Rampage) come
      // first; the base Rampage comes last.
      final firstBase = plugs.indexWhere((p) => !p.isEnhanced);
      final lastEnhanced = plugs.lastIndexWhere((p) => p.isEnhanced);
      expect(lastEnhanced, lessThan(firstBase));
      expect(plugs.last.name, 'Rampage');
      expect(plugs.last.isEnhanced, isFalse);
    });

    test('enhanced flagged across families: trait, barrel, and tooltip-only', () {
      final plugs = repo.resolveGearDetail(100)!.perkColumns.single.plugs;
      expect(plugs.firstWhere((p) => p.name == 'Kill Clip').isEnhanced, isTrue);
      expect(
          plugs.firstWhere((p) => p.name == 'Fluted Barrel').isEnhanced, isTrue);
      // Rampage appears twice: one base, one enhanced (flagged only by the
      // enhanced tooltip style — the origin-trait case).
      final rampages = plugs.where((p) => p.name == 'Rampage').toList();
      expect(rampages.where((p) => p.isEnhanced).length, 1);
      expect(rampages.where((p) => !p.isEnhanced).length, 1);
    });

    test('intrinsic frame plug is resolved', () {
      final detail = repo.resolveGearDetail(100)!;
      expect(detail.frame?.name, 'Adaptive Frame');
    });
  });

  group('resolveGearDetail — armor', () {
    test('armor gets its exotic intrinsic but no weapon perk columns', () {
      when(() => manifest.queryGearSummaries(any())).thenReturn([]);
      when(() => manifest.getSocketType(any())).thenReturn(null);
      when(() => manifest.getInventoryItem(200)).thenReturn({
        'hash': 200,
        'displayProperties': {'name': 'Exotic Helm', 'icon': '/h.png'},
        'itemType': 2,
        'itemSubType': 26,
        'defaultDamageType': 0,
        'inventory': {'tierType': 6, 'bucketTypeHash': 3448274439},
        'stats': {
          'stats': {
            '1': {'statHash': 111, 'value': 12},
          }
        },
        'sockets': {
          // Armor has an ARMOR PERKS category, never WEAPON PERKS.
          'socketCategories': [
            {
              'socketCategoryHash': 2518356196,
              'socketIndexes': [0]
            },
          ],
          'socketEntries': [
            {'singleInitialItemHash': 910}, // exotic intrinsic (index 0)
          ],
        },
      });
      when(() => manifest.getStat(111)).thenReturn({
        'displayProperties': {'name': 'Mobility'}
      });
      when(() => manifest.getInventoryItem(910))
          .thenReturn(_plug('Nightmare Fuel', category: 'intrinsics'));
      when(() => manifest.getBreakerType(any())).thenReturn(null);

      final detail = repo.resolveGearDetail(200)!;
      expect(detail.perkColumns, isEmpty);
      expect(detail.frame?.name, 'Nightmare Fuel');
      expect(detail.stats.single.name, 'Mobility');
    });
  });

  group('facetsFor — search facet build', () {
    setUp(() {
      when(() => manifest.queryGearSummaries(GearKind.weapon))
          .thenReturn([row(hash: 100, name: 'Facet Cannon')]);

      when(() => manifest.getInventoryItem(100)).thenReturn({
        'hash': 100,
        'displayProperties': {
          'name': 'Facet Cannon',
          'icon': '/fc.png',
          'description': 'Precision matters.',
        },
        'flavorText': 'Forged in the Light.',
        'itemType': 3,
        // Legendary: its "Adaptive Frame" is a shared archetype (in the frame
        // catalog), unlike an exotic's unique intrinsic.
        'inventory': {'tierType': 5, 'bucketTypeHash': 1498876634},
        'breakerTypeHash': 3178805705, // Stagger → Unstoppable
        'collectibleHash': 777,
        'stats': {
          'stats': {
            '1': {'statHash': 111, 'value': 60},
            '2': {'statHash': 222, 'value': 30},
          }
        },
        'sockets': {
          'socketEntries': [
            {'singleInitialItemHash': 900}, // archetype frame intrinsic
            {'randomizedPlugSetHash': 555},
          ],
        },
      });
      // The archetype frame: name ends in "frame", so it enters the frame
      // catalog and is `frame:`-searchable.
      when(() => manifest.getInventoryItem(900))
          .thenReturn(_plug('Adaptive Frame', category: 'intrinsics'));
      when(() => manifest.getStat(111)).thenReturn({
        'displayProperties': {'name': 'Range'}
      });
      when(() => manifest.getStat(222)).thenReturn({
        'displayProperties': {'name': 'Reload Speed'}
      });
      // The perk pool: one real trait, one magazine (searchable via perk: but
      // NOT a suggestable trait perk), plus a masterwork plug excluded entirely.
      when(() => manifest.getPlugSet(555)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': 801},
          {'plugItemHash': 803}, // magazine → in perks pool, not in catalog
          {'plugItemHash': 802}, // masterwork → excluded from perks
        ]
      });
      when(() => manifest.getInventoryItem(801))
          .thenReturn(_plug('Rampage', category: 'frames.traits'));
      when(() => manifest.getInventoryItem(803))
          .thenReturn(_plug('Alloy Magazine', category: 'magazines'));
      when(() => manifest.getInventoryItem(802))
          .thenReturn(_plug('Range MW', category: 'v400.weapon.masterworks'));
      when(() => manifest.getBreakerType(3178805705)).thenReturn({
        'displayProperties': {'name': 'Stagger'}
      });
      when(() => manifest.getCollectible(777)).thenReturn({
        'sourceString': 'Source: Season of the Seraph',
      });
    });

    test('resolves perks (traits only), stats, breaker, source, description',
        () {
      final facets = repo.facetsFor(GearKind.weapon, 100)!;
      // The `perk:` search pool includes traits AND build plugs like the
      // magazine (so perk:"alloy magazine" still finds the weapon); only the
      // masterwork is excluded.
      expect(facets.perks, {'rampage', 'alloy magazine'});
      expect(facets.stats, {'range': 60, 'reload speed': 30});
      // Stagger's champion effect is Unstoppable; both are searchable so
      // breaker:stagger and breaker:unstoppable each match.
      expect(facets.breaker, 'stagger unstoppable');
      expect(facets.sources, {'source: season of the seraph'});
      // Description folds in both the mechanical description and flavor text.
      expect(facets.description, 'precision matters. forged in the light.');
    });

    test('returns null for a hash not in the index', () {
      expect(repo.facetsFor(GearKind.weapon, 999), isNull);
    });

    test('perkOptions holds trait perks only, not build plugs or masterworks',
        () {
      // Touch the item so its perks decode via the lazy builder (the path a
      // search hits before the background warm lands).
      repo.facetsFor(GearKind.weapon, 100);
      final options = repo.perkOptions();
      final names = options.map((p) => p.name).toSet();

      // The trait perk is offered, with its icon.
      final rampage = options.where((p) => p.name == 'rampage');
      expect(rampage, isNotEmpty,
          reason: 'perk: autocomplete must work before the warm completes');
      expect(rampage.single.iconPath, '/i/Rampage.png');

      // The magazine is searchable (in facets.perks) but is NOT a suggestable
      // trait perk, so it stays out of the autocomplete catalog. Likewise the
      // masterwork. This is the regression the user hit: weapons/build plugs
      // leaking into the perk list.
      expect(names, isNot(contains('alloy magazine')));
      expect(names.any((n) => n.contains('mw')), isFalse);
    });

    test('frameOptions holds archetype frames only, not exotic intrinsics', () {
      // A second, EXOTIC weapon whose unique intrinsic is named like an
      // archetype ("Command Frame" — the real Choir of One case). It is
      // frame:-searchable but must be kept out of the archetype list purely
      // because its owner is exotic, even though the name ends in "frame".
      when(() => manifest.queryGearSummaries(GearKind.weapon)).thenReturn([
        row(hash: 100, name: 'Facet Cannon'),
        row(hash: 200, name: 'Exotic Cannon'),
      ]);
      when(() => manifest.getInventoryItem(200)).thenReturn({
        'hash': 200,
        'displayProperties': {'name': 'Exotic Cannon', 'icon': '/ec.png'},
        'itemType': 3,
        'inventory': {'tierType': 6, 'bucketTypeHash': 1498876634}, // exotic
        'sockets': {
          'socketEntries': [
            {'singleInitialItemHash': 902}, // unique exotic intrinsic
          ],
        },
      });
      when(() => manifest.getInventoryItem(902))
          .thenReturn(_plug('Command Frame', category: 'intrinsics'));

      repo.facetsFor(GearKind.weapon, 100); // legendary "Adaptive Frame"
      repo.facetsFor(GearKind.weapon, 200); // exotic "Command Frame"

      // Both frames are searchable via facets.frame…
      expect(repo.facetsFor(GearKind.weapon, 100)!.frame, 'adaptive frame');
      expect(repo.facetsFor(GearKind.weapon, 200)!.frame, 'command frame');

      // …but the exotic's "Command Frame" is excluded from the archetype list
      // despite ending in "frame", because its owner is exotic.
      final frameNames = repo.frameOptions().map((f) => f.name).toSet();
      expect(frameNames, contains('adaptive frame'));
      expect(frameNames, isNot(contains('command frame')));
      expect(repo.frameOptions().single.iconPath, '/i/Adaptive Frame.png');
    });
  });

  group('armor sets — reverse index', () {
    // Two members of one set + a stat-perk pair, mirroring a real
    // DestinyEquipableItemSetDefinition (2-piece / 4-piece bonuses).
    const setHash = 2151917545;
    const memberA = 2419726011;
    const memberB = 365930261;
    const perk2Hash = 681117218;
    const perk4Hash = 681117219;

    setUp(() {
      when(() => manifest.allEquipableItemSets()).thenReturn([
        {
          'hash': setHash,
          'displayProperties': {'name': 'Thriving Survivor'},
          'setItems': [memberA, memberB],
          // Deliberately out of order to prove ascending sort by count.
          'setPerks': [
            {'requiredSetCount': 4, 'sandboxPerkHash': perk4Hash},
            {'requiredSetCount': 2, 'sandboxPerkHash': perk2Hash},
          ],
          'redacted': false,
        },
      ]);
      when(() => manifest.getSandboxPerk(perk2Hash)).thenReturn({
        'displayProperties': {
          'name': 'Opening Act',
          'description': 'A two-piece bonus.',
          'icon': '/i/opening_act.png',
        }
      });
      when(() => manifest.getSandboxPerk(perk4Hash)).thenReturn({
        'displayProperties': {
          'name': 'Second Act',
          'description': 'A four-piece bonus.',
          'icon': '/i/second_act.png',
        }
      });
    });

    test('a member item resolves to its set with both perks (sorted)', () {
      final set = repo.armorSetForItem(memberA);
      expect(set, isNotNull);
      expect(set!.hash, setHash);
      expect(set.name, 'Thriving Survivor');
      expect(set.memberHashes, containsAll([memberA, memberB]));
      // Perks ascending by required count: 2-piece then 4-piece.
      expect(set.perks.map((p) => p.requiredSetCount), [2, 4]);
      expect(set.perks[0].name, 'Opening Act');
      expect(set.perks[0].description, 'A two-piece bonus.');
      expect(set.perks[0].iconUrl, contains('/i/opening_act.png'));
      expect(set.perks[1].name, 'Second Act');
    });

    test('every member of the set maps back to the same set', () {
      expect(repo.armorSetForItem(memberB)!.hash, setHash);
      expect(repo.armorSetByHash(setHash)!.name, 'Thriving Survivor');
    });

    test('an item in no set resolves to null', () {
      expect(repo.armorSetForItem(999999), isNull);
    });

    test('the reverse index is built once (allEquipableItemSets read once)',
        () {
      repo.armorSetForItem(memberA);
      repo.armorSetForItem(memberB);
      repo.armorSetByHash(setHash);
      verify(() => manifest.allEquipableItemSets()).called(1);
    });
  });
}
