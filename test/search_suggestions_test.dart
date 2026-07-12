import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/core/search/search_suggestions.dart';

void main() {
  const names = ["Winter's Guile", "Felwinter's Helm", "Fatebringer"];

  group('currentToken', () {
    test('returns the token containing the cursor and its bounds', () {
      const text = 'is:solar is:han';
      final tok = currentToken(text, text.length);
      expect(tok.token, 'is:han');
      expect(tok.start, 9);
      expect(tok.end, 15);
    });

    test('handles cursor in the middle term', () {
      const text = 'is:solar power:>540';
      final tok = currentToken(text, 4); // inside "is:solar"
      expect(tok.token, 'is:solar');
      expect(tok.start, 0);
      expect(tok.end, 8);
    });
  });

  group('suggestionsFor', () {
    test('suggests is: filter completions by prefix', () {
      final s = suggestionsFor('is:han', names).map((e) => e.insert).toList();
      expect(s, contains('is:handcannon'));
      expect(s, isNot(contains('is:solar')));
    });

    test('suggests item names as name:"..", never exactname:', () {
      final s = suggestionsFor('winter', names);
      final inserts = s.map((e) => e.insert).toList();
      expect(inserts, contains('name:"Winter\'s Guile"'));
      expect(inserts, contains('name:"Felwinter\'s Helm"'));
      expect(inserts.every((i) => !i.startsWith('exactname:')), isTrue);
    });

    test('never echoes the raw typed text as a suggestion', () {
      final s = suggestionsFor('winter', names).map((e) => e.insert).toList();
      expect(s, isNot(contains('winter')));
    });

    test('name:foo matches on the free-text portion', () {
      final s =
          suggestionsFor('name:fate', names).map((e) => e.insert).toList();
      expect(s, contains('name:"Fatebringer"'));
    });

    test('is: prefix does not produce name suggestions', () {
      final s = suggestionsFor('is:s', names);
      expect(s.every((e) => e.insert.startsWith('is:')), isTrue);
    });

    test('empty token yields no suggestions', () {
      expect(suggestionsFor('', names), isEmpty);
    });

    test('respects the max cap', () {
      final many = List.generate(50, (i) => 'Item Winter $i');
      expect(suggestionsFor('winter', many, max: 5).length, 5);
    });

    test('suggests the definition-backed filter keys (perk:, stat:, …)', () {
      expect(suggestionsFor('per', names).map((e) => e.insert),
          contains('perk:'));
      expect(suggestionsFor('desc', names).map((e) => e.insert),
          contains('description:'));
    });

    test('suggests frame:, exactname:, and ammo: on both tabs', () {
      expect(suggestionsFor('fra', names).map((e) => e.insert),
          contains('frame:'));
      // exactname: completes only when the token prefix-matches it (typing
      // "exact"), so it never displaces the name:"..." value suggestions.
      expect(suggestionsFor('exact', names).map((e) => e.insert),
          contains('exactname:'));
      final ammo = suggestionsFor('ammo', names).map((e) => e.insert);
      expect(ammo, containsAll(['ammo:primary', 'ammo:special', 'ammo:heavy']));
      // These are definition-resolvable, so the Database tab offers them too.
      expect(suggestionsFor('fra', names, instanceData: false).map((e) => e.insert),
          contains('frame:'));
      expect(suggestionsFor('ammo', names, instanceData: false).map((e) => e.insert),
          contains('ammo:heavy'));
    });

    test('bare catalyst: is offered before the state variants (live tab)', () {
      final s = suggestionsFor('catalyst', names, instanceData: true)
          .map((e) => e.insert)
          .toList();
      expect(s, contains('catalyst:'));
      // Shortest-first ordering puts the bare key ahead of catalyst:complete.
      expect(s.indexOf('catalyst:'),
          lessThan(s.indexOf('catalyst:complete')));
    });

    test('instanceData:false hides live-only filters (power/count/catalyst)',
        () {
      final dbPower = suggestionsFor('pow', names, instanceData: false)
          .map((e) => e.insert);
      expect(dbPower, isNot(contains('power:')));
      final dbCatalyst = suggestionsFor('catalyst', names, instanceData: false)
          .map((e) => e.insert);
      expect(dbCatalyst, isEmpty);
    });

    test('instanceData:true offers the live-only filters', () {
      expect(suggestionsFor('pow', names, instanceData: true).map((e) => e.insert),
          contains('power:'));
      expect(
          suggestionsFor('catalyst', names, instanceData: true)
              .map((e) => e.insert),
          contains('catalyst:complete'));
    });
  });

  group('perk value completion', () {
    const perks = [
      PerkOption('adagio', '/icon/adagio.png'),
      PerkOption('rampage', '/icon/rampage.png'),
      PerkOption('rangefinder', '/icon/rangefinder.png'),
    ];

    test('bare perk: lists every perk, quoted, with its icon', () {
      final s = suggestionsFor('perk:', names, perks: perks);
      expect(s.map((e) => e.insert), [
        'perk:"adagio"',
        'perk:"rampage"',
        'perk:"rangefinder"',
      ]);
      // The label is the unquoted, readable form; the icon is carried through.
      expect(s.first.label, 'perk:adagio');
      expect(s.first.iconPath, '/icon/adagio.png');
    });

    test('a typed value narrows to matching perks (substring)', () {
      final s = suggestionsFor('perk:ran', names, perks: perks)
          .map((e) => e.insert)
          .toList();
      expect(s, contains('perk:"rangefinder"'));
      expect(s, isNot(contains('perk:"adagio"')));
      // "ran" is a substring of rampage? no — but of rangefinder yes.
      expect(s, isNot(contains('perk:"rampage"')));
    });

    test('perk1: / perk2: complete against the same catalog, keyed', () {
      final s = suggestionsFor('perk1:ram', names, perks: perks)
          .map((e) => e.insert)
          .toList();
      expect(s, contains('perk1:"rampage"'));
      final s2 = suggestionsFor('perk2:', names, perks: perks)
          .map((e) => e.insert)
          .toList();
      expect(s2, contains('perk2:"adagio"'));
    });

    test('the inserted token quotes names so multi-word perks tokenize', () {
      const spaced = [PerkOption('aberrant combustion', '/i/ab.png')];
      final s = suggestionsFor('perk:aber', names, perks: spaced);
      expect(s.single.insert, 'perk:"aberrant combustion"');
    });

    test('perkMax caps the bare-list length', () {
      final many =
          List.generate(500, (i) => PerkOption('perk $i', '/i/$i.png'));
      expect(
          suggestionsFor('perk:', names, perks: many, perkMax: 200).length, 200);
    });

    test('an empty catalog yields no perk suggestions (warm not done)', () {
      expect(suggestionsFor('perk:', names), isEmpty);
      expect(suggestionsFor('perk:ram', names), isEmpty);
    });
  });

  group('frame value completion', () {
    const frames = [
      PerkOption('adaptive frame', '/i/adaptive.png'),
      PerkOption('rapid-fire frame', '/i/rapid.png'),
      PerkOption('precision frame', '/i/precision.png'),
    ];

    test('bare frame: lists every frame, quoted, with its icon', () {
      final s = suggestionsFor('frame:', names, frames: frames);
      expect(s.map((e) => e.insert), [
        'frame:"adaptive frame"',
        'frame:"rapid-fire frame"',
        'frame:"precision frame"',
      ]);
      expect(s.first.label, 'frame:adaptive frame');
      expect(s.first.iconPath, '/i/adaptive.png');
    });

    test('a typed value narrows to matching frames', () {
      final s = suggestionsFor('frame:rapid', names, frames: frames)
          .map((e) => e.insert)
          .toList();
      expect(s, ['frame:"rapid-fire frame"']);
    });

    test('the frame catalog is independent of the perk catalog', () {
      // Passing only perks must not leak into frame: completion, and vice versa.
      const perks = [PerkOption('rampage', '/i/r.png')];
      expect(suggestionsFor('frame:', names, perks: perks), isEmpty);
      expect(suggestionsFor('perk:', names, frames: frames), isEmpty);
    });

    test('an empty frame catalog yields no frame suggestions', () {
      expect(suggestionsFor('frame:', names), isEmpty);
      expect(suggestionsFor('frame:adapt', names), isEmpty);
    });
  });
}
