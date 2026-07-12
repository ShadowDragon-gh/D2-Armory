import '../../domain/models/destiny_item.dart';
import '../destiny/destiny_buckets.dart';
import '../destiny/destiny_enums.dart';
import 'numeric_compare.dart';
import 'search_query.dart';

typedef ItemPredicate = bool Function(DestinyItem);

/// The unlock state of an item's exotic catalyst. Only resolvable with live
/// account data (the inventory tab), so the Database tab always leaves
/// [SearchFacets.catalyst] null even for exotics that have a catalyst.
enum CatalystState {
  /// Owned and fully unlocked.
  complete,

  /// Owned but objectives not yet finished.
  incomplete,

  /// The item has a catalyst that the player has not obtained.
  missing,
}

/// The facets a [DestinyItem] can be searched by when the caller can supply
/// them. Both tabs supply these now: the Database tab resolves them from the
/// manifest definition; the inventory tab resolves them from the live instance's
/// sockets/stats plus its account records (which alone carry [catalyst] state).
/// All string fields are pre-lowercased for case-insensitive matching.
class SearchFacets {
  const SearchFacets({
    this.perks = const {},
    this.perkColumns = const [],
    this.stats = const {},
    this.breaker,
    this.sources = const {},
    this.description = '',
    this.catalyst,
    this.frame,
  });

  /// Every candidate perk/trait plug name for the item (the full random-roll
  /// pool on a definition; the socketed perks on a live instance), lowercased.
  /// `perk:` matches across all of these.
  final Set<String> perks;

  /// The candidate perk names for each random *trait* column, in column order —
  /// the two columns players call "perk 1" and "perk 2". `perk1:`/`perk2:` match
  /// the first/second entry. Empty for items without random trait columns
  /// (armor, most exotics). Lowercased.
  final List<Set<String>> perkColumns;

  /// The item's intrinsic frame name (e.g. `rapid-fire frame`), lowercased, or
  /// null when it has none. For weapons this is the archetype; for armor it is
  /// the exotic intrinsic perk.
  final String? frame;

  /// Stat display-name → value (e.g. `{'mobility': 40}`), names lowercased.
  final Map<String, int> stats;

  /// The item's champion breaker name (e.g. `unstoppable`), or null when none.
  final String? breaker;

  /// The item's source strings (e.g. `source: season of the seraph`),
  /// lowercased. A set because reissues can carry more than one.
  final Set<String> sources;

  /// The item's flavor/description text, lowercased. Empty when it has none.
  final String description;

  /// The catalyst unlock state, or null when the item has no catalyst (or the
  /// state is unknown — e.g. the Database tab, which has no account data).
  final CatalystState? catalyst;
}

/// Resolves the [SearchFacets] for an item, or null when facets are unavailable
/// for it. Passed to [compileQuery] by callers that can supply definition data.
typedef FacetResolver = SearchFacets? Function(DestinyItem);

