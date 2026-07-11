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
  int ammoType = 0,
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
      ammoType: ammoType,
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

    test('ammo: matches the ammunition type (no facets needed)', () {
      expect(compileQuery('ammo:heavy').matches(item(ammoType: 3)), isTrue);
      expect(compileQuery('ammo:heavy').matches(item(ammoType: 2)), isFalse);
      expect(compileQuery('ammo:special').matches(item(ammoType: 2)), isTrue);
      expect(compileQuery('ammo:primary').matches(item(ammoType: 1)), isTrue);
      // An unknown ammo value is an unknown filter (unsupported).
      expect(compileQuery('ammo:banana').unsupported, contains('ammo:banana'));
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

  group('facet filters (stat / perk / source / breaker)', () {
    // A resolver mapping a single item hash to fixed facets, standing in for
    // the Database tab's precomputed per-item facet index.
    FacetResolver facets(SearchFacets f) => (_) => f;

    final sample = const SearchFacets(
      perks: {'rampage', 'kill clip', 'enhanced rampage'},
      perkColumns: [
        {'outlaw', 'rapid hit'}, // perk 1
        {'rampage', 'kill clip'}, // perk 2
      ],
      stats: {'mobility': 40, 'range': 65, 'reload speed': 30},
      breaker: 'unstoppable',
      sources: {'source: season of the seraph'},
      description: 'a hand cannon forged in the light of the traveler',
      catalyst: CatalystState.incomplete,
      frame: 'adaptive frame',
    );

    test('perk: matches any candidate perk (substring), else excludes', () {
      final q = compileQuery('perk:rampage', facetsOf: facets(sample));
      expect(q.unsupported, isEmpty);
      expect(q.matches(item()), isTrue);
      expect(
          compileQuery('perk:mulligan', facetsOf: facets(sample))
              .matches(item()),
          isFalse);
    });

    test('perk1:/perk2: match only their own trait column', () {
      // outlaw is in column 1 (perk1), not column 2 (perk2).
      expect(compileQuery('perk1:outlaw', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('perk2:outlaw', facetsOf: facets(sample))
          .matches(item()), isFalse);
      // kill clip is in column 2 (perk2), not column 1.
      expect(compileQuery('perk2:kill', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('perk1:kill', facetsOf: facets(sample))
          .matches(item()), isFalse);
      // A weapon with no trait columns never matches perk1:/perk2:.
      final noColumns = const SearchFacets(perks: {'outlaw'});
      expect(compileQuery('perk1:outlaw', facetsOf: facets(noColumns))
          .matches(item()), isFalse);
    });

    test('frame: matches the intrinsic frame (substring), else excludes', () {
      expect(compileQuery('frame:adaptive', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('frame:"adaptive frame"', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('frame:rapid', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('frame: is unsupported when facets are unavailable', () {
      final q = compileQuery('frame:adaptive'); // no facetsOf
      expect(q.unsupported, contains('frame:adaptive'));
    });

    test('stat: with comparison matches on value', () {
      expect(compileQuery('stat:range:>60', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('stat:range:>70', facetsOf: facets(sample))
          .matches(item()), isFalse);
      expect(compileQuery('stat:mobility:<=40', facetsOf: facets(sample))
          .matches(item()), isTrue);
    });

    test('stat: without comparison is a presence check', () {
      expect(compileQuery('stat:mobility', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('stat:handling', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('stat: with a malformed comparison is unsupported', () {
      final q = compileQuery('stat:range:abc', facetsOf: facets(sample));
      expect(q.unsupported, ['stat:range:abc']);
      expect(q.isEmpty, isTrue);
    });

    test('source: matches a source-string substring', () {
      expect(compileQuery('source:seraph', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('source:raid', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('breaker: matches the intrinsic breaker name', () {
      expect(compileQuery('breaker:unstoppable', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('breaker:overload', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('description: matches description-text substring', () {
      expect(compileQuery('description:traveler', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('description:"the light"', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('description:shadow', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('keyword: matches across name, description, and perks', () {
      // name hit
      expect(compileQuery('keyword:messenger', facetsOf: facets(sample))
          .matches(item(name: 'The Messenger')), isTrue);
      // description hit
      expect(compileQuery('keyword:traveler', facetsOf: facets(sample))
          .matches(item(name: 'Nope')), isTrue);
      // perk hit
      expect(compileQuery('keyword:rampage', facetsOf: facets(sample))
          .matches(item(name: 'Nope')), isTrue);
      // none of the three
      expect(compileQuery('keyword:zzz', facetsOf: facets(sample))
          .matches(item(name: 'Nope')), isFalse);
    });

    test('catalyst: matches the unlock state', () {
      // sample has catalyst: incomplete.
      expect(compileQuery('catalyst:incomplete', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('catalyst:complete', facetsOf: facets(sample))
          .matches(item()), isFalse);
      // unlocked is an alias for complete.
      expect(compileQuery('catalyst:unlocked',
              facetsOf: facets(const SearchFacets(catalyst: CatalystState.complete)))
          .matches(item()), isTrue);
      // missing.
      expect(compileQuery('catalyst:missing',
              facetsOf: facets(const SearchFacets(catalyst: CatalystState.missing)))
          .matches(item()), isTrue);
    });

    test('bare catalyst: matches any item that has a catalyst', () {
      expect(compileQuery('catalyst:', facetsOf: facets(sample))
          .matches(item()), isTrue);
      // No catalyst record → no match.
      expect(compileQuery('catalyst:', facetsOf: facets(const SearchFacets()))
          .matches(item()), isFalse);
    });

    test('catalyst: with an unrecognized state word is unsupported', () {
      final q = compileQuery('catalyst:sometimes', facetsOf: facets(sample));
      expect(q.unsupported, ['catalyst:sometimes']);
    });

    test('negation applies to facet filters', () {
      expect(compileQuery('-perk:outlaw', facetsOf: facets(sample))
          .matches(item()), isTrue);
      expect(compileQuery('-perk:rampage', facetsOf: facets(sample))
          .matches(item()), isFalse);
    });

    test('an item with no facets never matches a facet filter', () {
      // Resolver returns null (facets unavailable for this item), distinct from
      // the whole-tab null resolver: the term is supported but matches nothing.
      final q = compileQuery('perk:rampage', facetsOf: (_) => null);
      expect(q.unsupported, isEmpty);
      expect(q.matches(item()), isFalse);
    });

    test('facet filters compose with is: facets via AND', () {
      final q = compileQuery('is:exotic breaker:unstoppable',
          facetsOf: facets(sample));
      expect(q.matches(item(tierType: 6)), isTrue);
      expect(q.matches(item(tierType: 5)), isFalse); // fails is:exotic
    });
  });

  group('count filter (inventory)', () {
    // A count resolver standing in for the account-owned tally.
    CountResolver owned(int n) => (_) => n;

    test('count: matches on the owned copy count', () {
      expect(compileQuery('count:>1', countOf: owned(3)).matches(item()),
          isTrue);
      expect(compileQuery('count:>1', countOf: owned(1)).matches(item()),
          isFalse);
      expect(compileQuery('count:1', countOf: owned(1)).matches(item()),
          isTrue);
    });

    test('count: is unsupported without a count resolver (Database tab)', () {
      final q = compileQuery('count:>1');
      expect(q.unsupported, ['count:>1']);
      expect(q.isEmpty, isTrue);
    });

    test('count: with a malformed value is unsupported', () {
      final q = compileQuery('count:abc', countOf: owned(2));
      expect(q.unsupported, ['count:abc']);
    });
  });

  group('unsupported terms', () {
    test('facet + count filters are unsupported when no resolver is supplied',
        () {
      // The inventory tab passes no facetsOf (so the definition filters route
      // to unsupported); the Database tab passes no countOf.
      final q = compileQuery('is:solar stat:mobility:>20 perk:rampage '
          'source:seraph breaker:overload description:foo keyword:bar '
          'count:>1');
      expect(
          q.unsupported,
          containsAll(<String>[
            'stat:mobility:>20',
            'perk:rampage',
            'source:seraph',
            'breaker:overload',
            'description:foo',
            'keyword:bar',
            'count:>1',
          ]));
      // The supported is:solar term still filters.
      expect(q.matches(item(damageType: 3)), isTrue);
      expect(q.matches(item(damageType: 4)), isFalse);
    });

    test('removed DIM filter keys are treated as unsupported', () {
      final q = compileQuery('is:solar season:22 tag:favorite masterwork:range '
          'kills:100 foundry:hakke modslot:artifact year:7 tier:10 notes:pvp');
      expect(
          q.unsupported,
          containsAll(<String>[
            'season:22',
            'tag:favorite',
            'masterwork:range',
            'kills:100',
            'foundry:hakke',
            'modslot:artifact',
            'year:7',
            'tier:10',
            'notes:pvp',
          ]));
      // The supported term still filters — the query is not empty.
      expect(q.isEmpty, isFalse);
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

  group('instanceDataAvailable=false (Database tab)', () {
    test('instance-only terms are flagged unsupported, not silently empty', () {
      final q = compileQuery('is:exotic is:masterwork power:>500 is:equipped',
          instanceDataAvailable: false);
      expect(q.unsupported,
          containsAll(<String>['is:masterwork', 'power:>500', 'is:equipped']));
      // The definition-applicable term still filters.
      expect(q.matches(item(tierType: 6)), isTrue);
      expect(q.matches(item(tierType: 5)), isFalse);
    });

    test('definition facets still work (element, type, rarity, class)', () {
      final q = compileQuery('is:solar is:handcannon is:exotic',
          instanceDataAvailable: false);
      expect(q.unsupported, isEmpty);
      expect(
          q.matches(item(damageType: 3, itemSubType: 9, tierType: 6)), isTrue);
    });

    test('the same instance-only terms DO apply when data is available', () {
      final q = compileQuery('is:masterwork', instanceDataAvailable: true);
      expect(q.unsupported, isEmpty);
      expect(q.matches(item(isMasterwork: true)), isTrue);
    });
  });
}
