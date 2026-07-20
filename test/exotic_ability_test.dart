import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/data/repositories/exotic_ability_repository.dart';
import 'package:d2_armory/data/repositories/manifest_repository.dart';
import 'package:d2_armory/domain/models/exotic_ability_interaction.dart';

class _MockManifest extends Mock implements ManifestRepository {}

void main() {
  group('AbilityKind.fromPlugCategory', () {
    // The join key between a subclass socket and the curated map: the ability
    // suffix of the plug category identifier, class/element-agnostic.
    test('maps each ability suffix to its kind', () {
      expect(AbilityKind.fromPlugCategory('shared.solar.grenades'),
          AbilityKind.grenade);
      expect(AbilityKind.fromPlugCategory('warlock.solar.melee'),
          AbilityKind.melee);
      expect(AbilityKind.fromPlugCategory('hunter.void.supers'),
          AbilityKind.superAbility);
      expect(AbilityKind.fromPlugCategory('titan.shared.class_abilities'),
          AbilityKind.classAbility);
      // Movement folds into the class-ability slot.
      expect(AbilityKind.fromPlugCategory('titan.shared.movement'),
          AbilityKind.classAbility);
      expect(AbilityKind.fromPlugCategory('warlock.stasis.aspects'),
          AbilityKind.aspect);
      // Stasis's pre-3.0 aspect naming.
      expect(AbilityKind.fromPlugCategory('warlock.stasis.totems'),
          AbilityKind.aspect);
    });

    test('returns null for fragments and unrecognised categories', () {
      // Fragments are not a badged ability kind.
      expect(AbilityKind.fromPlugCategory('warlock.stasis.fragments'), isNull);
      expect(AbilityKind.fromPlugCategory('warlock.stasis.trinkets'), isNull);
      expect(AbilityKind.fromPlugCategory('v400.weapon.mod_magazine'), isNull);
      expect(AbilityKind.fromPlugCategory(''), isNull);
      expect(AbilityKind.fromPlugCategory(null), isNull);
    });
  });

  group('AbilityKind.fromToken', () {
    test('round-trips every token', () {
      for (final kind in AbilityKind.values) {
        expect(AbilityKind.fromToken(kind.token), kind);
      }
    });

    test('returns null for an unknown token', () {
      expect(AbilityKind.fromToken('fragment'), isNull);
      expect(AbilityKind.fromToken(''), isNull);
    });
  });

  group('ExoticAbilityInteraction.matchesClass', () {
    const titanExotic = ExoticAbilityInteraction(
      itemHash: 1,
      name: 'Heart of Inmost Light',
      classType: 0,
      interactions: [AbilityInteraction(kind: AbilityKind.grenade)],
    );
    const anyClassExotic = ExoticAbilityInteraction(
      itemHash: 2,
      name: 'Class-agnostic',
      classType: 3,
      interactions: [AbilityInteraction(kind: AbilityKind.melee)],
    );

    test('a class-specific exotic matches only its own class', () {
      expect(titanExotic.matchesClass(0), isTrue); // Titan
      expect(titanExotic.matchesClass(1), isFalse); // Hunter
      expect(titanExotic.matchesClass(2), isFalse); // Warlock
    });

    test('a class-agnostic exotic matches every class', () {
      expect(anyClassExotic.matchesClass(0), isTrue);
      expect(anyClassExotic.matchesClass(1), isTrue);
      expect(anyClassExotic.matchesClass(2), isTrue);
    });
  });

  group('AbilityInteraction name-scoped vs general', () {
    // element: Arc=2 Solar=3 Void=4 Stasis=6 Strand=7.
    test('a type-level interaction is general, never name-scoped', () {
      const i = AbilityInteraction(kind: AbilityKind.grenade);
      expect(i.isNameScoped, isFalse);
      // General match: any grenade of any element.
      expect(i.matchesGeneral(AbilityKind.grenade, 4), isTrue);
      expect(i.matchesGeneral(AbilityKind.melee, 4), isFalse); // wrong kind
      // Never earns a name badge.
      expect(
          i.matchesNamedSocket(AbilityKind.grenade, ['Vortex Grenade'], 4),
          isFalse);
    });

    test('a name-scoped interaction badges only on a matching plug name', () {
      const i = AbilityInteraction(
          kind: AbilityKind.superAbility, names: ["Winter's Wrath"]);
      expect(i.isNameScoped, isTrue);
      // Named socket match: the buffed super is an option here.
      expect(
          i.matchesNamedSocket(AbilityKind.superAbility,
              ['Silence and Squall', "Winter's Wrath"], 6),
          isTrue);
      // A super socket without Winter's Wrath does not match.
      expect(
          i.matchesNamedSocket(AbilityKind.superAbility, ['Daybreak'], 3),
          isFalse);
      // A name-scoped interaction is NOT general — never in the right column.
      expect(i.matchesGeneral(AbilityKind.superAbility, 6), isFalse);
    });

    test('name match is case-insensitive', () {
      const i =
          AbilityInteraction(kind: AbilityKind.aspect, names: ['Frostpulse']);
      expect(i.matchesNamedSocket(AbilityKind.aspect, ['FROSTPULSE'], 6), isTrue);
    });

    test('an element-gated interaction is general, scoped to its element', () {
      const i = AbilityInteraction(kind: AbilityKind.grenade, element: 2); // Arc
      expect(i.isNameScoped, isFalse);
      expect(i.matchesGeneral(AbilityKind.grenade, 2), isTrue); // Arc
      expect(i.matchesGeneral(AbilityKind.grenade, 4), isFalse); // Void
    });
  });

  group('ExoticAbilityRepository', () {
    // Loads the real bundled asset so a malformed/renamed map fails the build,
    // and verifies the class filter and inverse-index query.
    TestWidgetsFlutterBinding.ensureInitialized();

    late _MockManifest manifest;
    late ExoticAbilityRepository repo;

    setUp(() async {
      manifest = _MockManifest();
      // No icons in the test: the map still loads and queries by class/ability.
      when(() => manifest.getInventoryItem(any())).thenReturn(null);
      repo = ExoticAbilityRepository(manifest: manifest);
      await repo.ensureLoaded();
    });

    test('loads the bundled map', () {
      expect(repo.isReady, isTrue);
    });

    // General grenade exotics (type-level + element-matching) for a class, on a
    // Solar (3) subclass — the right-column query.
    List<ExoticAbilityInteraction> generalGrenades(int classType) =>
        repo.generalExoticsFor(AbilityKind.grenade, classType, 3);

    test('generalExoticsFor returns only exotics of the queried class', () {
      final titanGrenade = generalGrenades(0);
      final warlockGrenade = generalGrenades(2);

      expect(titanGrenade, isNotEmpty);
      expect(warlockGrenade, isNotEmpty);
      // Every returned exotic is wearable by the queried class.
      expect(titanGrenade.every((e) => e.matchesClass(0)), isTrue);
      expect(warlockGrenade.every((e) => e.matchesClass(2)), isTrue);
      // A known Titan grenade exotic surfaces for Titan, not for Warlock.
      const armamentarium = 2999866952; // Armamentarium (extra grenade charge)
      expect(titanGrenade.any((e) => e.itemHash == armamentarium), isTrue);
      expect(warlockGrenade.any((e) => e.itemHash == armamentarium), isFalse);
    });

    test('a multi-kind general exotic is a synergy piece, not per-kind', () {
      // Heart of Inmost Light is general across grenade, melee, and class
      // ability (3 kinds) → it belongs in the synergy section, listed once, and
      // is EXCLUDED from each per-kind general column (no duplication).
      const heartOfInmostLight = 502173648;
      final synergy = repo.synergyExoticsFor(0, 3); // Titan
      expect(synergy.where((e) => e.itemHash == heartOfInmostLight).length, 1);
      for (final kind in [
        AbilityKind.grenade,
        AbilityKind.melee,
        AbilityKind.classAbility,
      ]) {
        expect(
            repo
                .generalExoticsFor(kind, 0, 3)
                .any((e) => e.itemHash == heartOfInmostLight),
            isFalse,
            reason: 'HoIL should not repeat under $kind');
      }
      // And it is NEVER badged on a specific ability (no name scoping).
      expect(
          repo
              .exoticsFor(AbilityKind.grenade, 0, 3, const ['Vortex Grenade'])
              .any((e) => e.itemHash == heartOfInmostLight),
          isFalse);
    });

    test('a single-kind general exotic stays a per-kind row, not synergy', () {
      // Armamentarium buffs only grenades (one general kind) → it stays in the
      // Grenade column and is NOT a synergy piece.
      const armamentarium = 2999866952;
      expect(
          repo
              .generalExoticsFor(AbilityKind.grenade, 0, 3)
              .any((e) => e.itemHash == armamentarium),
          isTrue);
      expect(
          repo.synergyExoticsFor(0, 3).any((e) => e.itemHash == armamentarium),
          isFalse);
    });

    test('a name-scoped exotic badges only on its named ability', () {
      // Ballidorse Wrathweavers (Warlock) buffs the Winter's Wrath super — it
      // must badge a super socket offering Winter's Wrath, but NOT one offering
      // only Daybreak, even though both are Warlock super sockets.
      const ballidorse = 3831935023;
      final onWintersWrath = repo.exoticsFor(
          AbilityKind.superAbility, 2, 6, const ["Winter's Wrath"]);
      final onDaybreak = repo.exoticsFor(
          AbilityKind.superAbility, 2, 3, const ['Daybreak']);
      expect(onWintersWrath.any((e) => e.itemHash == ballidorse), isTrue);
      expect(onDaybreak.any((e) => e.itemHash == ballidorse), isFalse);
      // It must NOT badge a generic class-ability socket (the over-broad token
      // removed in curation)…
      final onRift = repo.exoticsFor(
          AbilityKind.classAbility, 2, 6, const ['Healing Rift']);
      expect(onRift.any((e) => e.itemHash == ballidorse), isFalse);
      // …and, being name-scoped, it must NOT appear in the general super column.
      expect(
          repo
              .generalExoticsFor(AbilityKind.superAbility, 2, 6)
              .any((e) => e.itemHash == ballidorse),
          isFalse);
    });

    test('an element-gated multi-kind exotic is synergy only on its element', () {
      // Crown of Tempests (Warlock) buffs Arc grenade/melee/super → on an Arc
      // subclass it is a synergy piece (2+ general kinds); on a Void subclass
      // its element-gated interactions don't match, so it is neither synergy nor
      // in any column. Its named aspect (Ionic Sentry) is separate.
      const crown = 925466718;
      final arcSynergy = repo.synergyExoticsFor(2, 2); // Arc
      final voidSynergy = repo.synergyExoticsFor(2, 4); // Void
      expect(arcSynergy.any((e) => e.itemHash == crown), isTrue);
      expect(voidSynergy.any((e) => e.itemHash == crown), isFalse);
      // Being synergy on Arc, it does NOT repeat in the per-kind grenade column.
      expect(
          repo
              .generalExoticsFor(AbilityKind.grenade, 2, 2)
              .any((e) => e.itemHash == crown),
          isFalse);
      // Its named aspect still badges the Ionic Sentry aspect socket.
      expect(
          repo
              .exoticsFor(AbilityKind.aspect, 2, 2, const ['Ionic Sentry'])
              .any((e) => e.itemHash == crown),
          isTrue);
    });

    test('namedColumnExoticsFor lists name-scoped exotics with matched names',
        () {
      // Geomag Stabilizers (Warlock) → Chaos Reach. In a super socket that can
      // hold Chaos Reach, it lists in the Super column paired with that name —
      // regardless of what's equipped (a discovery listing, not the badge).
      const geomag = 121305948; // Geomag Stabilizers
      final rows = repo.namedColumnExoticsFor(
        AbilityKind.superAbility,
        2, // Warlock
        2, // Arc
        const ['Stormtrance', 'Chaos Reach'], // socket options
      );
      final geomagRow =
          rows.where((r) => r.exotic.itemHash == geomag).firstOrNull;
      expect(geomagRow, isNotNull);
      expect(geomagRow!.names, contains('Chaos Reach'));

      // A super socket that can't hold Chaos Reach does not list it.
      final without = repo.namedColumnExoticsFor(
          AbilityKind.superAbility, 2, 3, const ['Daybreak', 'Well of Radiance']);
      expect(without.any((r) => r.exotic.itemHash == geomag), isFalse);
    });

    test('returns empty for an ability with no interactions of that class', () {
      // No unmatched crash for a class with no movement exotics, etc.
      final result =
          repo.exoticsFor(AbilityKind.movement, 0, 3, const ['Strafe Jump']);
      expect(result.every((e) => e.matchesClass(0)), isTrue);
    });

    test('resolves the intrinsic from the intrinsics socket only', () async {
      // The intrinsic perk lives in the socket whose initial plug is
      // intrinsics-classed (often an empty-named placeholder, with the named
      // perk in that socket's plug set). Other sockets' plug sets hold every
      // armor mod/shader/ornament — thousands of definitions — so resolving
      // must never fetch them: doing so froze the app on load.
      const armamentarium = 2999866952;
      const modSocketSet = 900; // huge mod plug set: must never be fetched
      const intrinsicSet = 901;
      final gatedManifest = _MockManifest();
      when(() => gatedManifest.getInventoryItem(any())).thenReturn(null);
      when(() => gatedManifest.getInventoryItem(armamentarium)).thenReturn({
        'displayProperties': {'icon': '/armamentarium.jpg'},
        'sockets': {
          'socketEntries': [
            {
              'singleInitialItemHash': 111,
              'reusablePlugSetHash': modSocketSet,
            },
            {
              'singleInitialItemHash': 222,
              'reusablePlugSetHash': intrinsicSet,
            },
          ],
        },
      });
      when(() => gatedManifest.getInventoryItem(111)).thenReturn({
        'displayProperties': {'name': 'Empty Mod Socket'},
        'plug': {'plugCategoryIdentifier': 'enhancements.v2_general'},
      });
      when(() => gatedManifest.getInventoryItem(222)).thenReturn({
        'displayProperties': {'name': ''},
        'plug': {'plugCategoryIdentifier': 'intrinsics'},
      });
      when(() => gatedManifest.getPlugSet(intrinsicSet)).thenReturn({
        'reusablePlugItems': [
          {'plugItemHash': 333},
        ],
      });
      when(() => gatedManifest.getInventoryItem(333)).thenReturn({
        'hash': 333,
        'displayProperties': {
          'name': 'And Another Thing',
          'description': 'Carry an additional grenade charge.',
        },
        'plug': {'plugCategoryIdentifier': 'intrinsics'},
      });

      final gatedRepo = ExoticAbilityRepository(manifest: gatedManifest);
      await gatedRepo.ensureLoaded();
      final entry = gatedRepo
          .generalExoticsFor(AbilityKind.grenade, 0, 3)
          .firstWhere((e) => e.itemHash == armamentarium);
      expect(entry.iconPath, '/armamentarium.jpg');
      expect(entry.perkHash, 333);
      expect(entry.description, 'Carry an additional grenade charge.');
      verifyNever(() => gatedManifest.getPlugSet(modSocketSet));
    });
  });
}
