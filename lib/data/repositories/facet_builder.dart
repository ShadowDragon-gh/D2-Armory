import '../../core/destiny/destiny_buckets.dart';
import '../../core/destiny/plug_category.dart';
import '../../core/search/item_filter.dart';
import '../local/manifest_database.dart';

/// The manifest-lookup surface the facet build needs. Both [ManifestRepository]
/// (the app's open manifest, on the UI thread) and [ManifestDatabase] (a fresh
/// read-only connection inside a warm-up isolate) satisfy it, so one
/// [FacetBuilder] serves both paths and stays mockable in tests.
abstract interface class FacetSource {
  Map<String, dynamic>? getInventoryItem(int hash);
  Map<String, dynamic>? getStat(int hash);
  Map<String, dynamic>? getPlugSet(int hash);
  Map<String, dynamic>? getBreakerType(int hash);
  Map<String, dynamic>? getCollectible(int hash);
  Map<String, dynamic>? getSandboxPerk(int hash);
  Map<String, dynamic>? getSocketType(int hash);
}

/// Builds the searchable [SearchFacets] for gear definitions, reading through a
/// [FacetSource]. Single source of truth for both paths: the UI resolves one
/// item lazily over the app's open manifest; a background isolate resolves a
/// whole kind over its own read-only connection (see
/// `DatabaseRepository.warmFacets`). Per-plug/plug-set lookups are cached so a
/// perk shared by hundreds of weapons decodes once per build.
class FacetBuilder {
  FacetBuilder(this._db);

  final FacetSource _db;

  // Caches shared across a build (one FacetBuilder = one build session).
  final Map<int, String?> _plugPerkName = {};
  final Map<int, List<int>> _plugSetItems = {};

  // Champion effect keyword per breaker type name, so `breaker:overload` and
  // `breaker:disruption` both match (the def names the type, players type the
  // champion it counters).
  static const _breakerEffectByType = {
    'stagger': 'unstoppable',
    'disruption': 'overload',
    'shield piercing': 'barrier',
  };

  /// The facets for one item, or empty facets when its definition is missing.
  SearchFacets facetsFor(int itemHash, GearKind kind) {
    final def = _db.getInventoryItem(itemHash);
    if (def == null) return const SearchFacets();

    final stats = <String, int>{};
    final statMap = def['stats']?['stats'];
    if (statMap is Map) {
      for (final entry in statMap.values) {
        final e = entry as Map<String, dynamic>;
        final statHash = (e['statHash'] as num?)?.toInt();
        final value = (e['value'] as num?)?.toInt();
        if (statHash == null || value == null) continue;
        final name = (_db.getStat(statHash)?['displayProperties']?['name']
                as String?)
            ?.toLowerCase();
        if (name == null || name.isEmpty) continue;
        stats[name] = value;
      }
    }

    return SearchFacets(
      perks: kind == GearKind.weapon ? _perkNamesOf(def) : const {},
      perkColumns:
          kind == GearKind.weapon ? _traitColumnsOf(def) : const [],
      stats: stats,
      breaker: _breakerNameOf(def)?.toLowerCase(),
      sources: _sourceStringsOf(def),
      description: _descriptionOf(def),
      frame: _frameNameOf(def),
    );
  }

  /// The item's mechanical description + flavor text, combined and lowercased.
  String _descriptionOf(Map<String, dynamic> def) {
    final parts = [
      (def['displayProperties']?['description'] as String?) ?? '',
      (def['flavorText'] as String?) ?? '',
    ].where((s) => s.isNotEmpty);
    return parts.join(' ').toLowerCase();
  }

