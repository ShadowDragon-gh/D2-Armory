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
  });
}
