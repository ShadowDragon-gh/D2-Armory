import '../../domain/models/destiny_item.dart';
import '../destiny/destiny_buckets.dart';
import '../destiny/destiny_enums.dart';
import 'numeric_compare.dart';
import 'search_query.dart';

typedef ItemPredicate = bool Function(DestinyItem);

/// A query compiled into a single predicate plus any terms that were
/// recognized as filters but cannot be evaluated with the data loaded today.
class CompiledQuery {
  const CompiledQuery({
    required this.matches,
    required this.unsupported,
    required this.isEmpty,
  });

  /// True when [item] passes every supported term (unsupported terms ignored).
  final ItemPredicate matches;

  /// Raw text of terms that need data this app does not fetch yet.
  final List<String> unsupported;

  /// True when the query has no effective (supported, non-empty) terms.
  final bool isEmpty;

  static const CompiledQuery empty =
      CompiledQuery(matches: _always, unsupported: [], isEmpty: true);

  static bool _always(DestinyItem _) => true;
}

/// Compiles a raw search string into a [CompiledQuery].
CompiledQuery compileQuery(String raw) {
  final terms = tokenizeQuery(raw);
  if (terms.isEmpty) return CompiledQuery.empty;

  final predicates = <ItemPredicate>[];
  final unsupported = <String>[];

  for (final term in terms) {
    final predicate = _predicateFor(term);
    if (predicate == null) {
      unsupported.add(term.raw);
      continue;
    }
    predicates.add(term.negated ? (i) => !predicate(i) : predicate);
  }

  if (predicates.isEmpty) {
    return CompiledQuery(
        matches: CompiledQuery._always, unsupported: unsupported, isEmpty: true);
  }

  return CompiledQuery(
    matches: (item) => predicates.every((p) => p(item)),
    unsupported: unsupported,
    isEmpty: false,
  );
}

/// Returns the predicate for [term], or null when the filter is unknown or not
/// yet supported by the loaded data.
ItemPredicate? _predicateFor(SearchTerm term) {
  final value = term.value.toLowerCase();

  switch (term.key) {
    case '':
      // Bare keyword → substring match on name.
      if (value.isEmpty) return null;
      return (i) => i.name.toLowerCase().contains(value);

    case 'name':
      return (i) => i.name.toLowerCase().contains(value);

    case 'exactname':
      return (i) => i.name.toLowerCase() == value;

    case 'power':
    case 'light':
      final cmp = parseNumericCompare(term.value);
      if (cmp == null) return null;
      return (i) => i.power != null && cmp(i.power!);

    case 'is':
      return _isPredicate(value);

    // Recognized DIM filters that need data not loaded yet → unsupported.
    case 'stat':
    case 'basestat':
    case 'perk':
    case 'exactperk':
    case 'perkname':
    case 'source':
    case 'season':
    case 'tag':
    case 'masterwork':
    case 'count':
    case 'kills':
    case 'breaker':
    case 'foundry':
    case 'modslot':
    case 'year':
    case 'tier':
    case 'catalyst':
    case 'notes':
    case 'description':
    case 'keyword':
      return null;

    default:
      return null; // unknown key
  }
}

/// Handles `is:<value>`. An exact keyword match wins; otherwise the value is
/// treated as a prefix and every keyword that starts with it is OR-ed together
/// (so `is:s` matches solar OR shotgun OR stasis OR …). A value that matches no
/// keyword at all yields a predicate nothing satisfies (dims everything), which
/// is distinct from an unsupported/unknown filter key.
ItemPredicate? _isPredicate(String value) {
  if (value.isEmpty) return null;

  final registry = _isKeywords;

  // Exact match wins.
  final exact = registry[value];
  if (exact != null) return exact;

  // Prefix: OR every keyword starting with the typed value.
  final matches = [
    for (final entry in registry.entries)
      if (entry.key.startsWith(value)) entry.value,
  ];
  if (matches.isEmpty) return (_) => false; // real filter, nothing matches
  return (item) => matches.any((p) => p(item));
}

/// All supported `is:` keywords mapped to their predicates. Kept as a single
/// table so prefix matching can enumerate it.
final Map<String, ItemPredicate> _isKeywords = {
  'weapon': (i) => i.itemType == DestinyEnums.typeWeapon,
  'armor': (i) => i.itemType == DestinyEnums.typeArmor,
  'equipped': (i) => i.isEquipped,
  'masterwork': (i) => i.isMasterwork,
  'locked': (i) => i.isLocked,
  'unlocked': (i) => !i.isLocked,
  'light': (i) =>
      i.damageType != null && DestinyEnums.lightDamageTypes.contains(i.damageType),
  'dark': (i) =>
      i.damageType != null && DestinyEnums.darkDamageTypes.contains(i.damageType),
  // Damage types.
  for (final e in DestinyEnums.damageTypeByKeyword.entries)
    e.key: ((int dmg) => (DestinyItem i) => i.damageType == dmg)(e.value),
  // Equipment slots.
  for (final e in _bucketByKeyword.entries)
    e.key: ((EquipmentBucket b) => (DestinyItem i) => i.bucketHash == b.hash)(
        e.value),
  // Weapon types.
  for (final e in DestinyEnums.weaponSubTypeByKeyword.entries)
    e.key: ((int st) => (DestinyItem i) => i.itemSubType == st)(e.value),
  // Rarities.
  for (final e in DestinyEnums.tierByKeyword.entries)
    e.key: ((int t) => (DestinyItem i) => i.tierType == t)(e.value),
  for (final e in DestinyEnums.tierBasicByKeyword.entries)
    e.key: ((int t) => (DestinyItem i) => i.tierType == t)(e.value),
  // Class affinity.
  for (final e in DestinyEnums.classByKeyword.entries)
    e.key: ((int c) => (DestinyItem i) => i.classType == c)(e.value),
};

// Note: `is:kinetic` is the damage type (handled before this map); the kinetic
// weapon slot is `is:kineticslot`, matching DIM.
const Map<String, EquipmentBucket> _bucketByKeyword = {
  'kineticslot': EquipmentBucket.kineticWeapons,
  'energy': EquipmentBucket.energyWeapons,
  'power': EquipmentBucket.powerWeapons,
  'helmet': EquipmentBucket.helmet,
  'gauntlets': EquipmentBucket.gauntlets,
  'chest': EquipmentBucket.chestArmor,
  'leg': EquipmentBucket.legArmor,
  'legs': EquipmentBucket.legArmor,
  'classitem': EquipmentBucket.classArmor,
};

/// Complete, suggestible filter tokens for autocomplete. Each is a full term a
/// user could type (e.g. `is:solar`, `power:`). `name:`/`exactname:` are keys
/// that take free text, so only the key is offered.
List<String> get filterSuggestionCatalog => _catalog;

final List<String> _catalog = [
  for (final k in _isKeywords.keys) 'is:$k',
  'power:',
  'light:',
  'name:',
];