/// Resolves how many copies of an item the account owns, for `count:`. Passed
/// to [compileQuery] by the inventory (which alone knows account holdings);
/// null on the Database tab, where a definition list has no ownership.
typedef CountResolver = int Function(DestinyItem);

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
///
/// [instanceDataAvailable] is true for the inventory (items carry live instance
/// data: power, equipped, masterwork, locked). The Database tab filters
/// *definitions*, which have none of that, so it passes false: terms that need
/// instance data are routed to [CompiledQuery.unsupported] (flagged, ignored)
/// instead of silently matching nothing.
///
/// [facetsOf] supplies definition-sourced [SearchFacets] (perks, stats, breaker,
/// source, description) so the `stat:` / `perk:` / `source:` / `breaker:` /
/// `description:` / `keyword:` filters can be evaluated. When null (the inventory
/// tab, which has no such data loaded) those filters route to
/// [CompiledQuery.unsupported] like any other unavailable term.
///
/// [countOf] supplies the account-owned copy count for `count:`. Only the
/// inventory knows ownership, so the Database tab passes null and `count:`
/// routes to unsupported there.
CompiledQuery compileQuery(
  String raw, {
  bool instanceDataAvailable = true,
  FacetResolver? facetsOf,
  CountResolver? countOf,
}) {
  final terms = tokenizeQuery(raw);
  if (terms.isEmpty) return CompiledQuery.empty;

  final predicates = <ItemPredicate>[];
  final unsupported = <String>[];

  for (final term in terms) {
    if (!instanceDataAvailable && _needsInstanceData(term)) {
      unsupported.add(term.raw);
      continue;
    }
    final predicate = _predicateFor(term, facetsOf, countOf);
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

/// Whether [term] needs live instance data (so it cannot apply to a bare
/// definition). Covers the power/light numeric compares and the `is:` state
/// keywords equipped / masterwork / locked. Only the exact `is:` value is
/// treated as instance-only; a prefix like `is:e` also matches definition
/// facets (energy), so it is left to the normal predicate path.
bool _needsInstanceData(SearchTerm term) {
  if (term.key == 'power' || term.key == 'light' || term.key == 'tier') {
    return true;
  }
  if (term.key == 'is') {
    const instanceIsKeywords = {'equipped', 'masterwork', 'locked'};
    return instanceIsKeywords.contains(term.value.toLowerCase());
  }
  return false;
}

/// Returns the predicate for [term], or null when the filter is unknown or not
/// yet supported by the loaded data. [facetsOf] enables the definition-backed
/// filters (`stat:` / `perk:` / `source:` / `breaker:` / `description:` /
/// `keyword:`); [countOf] enables `count:`. When a resolver is null its filters
/// remain unsupported.
ItemPredicate? _predicateFor(
    SearchTerm term, FacetResolver? facetsOf, CountResolver? countOf) {
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

    case 'tier':
      // Gear tier (0-5) from the instance; `tier:4`, `tier:>2`, `tier:>=3`, …
      final cmp = parseNumericCompare(term.value);
      if (cmp == null) return null;
      return (i) => cmp(i.gearTier);

    case 'is':
      return _isPredicate(value);

    case 'ammo':
      return _ammoPredicate(value);

    case 'stat':
      return _statPredicate(term.value, facetsOf);
    case 'perk':
      return _perkPredicate(value, facetsOf);
    case 'perk1':
      return _perkColumnPredicate(value, facetsOf, 0);
    case 'perk2':
      return _perkColumnPredicate(value, facetsOf, 1);
    case 'frame':
      return _framePredicate(value, facetsOf);
    case 'source':
      return _sourcePredicate(value, facetsOf);
    case 'breaker':
      return _breakerPredicate(value, facetsOf);
    case 'description':
      return _descriptionPredicate(value, facetsOf);
    case 'keyword':
      return _keywordPredicate(value, facetsOf);
    case 'catalyst':
      return _catalystPredicate(value, facetsOf);
    case 'count':
      return _countPredicate(term.value, countOf);

    default:
      return null; // unknown or not-yet-supported key
  }
}

/// `ammo:<primary|special|heavy>` — matches the weapon's ammunition type.
/// Resolved from [DestinyItem.ammoType] directly (no facet), so it works on
/// both tabs. Null (unknown) when the value is not an ammo name.
ItemPredicate? _ammoPredicate(String value) {
  const byKeyword = {'primary': 1, 'special': 2, 'heavy': 3};
  final ammo = byKeyword[value];
  if (ammo == null) return null;
  return (i) => i.ammoType == ammo;
}

/// `stat:<name>:<compare>` — e.g. `stat:mobility:>20`. Matches when the item has
/// a stat whose name contains [rawValue]'s name part and whose value satisfies
/// the comparison. A bare `stat:mobility` (no comparison) matches any item that
/// has that stat at all. Null (unsupported) when facets are unavailable or the
/// syntax is malformed.
ItemPredicate? _statPredicate(String rawValue, FacetResolver? facetsOf) {
  if (facetsOf == null) return null;
  final colon = rawValue.lastIndexOf(':');
  final String statName;
  final bool Function(int)? cmp;
  if (colon <= 0) {
    // No comparison → presence check.
    statName = rawValue.toLowerCase();
    cmp = null;
  } else {
    statName = rawValue.substring(0, colon).toLowerCase();
    cmp = parseNumericCompare(rawValue.substring(colon + 1));
    if (cmp == null) return null; // malformed comparison
  }
  if (statName.isEmpty) return null;
  return (item) {
    final facets = facetsOf(item);
    if (facets == null) return false;
    for (final entry in facets.stats.entries) {
      if (!entry.key.contains(statName)) continue;
      if (cmp == null || cmp(entry.value)) return true;
    }
    return false;
  };
}

/// `perk:<name>` — matches when any of the item's candidate perks' names
/// contains [value] (the full random-roll pool, so a legendary matches on any
/// perk it *can* roll). Null (unsupported) when facets are unavailable.
ItemPredicate? _perkPredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final facets = facetsOf(item);
    if (facets == null) return false;
    return facets.perks.any((p) => p.contains(value));
  };
}

/// `perk1:<name>` / `perk2:<name>` — matches when a candidate perk in the
/// item's [column]-th random *trait* column (0 = perk 1, 1 = perk 2) contains
/// [value]. An item without that trait column (armor, most exotics) never
/// matches. Null (unsupported) when facets are unavailable.
ItemPredicate? _perkColumnPredicate(
    String value, FacetResolver? facetsOf, int column) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final columns = facetsOf(item)?.perkColumns;
    if (columns == null || column >= columns.length) return false;
    return columns[column].any((p) => p.contains(value));
  };
}

