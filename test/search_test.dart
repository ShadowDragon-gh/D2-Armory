import 'package:flutter_test/flutter_test.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/core/search/item_filter.dart';
import 'package:destiny2_loadout_planner/core/search/search_query.dart';
import 'package:destiny2_loadout_planner/domain/models/destiny_item.dart';

DestinyItem item({
  String name = 'Test Item',
  int itemType = 3, // weapon
  int itemSubType = 9, // hand cannon
  int tierType = 5, // legendary
  int bucketHash = 1498876634, // kinetic
  int? classType,
  int? power,
  int? damageType = 3, // solar
  bool isMasterwork = false,
  bool isLocked = false,
  bool isEquipped = false,
}) =>
    DestinyItem(
      itemHash: 1,
      bucketHash: bucketHash,
      name: name,
      iconPath: '',
      itemType: itemType,
      itemSubType: itemSubType,
      tierType: tierType,
      classType: classType,
      power: power,
      damageType: damageType,
      isMasterwork: isMasterwork,
      isLocked: isLocked,
      isEquipped: isEquipped,
    );

void main() {
  group('tokenizer', () {
    test('splits terms and respects quotes', () {
      final terms = tokenizeQuery('is:solar name:"the messenger" -is:exotic');
      expect(terms.length, 3);
      expect(terms[0].key, 'is');
      expect(terms[0].value, 'solar');
      expect(terms[1].key, 'name');
      expect(terms[1].value, 'the messenger');
      expect(terms[2].key, 'is');
      expect(terms[2].negated, isTrue);
    });

    test('not:foo becomes a negated bare keyword', () {
      final t = tokenizeQuery('not:exotic').single;
      expect(t.key, '');
      expect(t.value, 'exotic');
      expect(t.negated, isTrue);
    });
  });

  group('filters', () {
    test('is:weapon / is:armor', () {
      expect(compileQuery('is:weapon').matches(item(itemType: 3)), isTrue);
      expect(compileQuery('is:weapon').matches(item(itemType: 2)), isFalse);
      expect(compileQuery('is:armor').matches(item(itemType: 2)), isTrue);
    });

    test('is:<element> matches damage type', () {
      expect(compileQuery('is:solar').matches(item(damageType: 3)), isTrue);
      expect(compileQuery('is:void').matches(item(damageType: 3)), isFalse);
    });

    test('is:light and is:dark', () {
      expect(compileQuery('is:light').matches(item(damageType: 3)), isTrue);
      expect(compileQuery('is:dark').matches(item(damageType: 6)), isTrue);
      expect(compileQuery('is:dark').matches(item(damageType: 3)), isFalse);
    });

    test('weapon type and rarity', () {
      expect(compileQuery('is:handcannon').matches(item(itemSubType: 9)), isTrue);
      expect(compileQuery('is:bow').matches(item(itemSubType: 9)), isFalse);
      expect(compileQuery('is:legendary').matches(item(tierType: 5)), isTrue);
      expect(compileQuery('is:exotic').matches(item(tierType: 5)), isFalse);
    });

    test('equipment slot (is:kineticslot vs is:energy)', () {
      final kinetic = item(bucketHash: EquipmentBucket.kineticWeapons.hash);
      expect(compileQuery('is:kineticslot').matches(kinetic), isTrue);
      expect(compileQuery('is:energy').matches(kinetic), isFalse);
    });

    test('power comparison', () {
      expect(compileQuery('power:>540').matches(item(power: 545)), isTrue);
      expect(compileQuery('power:>540').matches(item(power: 540)), isFalse);
      expect(compileQuery('light:<=500').matches(item(power: 500)), isTrue);
      // No power → cannot match a power comparison.
      expect(compileQuery('power:>1').matches(item(power: null)), isFalse);
    });

    test('name and exactname', () {
      expect(compileQuery('name:mess').matches(item(name: 'The Messenger')),
          isTrue);
      expect(compileQuery('exactname:"the messenger"')
          .matches(item(name: 'The Messenger')), isTrue);
      expect(compileQuery('exactname:mess').matches(item(name: 'The Messenger')),
          isFalse);
    });

    test('bare keyword matches name substring', () {
      expect(compileQuery('fatebringer')
          .matches(item(name: 'Fatebringer')), isTrue);
    });

    test('multiple terms are ANDed', () {
      final q = compileQuery('is:solar is:handcannon is:legendary');
      expect(q.matches(item(damageType: 3, itemSubType: 9, tierType: 5)),
          isTrue);
      expect(q.matches(item(damageType: 4, itemSubType: 9, tierType: 5)),
          isFalse);
    });

    test('negation with - prefix', () {
      expect(compileQuery('-is:exotic').matches(item(tierType: 5)), isTrue);
      expect(compileQuery('-is:exotic').matches(item(tierType: 6)), isFalse);
    });
  });

  group('partial is: values', () {
    test('prefix ORs every keyword starting with the value', () {
      final q = compileQuery('is:s');
      // solar (damage) matches
      expect(q.matches(item(damageType: 3, itemSubType: 6)), isTrue);
      // shotgun (subtype 7) matches even if not solar
      expect(q.matches(item(damageType: 4, itemSubType: 7)), isTrue);
      // stasis (damage 6) matches
      expect(q.matches(item(damageType: 6, itemSubType: 6)), isTrue);
      // arc auto rifle: not solar, not an s-subtype -> excluded
      expect(q.matches(item(damageType: 2, itemSubType: 6)), isFalse);
    });

    test('exact keyword still wins over prefix', () {
      final q = compileQuery('is:solar');
      expect(q.matches(item(damageType: 3, itemSubType: 7)), isTrue);
      // shotgun but not solar -> excluded (exact solar, not prefix)
      expect(q.matches(item(damageType: 4, itemSubType: 7)), isFalse);
    });

    test('a partial that matches no keyword dims everything (not unsupported)',
        () {
      final q = compileQuery('is:zzz');
      expect(q.isEmpty, isFalse);
      expect(q.unsupported, isEmpty);
      expect(q.matches(item()), isFalse);
    });

    test('bare partial (no colon) still matches item name', () {
      // Per the requested behaviour: a partial typed without a colon filters as
      // a name search, not as an is: value.
      expect(compileQuery('sol').matches(item(name: 'Solar Flare')), isTrue);
      expect(compileQuery('sol').matches(item(name: 'Arc Blade')), isFalse);
    });
  });

  group('unsupported terms', () {
    test('recognized-but-unsupported filters are flagged, not applied', () {
      final q = compileQuery('is:solar stat:mobility:>20 perk:rampage');
      expect(q.unsupported, containsAll(<String>['stat:mobility:>20', 'perk:rampage']));
      // The supported is:solar term still filters.
      expect(q.matches(item(damageType: 3)), isTrue);
      expect(q.matches(item(damageType: 4)), isFalse);
    });

    test('a query of only unsupported terms is empty (matches everything)', () {
      final q = compileQuery('stat:mobility:>20');
      expect(q.isEmpty, isTrue);
      expect(q.matches(item()), isTrue);
      expect(q.unsupported, ['stat:mobility:>20']);
    });

    test('empty query is empty', () {
      expect(compileQuery('   ').isEmpty, isTrue);
    });
  });
}