  /// Every candidate perk/trait plug name across a weapon's sockets, lowercased
  /// (the full roll pool), keeping only real perk/frame plugs.
  Set<String> _perkNamesOf(Map<String, dynamic> def) {
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List) return const {};
    final names = <String>{};
    for (final entry in entries) {
      final e = entry as Map<String, dynamic>;
      for (final key in ['randomizedPlugSetHash', 'reusablePlugSetHash']) {
        final setHash = (e[key] as num?)?.toInt();
        if (setHash == null) continue;
        for (final plugHash in _plugSetItemsOf(setHash)) {
          final name = _perkNameFor(plugHash);
          if (name != null) names.add(name);
        }
      }
      final inline = e['reusablePlugItems'];
      if (inline is List) {
        for (final pi in inline) {
          final plugHash = ((pi as Map)['plugItemHash'] as num?)?.toInt();
          if (plugHash == null) continue;
          final name = _perkNameFor(plugHash);
          if (name != null) names.add(name);
        }
      }
    }
    return names;
  }

  String? _perkNameFor(int plugHash) {
    return _plugPerkName.putIfAbsent(plugHash, () {
      if (plugHash == 0) return null;
      final def = _db.getInventoryItem(plugHash);
      if (def == null) return null;
      final name =
          (def['displayProperties']?['name'] as String?)?.toLowerCase();
      if (name == null || name.isEmpty) return null;
      final category =
          classifyPlug(def['plug']?['plugCategoryIdentifier'] as String?);
      if (category != PlugCategory.perk && category != PlugCategory.frame) {
        return null;
      }
      return name;
    });
  }

  List<int> _plugSetItemsOf(int setHash) {
    return _plugSetItems.putIfAbsent(setHash, () {
      final items = _db.getPlugSet(setHash)?['reusablePlugItems'];
      if (items is! List) return const [];
      return [
        for (final pi in items)
          if (((pi as Map)['plugItemHash'] as num?)?.toInt() != null)
            (pi['plugItemHash'] as num).toInt(),
      ];
    });
  }

  // The WEAPON PERKS socket category (a stable game constant). Its `frames`
  // sockets are the two random trait columns — perk 1 and perk 2.
  static const _weaponPerksCategory = 4241085061;

  /// The candidate perk names for each random *trait* column, in column order.
  /// A trait column is a WEAPON PERKS socket whose plug whitelist is `frames`
  /// (barrels/magazines/origin sockets are excluded). Empty when the weapon has
  /// no random trait sockets (most exotics).
  List<Set<String>> _traitColumnsOf(Map<String, dynamic> def) {
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List) return const [];

    final columns = <Set<String>>[];
    for (final i in traitSocketIndexes(def)) {
      final entry = entries[i] as Map<String, dynamic>;
      final names = <String>{};
      for (final key in ['randomizedPlugSetHash', 'reusablePlugSetHash']) {
        final setHash = (entry[key] as num?)?.toInt();
        if (setHash == null) continue;
        for (final plugHash in _plugSetItemsOf(setHash)) {
          final name = _perkNameFor(plugHash);
          if (name != null) names.add(name);
        }
      }
      final inline = entry['reusablePlugItems'];
      if (inline is List) {
        for (final pi in inline) {
          final plugHash = ((pi as Map)['plugItemHash'] as num?)?.toInt();
          final name = plugHash == null ? null : _perkNameFor(plugHash);
          if (name != null) names.add(name);
        }
      }
      if (names.isNotEmpty) columns.add(names);
    }
    return columns;
  }

  /// The `socketEntries` indexes of a weapon's random *trait* columns, in column
  /// order — the WEAPON PERKS sockets whose plug whitelist is `frames`. Bungie
  /// aligns instance socket components (305/310) with these definition indexes,
  /// so callers can read an instance's rolled options per trait column by index.
  /// Empty when the weapon has no random trait sockets (most exotics).
  List<int> traitSocketIndexes(Map<String, dynamic> def) {
    final sockets = def['sockets'];
    if (sockets is! Map) return const [];
    final categories = sockets['socketCategories'];
    final entries = sockets['socketEntries'];
    if (categories is! List || entries is! List) return const [];

    List indexes = const [];
    for (final c in categories) {
      if ((c as Map)['socketCategoryHash'] == _weaponPerksCategory) {
        indexes = c['socketIndexes'] as List? ?? const [];
        break;
      }
    }

    final result = <int>[];
    for (final i in indexes) {
      if (i is! int || i < 0 || i >= entries.length) continue;
      if (!_isTraitSocket(entries[i] as Map<String, dynamic>)) continue;
      result.add(i);
    }
    return result;
  }

  /// The perk/frame plug name for [plugHash], lowercased, or null when the plug
  /// is missing or is not a real perk/frame plug. Cached per build.
  String? perkNameFor(int plugHash) => _perkNameFor(plugHash);

  /// Whether a socket entry is a random *trait* column — its socket type's plug
  /// whitelist is `frames` (as opposed to barrels/magazines/origins/trackers).
  bool _isTraitSocket(Map<String, dynamic> entry) {
    final typeHash = (entry['socketTypeHash'] as num?)?.toInt();
    if (typeHash == null) return false;
    final whitelist = _db.getSocketType(typeHash)?['plugWhitelist'];
    if (whitelist is! List) return false;
    return whitelist
        .any((w) => (w as Map)['categoryIdentifier'] == 'frames');
  }

  /// The champion breaker as `<type> <champion>` (e.g. `stagger unstoppable`),
  /// or null. Resolves the intrinsic `breakerTypeHash` first (exotics), then the
  /// frame-granted breaker from the intrinsic frame plug's marker perk (e.g.
  /// "[Stagger] Unstoppable") the same way the list/modal do — so `breaker:`
  /// search covers legendaries too, not just intrinsic-breaker exotics.
  String? _breakerNameOf(Map<String, dynamic> def) {
    // 1. Intrinsic breaker on the item definition.
    final hash = (def['breakerTypeHash'] as num?)?.toInt();
    if (hash != null && hash != 0) {
      final name =
          _db.getBreakerType(hash)?['displayProperties']?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        final effect = _breakerEffectByType[name.toLowerCase()];
        return effect == null ? name : '$name $effect';
      }
    }
    // 2. Frame-granted breaker: a marker perk on the intrinsic frame plug.
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List) return null;
    final seen = <int>{};
    for (final entry in entries) {
      final plugHash =
          ((entry as Map)['singleInitialItemHash'] as num?)?.toInt();
      if (plugHash == null || plugHash == 0 || !seen.add(plugHash)) continue;
      final champion = _frameMarkerChampion(plugHash);
      if (champion != null) return champion;
    }
    return null;
  }

  /// The champion breaker (e.g. `stagger unstoppable`) a frame plug grants via a
  /// marker sandbox perk ("[Stagger] Unstoppable"), or null. Both the type name
  /// and the champion keyword are returned so `breaker:stagger` and
  /// `breaker:unstoppable` both match.
  String? _frameMarkerChampion(int plugHash) {
    final perks = _db.getInventoryItem(plugHash)?['perks'];
    if (perks is! List) return null;
    for (final perk in perks) {
      final perkHash = ((perk as Map)['perkHash'] as num?)?.toInt();
      if (perkHash == null) continue;
      final name = (_db.getSandboxPerk(perkHash)?['displayProperties']?['name']
              as String?)
          ?.toLowerCase();
      if (name == null) continue;
      if (name.contains('[stagger]')) return 'stagger unstoppable';
      if (name.contains('[disruption]')) return 'disruption overload';
      if (name.contains('[shield-piercing]') ||
          name.contains('[shield piercing]')) {
        return 'shield piercing barrier';
      }
    }
    return null;
  }

  Set<String> _sourceStringsOf(Map<String, dynamic> def) {
    final collectibleHash = (def['collectibleHash'] as num?)?.toInt();
    if (collectibleHash == null || collectibleHash == 0) return const {};
    final source =
        _db.getCollectible(collectibleHash)?['sourceString'] as String?;
    if (source == null || source.isEmpty) return const {};
    return {source.toLowerCase()};
  }

  /// The intrinsic frame name (archetype), lowercased — the first frame-classed
  /// initial plug across the item's sockets (matching the detail resolver), or
  /// null when it has none.
  String? _frameNameOf(Map<String, dynamic> def) {
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List) return null;
    final seen = <int>{};
    for (final entry in entries) {
      final plugHash =
          ((entry as Map)['singleInitialItemHash'] as num?)?.toInt();
      if (plugHash == null || plugHash == 0 || !seen.add(plugHash)) continue;
      final pd = _db.getInventoryItem(plugHash);
      final category =
          classifyPlug(pd?['plug']?['plugCategoryIdentifier'] as String?);
      if (category != PlugCategory.frame) continue;
      final name =
          (pd?['displayProperties']?['name'] as String?)?.toLowerCase();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }
}

/// Build the facets for every [itemHash] over the manifest at [dbPath], opening
/// a fresh read-only connection. Runs in a background isolate (via
/// `Isolate.run`) so the ~3s of definition decoding never touches the UI
/// thread. Returns a plain, sendable map from item hash to its facets.
Map<int, SearchFacets> buildKindFacets({
  required String dbPath,
  required GearKind kind,
  required List<int> itemHashes,
}) {
  final db = ManifestDatabase.open(dbPath);
  try {
    final builder = FacetBuilder(db);
    return {
      for (final hash in itemHashes) hash: builder.facetsFor(hash, kind),
    };
  } finally {
    db.close();
  }
}