/// `frame:<name>` — matches when the item's intrinsic frame name contains
/// [value] (e.g. `frame:adaptive`, `frame:rapid`). Null (unsupported) when
/// facets are unavailable.
ItemPredicate? _framePredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final frame = facetsOf(item)?.frame;
    return frame != null && frame.contains(value);
  };
}

/// `source:<keyword>` — matches when any of the item's source strings contains
/// [value] (e.g. `source:seraph`, `source:raid`). Null (unsupported) when
/// facets are unavailable.
ItemPredicate? _sourcePredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final facets = facetsOf(item);
    if (facets == null) return false;
    return facets.sources.any((s) => s.contains(value));
  };
}

/// `breaker:<name>` — matches when the item's champion breaker name contains
/// [value] (e.g. `breaker:overload`). Null (unsupported) when facets are
/// unavailable. Only intrinsic breakers (exotics) are resolvable from the
/// definition; frame-granted legendary breakers are not.
ItemPredicate? _breakerPredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final breaker = facetsOf(item)?.breaker;
    return breaker != null && breaker.contains(value);
  };
}

/// `description:<text>` — matches when the item's flavor/description text
/// contains [value]. Null (unsupported) when facets are unavailable.
ItemPredicate? _descriptionPredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    final facets = facetsOf(item);
    return facets != null && facets.description.contains(value);
  };
}

/// `keyword:<text>` — a broad match: the item's name, description, or any of
/// its candidate perk names contains [value]. Null (unsupported) when facets
/// are unavailable.
ItemPredicate? _keywordPredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null || value.isEmpty) return null;
  return (item) {
    if (item.name.toLowerCase().contains(value)) return true;
    final facets = facetsOf(item);
    if (facets == null) return false;
    return facets.description.contains(value) ||
        facets.perks.any((p) => p.contains(value));
  };
}

/// `catalyst:<state>` — matches on the item's catalyst unlock state, which is
/// only known with account data (the inventory tab). Bare `catalyst:` (or
/// `catalyst:yes`/`has`) matches any item that has a catalyst at all;
/// `complete` / `incomplete` / `missing` match those states. `unlocked` is an
/// alias for complete. Null (unsupported) when facets are unavailable or the
/// state word is unrecognized.
ItemPredicate? _catalystPredicate(String value, FacetResolver? facetsOf) {
  if (facetsOf == null) return null;
  const anyKeywords = {'', 'yes', 'y', 'has', 'true'};
  const stateByWord = {
    'complete': CatalystState.complete,
    'completed': CatalystState.complete,
    'unlocked': CatalystState.complete,
    'incomplete': CatalystState.incomplete,
    'inprogress': CatalystState.incomplete,
    'missing': CatalystState.missing,
    'none': CatalystState.missing,
    'locked': CatalystState.missing,
  };
  if (anyKeywords.contains(value)) {
    return (item) => facetsOf(item)?.catalyst != null;
  }
  final want = stateByWord[value];
  if (want == null) return null; // unrecognized state word → unsupported
  return (item) => facetsOf(item)?.catalyst == want;
}

/// `count:<compare>` — e.g. `count:>1` for owned duplicates. Matches on the
/// account-owned copy count from [countOf]. Null (unsupported) when the count
/// is unavailable (the Database tab) or the comparison is malformed.
ItemPredicate? _countPredicate(String rawValue, CountResolver? countOf) {
  if (countOf == null) return null;
  final cmp = parseNumericCompare(rawValue);
  if (cmp == null) return null;
  return (item) => cmp(countOf(item));
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
/// user could type (e.g. `is:solar`, `power:`). Free-text keys (`name:`,
/// `perk:`, …) offer just the key. [instanceData] adds the terms that only
/// work with live account data (power/light/count and the catalyst states) —
/// pass false for the Database tab so it does not suggest filters it cannot
/// evaluate.
List<String> filterSuggestionCatalog({bool instanceData = true}) => [
      for (final k in _isKeywords.keys) 'is:$k',
      // Free-text / definition-backed keys, on both tabs.
      'name:',
      'exactname:',
      'perk:',
      'perk1:',
      'perk2:',
      'frame:',
      'stat:',
      'source:',
      // The three ammo types as full suggestions; resolved from the item
      // directly, so they work on both tabs.
      'ammo:primary',
      'ammo:special',
      'ammo:heavy',
      // The three champion breakers as full suggestions; `breaker:` still lets
      // any value be typed.
      'breaker:overload',
      'breaker:barrier',
      'breaker:unstoppable',
      'description:',
      'keyword:',
      // Live-data-only terms.
      if (instanceData) ...[
        'power:',
        'light:',
        'tier:',
        'count:',
        // Bare `catalyst:` (any item that has a catalyst) plus each state.
        'catalyst:',
        'catalyst:complete',
        'catalyst:incomplete',
        'catalyst:missing',
      ],
    ];
