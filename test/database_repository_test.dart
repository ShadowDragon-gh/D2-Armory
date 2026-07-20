import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/destiny/destiny_buckets.dart';
import 'package:d2_armory/data/repositories/d2ai_repository.dart';
import 'package:d2_armory/data/repositories/database_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/item_detail.dart';

class _MockManifest extends Mock implements ManifestRepository {}

class _MockD2ai extends Mock implements D2aiRepository {}

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
    String? pci,
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
        'pci': pci,
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

    test('armor pieces sharing a name but differing by class/slot are both '
        'kept; a true reissue (same name+class+slot) still collapses', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // A set's "Boots" name reused across two classes (legs, slot 29) —
        // these are distinct pieces and must BOTH survive.
        row(hash: 1, name: 'Set Boots', itemType: 2, itemSubType: 29, classType: 0),
        row(hash: 2, name: 'Set Boots', itemType: 2, itemSubType: 29, classType: 2),
        // A true reissue: same name, class, and slot — collapses to the newest.
        row(hash: 3, name: 'Reissued Helm', itemType: 2, itemSubType: 26, classType: 0, index: 1),
        row(hash: 4, name: 'Reissued Helm', itemType: 2, itemSubType: 26, classType: 0, index: 9),
      ]);

      final rows = repo.listGear(const GearFilter(kind: GearKind.armor));
      // Both "Set Boots" survive (Titan + Warlock legs).
      expect(rows.where((r) => r.name == 'Set Boots').map((r) => r.classType),
          unorderedEquals([0, 2]));
      // The reissue collapses to the newest (index 9 → hash 4).
      final reissue =
          rows.where((r) => r.name == 'Reissued Helm').toList();
      expect(reissue.single.itemHash, 4);
    });
  });

  group('ability index — pci-derived class/element', () {
    setUp(() {
      // Damage-type defs keyed by enumValue, for the ability element glyph.
      when(() => manifest.allDamageTypes()).thenReturn([
        {'enumValue': 3, 'transparentIconPath': '/dmg/solar.png'},
        {'enumValue': 6, 'transparentIconPath': '/dmg/stasis.png'},
      ]);
      when(() => manifest.queryGearSummaries(GearKind.ability)).thenReturn([
        row(
            hash: 1,
            name: 'Phoenix Dive',
            itemType: 19,
            classType: 3,
            damageType: 0,
            pci: 'warlock.solar.class_abilities'),
        row(
            hash: 2,
            name: 'Ember of Torches',
            itemType: 19,
            classType: 3,
            damageType: 0,
            pci: 'shared.solar.fragments'),
        row(
            hash: 3,
            name: 'Iceflare Bolts',
            itemType: 19,
            classType: 3,
            damageType: 0,
            pci: 'hunter.stasis.totems'),
        row(
            hash: 4,
            name: 'Facet of Courage',
            itemType: 19,
            classType: 3,
            damageType: 0,
            pci: 'titan.prism.fragments'),
      ]);
    });

    test('class derives from the pci prefix', () {
      final rows = repo.listGear(const GearFilter(kind: GearKind.ability));
      final byName = {for (final r in rows) r.name: r};
      expect(byName['Phoenix Dive']!.classType, 2); // warlock
      expect(byName['Iceflare Bolts']!.classType, 1); // hunter
      expect(byName['Facet of Courage']!.classType, 0); // titan
      expect(byName['Ember of Torches']!.classType, 3); // shared → any
    });

    test('element derives from the pci element segment', () {
      final rows = repo.listGear(const GearFilter(kind: GearKind.ability));
      final byName = {for (final r in rows) r.name: r};
      expect(byName['Phoenix Dive']!.damageType, 3); // solar
      expect(byName['Iceflare Bolts']!.damageType, 6); // stasis
      // Prismatic has no single element → 0.
      expect(byName['Facet of Courage']!.damageType, 0);
    });

    test('a solar fragment gets its element glyph from the derived type', () {
      final rows = repo.listGear(const GearFilter(kind: GearKind.ability));
      final ember = rows.firstWhere((r) => r.name == 'Ember of Torches');
      expect(ember.elementIconUrl, contains('/dmg/solar.png'));
    });

    test('abilities dedupe by name (shared across subclass generations)', () {
      when(() => manifest.queryGearSummaries(GearKind.ability)).thenReturn([
        row(
            hash: 1,
            name: 'Daybreak',
            itemType: 19,
            damageType: 0,
            pci: 'warlock.solar.supers',
            index: 3),
        row(
            hash: 2,
            name: 'Daybreak',
            itemType: 19,
            damageType: 0,
            pci: 'warlock.solar.supers',
            index: 9),
      ]);
      final rows = repo.listGear(const GearFilter(kind: GearKind.ability));
      final daybreaks = rows.where((r) => r.name == 'Daybreak').toList();
      expect(daybreaks.single.itemHash, 2); // newest index kept
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

    test('minTierType drops everything below the floor (Legendary and up)', () {
      when(() => manifest.queryGearSummaries(GearKind.weapon)).thenReturn([
        row(hash: 1, name: 'RareHC', tierType: 4),
        row(hash: 2, name: 'LegendaryHC', tierType: 5),
        row(hash: 3, name: 'ExoticHC', tierType: 6),
      ]);
      final rows = repo
          .listGear(const GearFilter(kind: GearKind.weapon, minTierType: 5));
      expect(rows.map((r) => r.name).toSet(), {'LegendaryHC', 'ExoticHC'});
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
        'sourceHash': 778,
        'sourceString': 'Source: Season of the Seraph',
      });
    });

    test('resolveGearDetail exposes the manifest source when no d2ai override',
        () {
      // The shared repo has no d2ai wired → the manifest sourceString shows.
      expect(repo.resolveGearDetail(100)!.source,
          'Source: Season of the Seraph');
      expect(repo.resolveGearDetail(100)!.questOrigin, isNull);
    });

    test('resolveGearDetail lets d2ai override the source and add quest origin',
        () {
      final d2ai = _MockD2ai();
      when(() => d2ai.sourceOverrideFor(any())).thenReturn(null);
      when(() => d2ai.sourceFor(778))
          .thenReturn('Source: Complete the raid "The Best Raid"');
      when(() => d2ai.questStepFor(100)).thenReturn(950);
      when(() => manifest.getInventoryItem(950)).thenReturn({
        'displayProperties': {'name': 'The Whisper'},
      });
      final repoWithD2ai = DatabaseRepository(manifest: manifest, d2ai: d2ai);

      final detail = repoWithD2ai.resolveGearDetail(100)!;
      expect(detail.source, 'Source: Complete the raid "The Best Raid"');
      expect(detail.questOrigin, 'The Whisper');
    });

    test('a per-item override wins over d2ai, manifest, and the random-perks '
        'hide', () {
      final d2ai = _MockD2ai();
      // Our hand-authored override for item 100.
      when(() => d2ai.sourceOverrideFor(100))
          .thenReturn('Source: Found it in the Prophecy dungeon');
      when(() => d2ai.sourceFor(any())).thenReturn('d2ai text (should lose)');
      when(() => d2ai.questStepFor(any())).thenReturn(null);
      // Even if this item were a hidden random-perks item, the override shows.
      when(() => manifest.getCollectible(777)).thenReturn({
        'sourceHash': 2387628034,
        'sourceString':
            'Random Perks: This item cannot be reacquired from Collections.',
      });
      final repoWithD2ai = DatabaseRepository(manifest: manifest, d2ai: d2ai);

      expect(repoWithD2ai.resolveGearDetail(100)!.source,
          'Source: Found it in the Prophecy dungeon');
    });

    test('hides the random-perks Collections note (not a real source)', () {
      // The shared sourceHash for random-rolled world loot: its only "source"
      // is a Collections note, so no Source row should show.
      when(() => manifest.getCollectible(777)).thenReturn({
        'sourceHash': 2387628034,
        'sourceString':
            'Random Perks: This item cannot be reacquired from Collections.',
      });
      expect(repo.resolveGearDetail(100)!.source, isNull);
    });

    test('hides the vague "Earned while leveling" note', () {
      when(() => manifest.getCollectible(777)).thenReturn({
        'sourceHash': 2892963218,
        'sourceString': 'Source: Earned while leveling.',
      });
      expect(repo.resolveGearDetail(100)!.source, isNull);
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
      // No armor gear rows: the legacy name-grouping pass has nothing to add,
      // leaving only the manifest-defined set these tests assert on.
      when(() => manifest.queryGearSummaries(GearKind.armor))
          .thenReturn(const []);
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

    test('setEffectOptions lists every set-bonus name (sorted, with icon)', () {
      final options = repo.setEffectOptions();
      // Alphabetical: "Opening Act" < "Second Act".
      expect(options.map((o) => o.name), ['Opening Act', 'Second Act']);
      expect(options.first.iconPath, '/i/opening_act.png');
    });
  });

  group('armor sets — legacy name grouping', () {
    // Armor bucket for the row() helper's itemType=2 armor rows.
    const helmet = 3448274439;

    Map<String, Object?> armorRow(int hash, String name, int sub) => row(
        hash: hash,
        name: name,
        itemType: 2,
        itemSubType: sub,
        classType: 0)
      ..['bucketHash'] = helmet;

    setUp(() {
      // No manifest-defined sets — force the legacy name-grouping path.
      when(() => manifest.allEquipableItemSets()).thenReturn(const []);
    });

    test('older armor with a shared name prefix spanning 2+ slots collapses '
        'into one legacy set (cross-class same-slot variants included)', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // Bulletsmith's Ire: helm (two class variants), gauntlets, greaves.
        armorRow(1, "Bulletsmith's Ire Helm", 26),
        armorRow(2, "Bulletsmith's Ire Gauntlets", 27),
        armorRow(3, "Bulletsmith's Ire Greaves", 29),
        // A lone piece whose prefix appears on only one slot → not a set.
        armorRow(4, 'Solo Circlet', 26),
      ]);

      // All Bulletsmith's Ire pieces map to one legacy set.
      final set = repo.armorSetForItem(1);
      expect(set, isNotNull);
      expect(set!.name, "Bulletsmith's Ire");
      expect(set.isLegacy, isTrue);
      expect(set.perks, isEmpty); // legacy: no defined bonuses
      expect(set.memberHashes, containsAll([1, 2, 3]));
      expect(repo.armorSetForItem(2)!.hash, set.hash);
      expect(repo.armorSetForItem(3)!.hash, set.hash);

      // The single-slot lone piece is NOT grouped.
      expect(repo.armorSetForItem(4), isNull);
    });

    test('any trailing piece word works — the set name is name-minus-last-word '
        '(no enumerated noun list), so unusual nouns still group', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // "Guard" / "Vestment" / "Handguards" are not in any fixed noun list,
        // yet the pieces group because the set name is just the prefix.
        armorRow(30, 'Annihilating Helm', 26),
        armorRow(31, 'Annihilating Guard', 27),
        armorRow(32, 'Annihilating Vestment', 28),
        armorRow(33, 'Eidolon Pursuant Handguards', 27),
        armorRow(34, 'Eidolon Pursuant Legguards', 29),
      ]);
      expect(repo.armorSetForItem(31)!.name, 'Annihilating');
      expect(repo.armorSetForItem(31)!.memberHashes, containsAll([30, 31, 32]));
      expect(repo.armorSetForItem(33)!.name, 'Eidolon Pursuant');
      expect(repo.armorSetForItem(33)!.memberHashes, containsAll([33, 34]));
    });

    test('exotics are never grouped, even when they share a name template', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // Exotic helmets sharing "Mask of" across classes — not a set.
        armorRow(40, 'Mask of Bakris', 26)
          ..['tierType'] = 6
          ..['classType'] = 1,
        armorRow(41, 'Mask of the Quiet One', 26)
          ..['tierType'] = 6
          ..['classType'] = 0,
      ]);
      expect(repo.armorSetForItem(40), isNull);
      expect(repo.armorSetForItem(41), isNull);
    });

    test('legendary "X of [the] Y" template families are not grouped '
        '(single slot, of-template name)', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // Unrelated legendary boots sharing "Boots of" across classes.
        armorRow(50, 'Boots of Trepidation', 29)..['classType'] = 1,
        armorRow(51, 'Boots of Sekris', 29)..['classType'] = 2,
        armorRow(52, 'Boots of Detestation', 29)..['classType'] = 0,
      ]);
      expect(repo.armorSetForItem(50), isNull);
      expect(repo.armorSetForItem(51), isNull);
    });

    test('a single-slot one-piece-per-class set (Shieldbreaker Robes/Plate/'
        'Vest) groups', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // Three chest pieces (slot 28), one per class — the class-specific
        // names of a single-slot set.
        armorRow(60, 'Shieldbreaker Robes', 28)..['classType'] = 2,
        armorRow(61, 'Shieldbreaker Plate', 28)..['classType'] = 0,
        armorRow(62, 'Shieldbreaker Vest', 28)..['classType'] = 1,
      ]);
      final set = repo.armorSetForItem(60);
      expect(set, isNotNull);
      expect(set!.name, 'Shieldbreaker');
      expect(set.memberHashes, containsAll([60, 61, 62]));
    });

    test('a class-item-only set (Mark/Bond/Cloak, one per class) groups even '
        'though all three share the class-item slot', () {
      when(() => manifest.queryGearSummaries(GearKind.armor)).thenReturn([
        // "All-Star": three class items, one per character class (slot 30).
        armorRow(20, 'All-Star Mark', 30)..['classType'] = 0, // Titan
        armorRow(21, 'All-Star Bond', 30)..['classType'] = 2, // Warlock
        armorRow(22, 'All-Star Cloak', 30)..['classType'] = 1, // Hunter
        // A lone class item (single slot AND single class) is not a set.
        armorRow(23, 'Loner Cloak', 30)..['classType'] = 1,
      ]);

      final set = repo.armorSetForItem(20);
      expect(set, isNotNull);
      expect(set!.name, 'All-Star');
      expect(set.isLegacy, isTrue);
      expect(set.memberHashes, containsAll([20, 21, 22]));
      expect(repo.armorSetForItem(21)!.hash, set.hash);
      expect(repo.armorSetForItem(22)!.hash, set.hash);

      // The lone class item stays a piece (one slot, one class).
      expect(repo.armorSetForItem(23), isNull);
    });
  });
}
