import '../../core/destiny/destiny_buckets.dart';
import '../../core/destiny/plug_category.dart';
import '../../core/search/item_filter.dart';
import '../../domain/models/destiny_item.dart';
import '../../domain/models/item_detail.dart';
import '../../core/search/search_suggestions.dart';
import 'facet_builder.dart';
import 'manifest_repository.dart';

/// The facets a Database browse applies. All fields are optional; a null field
/// means "no constraint on that facet". Applied in Dart against the cached
/// per-kind gear index (name search is handled separately by the search
/// grammar, so it is not a field here).
class GearFilter {
  const GearFilter({
    required this.kind,
    this.tierType,
    this.classType,
    this.itemSubType,
    this.damageType,
    this.ammoType,
  });

  /// Weapon or armor — selects which cached gear index to filter.
  final GearKind kind;

  /// DestinyTierType (5=Legendary, 6=Exotic, …).
  final int? tierType;

  /// DestinyClass (0=Titan, 1=Hunter, 2=Warlock). 3/any is not a filter value.
  final int? classType;

  /// DestinyItemSubType (weapon type: 9=HandCannon…; armor slot subtype).
  final int? itemSubType;

  /// Weapon default damage type (DestinyDamageType). Weapons only.
  final int? damageType;

  /// DestinyAmmunitionType (1=Primary, 2=Special, 3=Heavy). Weapons only.
  final int? ammoType;
}

/// Browses the manifest's **definitions** (all weapons and all armor) for the
/// Database tab. Unlike [InventoryRepository], which resolves *instances* from a
/// live profile, this reads definition data only — no auth, no account. It is a
/// separate resolution path on purpose: a definition exposes the *pool* of
/// possible perks per socket, not the single rolled perk an instance has.
class DatabaseRepository {
  DatabaseRepository({required this._manifest});

  final ManifestRepository _manifest;

  // The full deduped gear index per kind, built once (the ~800ms full-table
  // scan is measured; caching keeps every later facet/search/sort instant).
  final Map<GearKind, List<GearSummary>> _indexByKind = {};

  // Search facets (perks/stats/breaker/source/description) per item hash, per
  // kind, so the Database search grammar can evaluate the definition-backed
  // filters. Populated lazily by [facetsFor] — an item's facets (notably its
  // perk pool, a full definition decode) are resolved only when a search first
  // tests that item, then cached here.
  final Map<GearKind, Map<int, SearchFacets>> _facetsByKind = {};

  // Deduped index summaries keyed by item hash, per kind, so [facetsFor] can
  // find the summary for a hash without scanning the list. Built with the index.
  final Map<GearKind, Map<int, GearSummary>> _summariesByHash = {};

  // Perk display name (lowercased) -> Bungie icon path, the catalog that backs
  // the `perk:` autocomplete. Merged from each kind's facet warm; perks are a
  // weapon concept, so in practice only the weapon warm populates it.
  final Map<String, String> _perkIconByName = {};

  // Archetype-frame name (lowercased) -> Bungie icon path, the catalog behind
  // the `frame:` autocomplete. Also merged from the facet warm.
  final Map<String, String> _frameIconByName = {};

  // The stable WEAPON PERKS socket-category hash (like the bucket hashes in
  // EquipmentBucket, a game constant, not a per-launch lookup). Its sockets are
  // the perk columns destiny.report shows.
  static const _weaponPerksCategory = 4241085061;

  // Stats shown as an absolute number rather than a 0-100 bar. Mirrors the
  // instance resolver's list so the Database detail renders stats the same way.
  static const _numericStatNames = {
    'rounds per minute',
    'rpm',
    'draw time',
    'charge time',
    'magazine',
    'rounds per magazine',
    'ammo capacity',
    'heat generated',
    'cooling efficiency',
    // Note: the sword bar stats (Swing Speed, Charge Rate, Guard Resistance,
    // Guard Endurance) are intentionally NOT here — the game shows them as bars.
  };

  /// The gear of [filter], as list-row summaries. Filtered in Dart against the
  /// cached per-kind index (built lazily on first access — see [_indexFor]), so
  /// only the first call for a kind pays the manifest scan; later facet changes
  /// are instant.
  List<GearSummary> listGear(GearFilter filter) {
    return _indexFor(filter.kind).where((g) {
      if (filter.tierType != null && g.tierType != filter.tierType) {
        return false;
      }
      if (filter.classType != null && g.classType != filter.classType) {
        return false;
      }
      if (filter.itemSubType != null && g.itemSubType != filter.itemSubType) {
        return false;
      }
      if (filter.damageType != null && g.damageType != filter.damageType) {
        return false;
      }
      if (filter.ammoType != null && g.ammoType != filter.ammoType) {
        return false;
      }
      return true;
    }).toList();
  }

  /// The full deduped [GearSummary] index for [kind], built once and cached.
  /// Reissued definitions share a name; per the product decision they collapse
  /// to one row per name, keeping the newest (highest manifest `index`).
  List<GearSummary> _indexFor(GearKind kind) {
    final cached = _indexByKind[kind];
    if (cached != null) return cached;

    final rows = _manifest.queryGearSummaries(kind);
    final byName = <String, GearSummary>{};
    for (final row in rows) {
      final summary = _summaryOf(row);
      if (summary == null) continue;
      final existing = byName[summary.name];
      if (existing == null || summary.index > existing.index) {
        byName[summary.name] = summary;
      }
    }

    final index = byName.values.toList();
    _indexByKind[kind] = index;
    _summariesByHash[kind] = {for (final s in index) s.itemHash: s};
    _facetsByKind[kind] = {};
    return index;
  }

  /// The [SearchFacets] for the gear [itemHash] in [kind], or null when the item
  /// is not in the (built) index. Normally already warmed in a background
  /// isolate ([warmFacets]); this is the fallback that resolves one item
  /// synchronously on the UI thread if a search tests it before the warm
  /// completes, caching the result so later tests are instant.
  SearchFacets? facetsFor(GearKind kind, int itemHash) {
    _indexFor(kind); // ensure the index + summary lookup are built
    if (_summariesByHash[kind]?[itemHash] == null) return null;
    final cache = _facetsByKind[kind]!;
    return cache[itemHash] ??=
        (_lazyBuilder ??= FacetBuilder(_manifest)).facetsFor(itemHash, kind);
  }

  // A FacetBuilder over the app's (UI-thread) manifest, for the lazy fallback
  // in [facetsFor]. The startup warm uses a separate builder inside an isolate.
  FacetBuilder? _lazyBuilder;

  /// Whether [kind]'s gear index has been built (its list is ready to show).
  bool isIndexWarm(GearKind kind) => _indexByKind.containsKey(kind);

  /// Build and cache [kind]'s gear index, returning it. Async so callers can
  /// warm it at startup off the first-paint path; the manifest scan itself is a
  /// single synchronous SQLite call (it cannot be chunked — sqlite3 is
  /// synchronous), so this awaits a microtask first to yield the current frame,
  /// then runs the ~800ms scan. Idempotent — a second call returns the cache.
  Future<List<GearSummary>> warmIndex(GearKind kind) async {
    if (_indexByKind[kind] case final cached?) return cached;
    await Future<void>.delayed(Duration.zero);
    return _indexFor(kind);
  }

  /// Resolve every item's [SearchFacets] for [kind] in a **background isolate**,
  /// then merge the result into the cache. The ~3s of definition decoding runs
  /// entirely off the UI thread (the isolate opens its own read-only manifest
  /// connection), so warming never stutters the UI. Idempotent — items already
  /// cached (e.g. touched by a mid-warm search) are not overwritten. No-op when
  /// the manifest path is unknown (falls back to lazy per-item resolution).
  Future<void> warmFacets(GearKind kind) async {
    final index = await warmIndex(kind);
    final dbPath = _manifest.databasePath;
    if (dbPath == null) return; // lazy facetsFor still covers searches
    final hashes = [for (final s in index) s.itemHash];
    final built = await runFacetBuildInIsolate(
      dbPath: dbPath,
      kind: kind,
      itemHashes: hashes,
    );
    final cache = _facetsByKind[kind]!;
    built.facets.forEach((hash, facets) => cache[hash] ??= facets);
    // Merge the kind's catalogs; first path to record a name wins.
    built.perkIcons.forEach((name, icon) => _perkIconByName[name] ??= icon);
    built.frameIcons.forEach((name, icon) => _frameIconByName[name] ??= icon);
  }

  /// The perk catalog (name + icon) for the `perk:` autocomplete, sorted by
  /// name. Draws from both the background warm's merged catalog and the lazy
  /// UI-thread builder — whichever resolved a perk first — so autocomplete works
  /// even if a search touches items before (or instead of) the isolate warm.
  /// Empty only until at least one weapon's perks have decoded either way.
  List<PerkOption> perkOptions() {
    final byName = {..._perkIconByName};
    // Fold in perks resolved lazily on the UI thread (the isolate warm merges
    // its own into _perkIconByName; the lazy builder keeps its own map).
    _lazyBuilder?.perkIcons.forEach((name, icon) => byName[name] ??= icon);
    final names = byName.keys.toList()..sort();
    return [for (final name in names) PerkOption(name, byName[name]!)];
  }

  /// The archetype-frame catalog (name + icon) for the `frame:` autocomplete,
  /// sorted by name. Same dual-source resolution as [perkOptions] — the warm's
  /// merged catalog plus the lazy builder — so it fills whichever path runs.
  List<PerkOption> frameOptions() {
    final byName = {..._frameIconByName};
    _lazyBuilder?.frameIcons.forEach((name, icon) => byName[name] ??= icon);
    final names = byName.keys.toList()..sort();
    return [for (final name in names) PerkOption(name, byName[name]!)];
  }

  /// Build a [GearSummary] from a projected gear row, or null when it lacks a
  /// usable name.
  GearSummary? _summaryOf(Map<String, Object?> row) {
    final name = row['name'] as String? ?? '';
    final itemHash = (row['hash'] as num?)?.toInt();
    if (name.isEmpty || itemHash == null) return null;

    final damageType = (row['damageType'] as num?)?.toInt() ?? 0;
    // Resolve the element glyph for every real damage type, kinetic included —
    // kinetic has its own icon, so kinetic weapons no longer render blank.
    String? elementIconPath;
    if (damageType >= DamageType.kinetic) {
      final dmgDef =
          _manifest.getDamageType((row['damageTypeHash'] as num?)?.toInt() ?? 0);
      elementIconPath = (dmgDef?['transparentIconPath'] as String?) ??
          (dmgDef?['displayProperties']?['icon'] as String?);
    }

    return GearSummary(
      itemHash: itemHash,
      name: name,
      iconPath: row['icon'] as String? ?? '',
      tierType: (row['tierType'] as num?)?.toInt() ?? 0,
      itemType: (row['itemType'] as num?)?.toInt() ?? 0,
      itemSubType: (row['itemSubType'] as num?)?.toInt() ?? 0,
      itemTypeDisplayName: row['itemTypeDisplayName'] as String? ?? '',
      classType: (row['classType'] as num?)?.toInt() ?? 3,
      damageType: damageType,
      ammoType: (row['ammoType'] as num?)?.toInt() ?? 0,
      bucketHash: (row['bucketHash'] as num?)?.toInt() ?? 0,
      index: (row['idx'] as num?)?.toInt() ?? 0,
      elementIconPath: elementIconPath,
    );
  }

  /// Resolve the full definition detail for the Database modal: base stats (no
  /// instance bonuses), the pre-rendered screenshot, flavor text, the intrinsic
  /// frame plug, the champion breaker, the destiny.report-style perk columns
  /// (every candidate per socket, labeled).
  GearDetail? resolveGearDetail(int itemHash) {
    final def = _manifest.getInventoryItem(itemHash);
    if (def == null) return null;

    final item = _itemOf(itemHash, def);
    final frame = _resolveFramePlugs(def);
    return GearDetail(
      item: item,
      stats: _resolveStats(def),
      perkColumns: _resolvePerkColumns(def),
      frame: frame.isEmpty ? null : frame.first,
      breaker: _resolveBreaker(def),
      flavorText: (def['flavorText'] as String?) ?? '',
      screenshotPath: (def['screenshot'] as String?) ?? '',
    );
  }

  DestinyItem _itemOf(int itemHash, Map<String, dynamic> def) {
    final display = def['displayProperties'] as Map<String, dynamic>?;
    final damageType = (def['defaultDamageType'] as num?)?.toInt() ?? 0;
    String? elementIconPath;
    if (damageType > DamageType.kinetic) {
      final dmgDef = _manifest.getDamageType(
          (def['defaultDamageTypeHash'] as num?)?.toInt() ?? 0);
      elementIconPath = (dmgDef?['transparentIconPath'] as String?) ??
          (dmgDef?['displayProperties']?['icon'] as String?);
    }
    return DestinyItem(
      itemHash: itemHash,
      bucketHash: (def['inventory']?['bucketTypeHash'] as num?)?.toInt() ?? 0,
      name: (display?['name'] as String?) ?? '',
      iconPath: (display?['icon'] as String?) ?? '',
      itemType: (def['itemType'] as num?)?.toInt() ?? 0,
      itemSubType: (def['itemSubType'] as num?)?.toInt() ?? 0,
      tierType: (def['inventory']?['tierType'] as num?)?.toInt() ?? 0,
      classType: (def['classType'] as num?)?.toInt(),
      ammoType: (def['equippingBlock']?['ammoType'] as num?)?.toInt() ?? 0,
      itemTypeDisplayName: (def['itemTypeDisplayName'] as String?) ?? '',
      // A definition has no rolled damage type; use the default so the header
      // shows the element badge.
      damageType: damageType > DamageType.kinetic ? damageType : null,
      elementIconPath: elementIconPath,
    );
  }

  // The weapon power-level stats ("Attack" and "Power"): they come from the
  // *instance*, so they are always 0 on a definition and are duplicates of each
  // other — noise that the in-game inspect screen also omits. Excluded here.
  static const _powerLevelStatHashes = {1480404414, 1935470627};

  /// Base stats from the definition's `stats.stats` map. These are the raw
  /// definition values — no instance masterwork/mod bonuses, so no gold/red
  /// segments (the plain bar path). Ordered bar, then recoil, then numeric
  /// stats via [sortStatsForDisplay], with the always-zero power-level stats
  /// dropped.
  List<ItemStat> _resolveStats(Map<String, dynamic> def) {
    final map = def['stats']?['stats'];
    if (map is! Map) return const [];
    // The stats a weapon shows are its stat group's scaledStats — the declared
    // `stats.stats` is a superset with hidden junk (e.g. a sword declares
    // Zoom/Range/Guard Efficiency but shows none). Filter to the shown set.
    final shown = _shownStatHashes(def);
    final result = <ItemStat>[];
    for (final entry in map.values) {
      final e = entry as Map<String, dynamic>;
      final statHash = (e['statHash'] as num?)?.toInt();
      final value = (e['value'] as num?)?.toInt();
      if (statHash == null || value == null) continue;
      if (_powerLevelStatHashes.contains(statHash)) continue;
      if (shown != null && !shown.contains(statHash)) continue;
      final statDef = _manifest.getStat(statHash);
      final name = (statDef?['displayProperties']?['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      final display = lower == 'recoil direction'
          ? StatDisplay.recoil
          : _numericStatNames.contains(lower)
              ? StatDisplay.numeric
              : StatDisplay.bar;
      result.add(ItemStat(
          statHash: statHash, name: name, value: value, display: display));
    }
    return sortStatsForDisplay(result);
  }

  /// The stat hashes a weapon actually displays — its stat group's
  /// `scaledStats`. Null when the item has no stat group (show every declared
  /// stat, unchanged behaviour).
  Set<int>? _shownStatHashes(Map<String, dynamic> def) {
    final groupHash = (def['stats']?['statGroupHash'] as num?)?.toInt();
    if (groupHash == null) return null;
    final scaled = _manifest.getStatGroup(groupHash)?['scaledStats'];
    if (scaled is! List) return null;
    return {
      for (final s in scaled)
        ?((s as Map)['statHash'] as num?)?.toInt(),
    };
  }

  /// The intrinsic frame plug(s): a weapon's frame ("Adaptive Frame") or an
  /// exotic's intrinsic perk — and, for armor, the exotic intrinsic perk (e.g.
  /// "Nightmare Fuel"). Both live as a socket's initial plug that classifies as
  /// [PlugCategory.frame] (its `plugCategoryIdentifier` is `intrinsics`), so
  /// scanning every socket's initial plug and keeping the frame-classed ones
  /// covers weapons and armor uniformly without armor-specific category hashes.
  List<ItemPlug> _resolveFramePlugs(Map<String, dynamic> def) {
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List) return const [];
    final result = <ItemPlug>[];
    final seen = <int>{};
    for (final entry in entries) {
      final plugHash =
          ((entry as Map)['singleInitialItemHash'] as num?)?.toInt();
      if (plugHash == null || plugHash == 0 || !seen.add(plugHash)) continue;
      final plug = _plugOf(plugHash, PlugCategory.other);
      if (plug != null && plug.category == PlugCategory.frame) {
        result.add(plug);
      }
    }
    return result;
  }

  /// The weapon's perk columns: for each socket in the WEAPON PERKS category,
  /// the pool of possible plugs (from its randomized/reusable plug set and any
  /// inline reusable plugs). Empty for armor and for non-random exotics with no
  /// perk sockets.
  List<PerkColumn> _resolvePerkColumns(Map<String, dynamic> def) {
    final columns = <PerkColumn>[];
    for (final index in _socketIndexesOf(def, _weaponPerksCategory)) {
      final entry = _socketEntry(def, index);
      if (entry == null) continue;
      final plugs = _columnPlugs(entry);
      // Keep only real perk columns. The WEAPON PERKS category also contains
      // the kill-tracker socket (Kill Tracker / Crucible Tracker); those plugs
      // classify as masterwork/cosmetic, not perk, so a column with no
      // perk/frame plug is dropped.
      final hasPerk = plugs.any((p) =>
          p.category == PlugCategory.perk || p.category == PlugCategory.frame);
      if (hasPerk) {
        columns.add(PerkColumn(plugs: plugs, label: _columnLabel(entry)));
      }
    }
    return columns;
  }

  /// A human column label ("Barrel", "Bowstring", "Launcher Barrel",
  /// "Magazine", "Trait", "Origin Trait"…). Preferred source: the plugs' own
  /// type names, since the whitelist identifiers vary per weapon family and
  /// don't cover them all; falls back to the socket type's plug whitelist,
  /// then to an empty label.
  String _columnLabel(Map<String, dynamic> entry) {
    for (final hash in _columnPlugHashes(entry)) {
      if (hash == 0) continue;
      final label = perkColumnLabelFromPlugType(
          _manifest.getInventoryItem(hash)?['itemTypeDisplayName'] as String?);
      if (label.isNotEmpty) return label;
    }
    final typeHash = (entry['socketTypeHash'] as num?)?.toInt();
    if (typeHash == null) return '';
    final type = _manifest.getSocketType(typeHash);
    final whitelist = type?['plugWhitelist'];
    if (whitelist is! List) return '';
    for (final w in whitelist) {
      final id = ((w as Map)['categoryIdentifier'] as String?) ?? '';
      final label = perkColumnLabelFor(id);
      if (label.isNotEmpty) return label;
    }
    return '';
  }

  /// Gather the candidate plugs for one perk socket: the plug-set entries
  /// (randomized rolls, then reusable) plus inline reusable plugs, deduped and
  /// resolved to displayable trait/perk plugs. Placeholder/empty plugs are
  /// dropped.
  List<ItemPlug> _columnPlugs(Map<String, dynamic> entry) {
    final seen = <int>{};
    final plugs = <ItemPlug>[];
    for (final hash in _columnPlugHashes(entry)) {
      if (hash == 0 || !seen.add(hash)) continue;
      final plug = _plugOf(hash, PlugCategory.perk);
      if (plug != null) plugs.add(plug);
    }
    // A column's plug sets list base and enhanced rolls in a mixed order (and a
    // socket may draw from two sets). Group all enhanced first, then base, each
    // keeping its original order (a stable partition, not List.sort which is
    // not guaranteed stable). Perks are never deduped — a same-named base and
    // enhanced roll are two distinct, real options.
    return [
      ...plugs.where((p) => p.isEnhanced),
      ...plugs.where((p) => !p.isEnhanced),
    ];
  }

  /// Every candidate plug hash of a perk socket, in definition order: the
  /// plug-set entries (randomized rolls, then reusable) then inline reusable
  /// plugs. May contain duplicates; callers dedupe as needed.
  Iterable<int> _columnPlugHashes(Map<String, dynamic> entry) sync* {
    for (final key in ['randomizedPlugSetHash', 'reusablePlugSetHash']) {
      final setHash = (entry[key] as num?)?.toInt();
      if (setHash == null) continue;
      final set = _manifest.getPlugSet(setHash);
      final items = set?['reusablePlugItems'];
      if (items is! List) continue;
      for (final pi in items) {
        final hash = ((pi as Map)['plugItemHash'] as num?)?.toInt();
        if (hash != null) yield hash;
      }
    }
    final inline = entry['reusablePlugItems'];
    if (inline is List) {
      for (final pi in inline) {
        final hash = ((pi as Map)['plugItemHash'] as num?)?.toInt();
        if (hash != null) yield hash;
      }
    }
  }

  /// Resolve a plug definition to an [ItemPlug]. [fallbackCategory] is used when
  /// the plug's own category identifier is missing. Returns null for plugs with
  /// no display name (empty-socket placeholders).
  ItemPlug? _plugOf(int plugHash, PlugCategory fallbackCategory) {
    final def = _manifest.getInventoryItem(plugHash);
    if (def == null) return null;
    final display = def['displayProperties'] as Map<String, dynamic>?;
    final name = (display?['name'] as String?) ?? '';
    if (name.isEmpty) return null;
    final plugCategory = def['plug']?['plugCategoryIdentifier'] as String?;
    final category = plugCategory == null
        ? fallbackCategory
        : classifyPlug(plugCategory);
    final enhanced = isEnhancedPlugDef(def);
    return ItemPlug(
      name: name,
      iconPath: (display?['icon'] as String?) ?? '',
      description: (display?['description'] as String?) ?? '',
      category: category,
      isEnhanced: enhanced,
      statEffects: _statEffectsOf(def),
    );
  }

  /// The stat changes a plug applies, from its unconditional `investmentStats`.
  /// Conditionally-active stats (situational bonuses) and zero values are
  /// skipped, matching how the instance detail folds perk stats in.
  List<PerkStatEffect> _statEffectsOf(Map<String, dynamic> def) {
    final invStats = def['investmentStats'];
    if (invStats is! List) return const [];
    final effects = <PerkStatEffect>[];
    for (final s in invStats) {
      final st = s as Map<String, dynamic>;
      if (st['isConditionallyActive'] == true) continue;
      final statHash = (st['statTypeHash'] as num?)?.toInt();
      final value = (st['value'] as num?)?.toInt() ?? 0;
      if (statHash == null || value == 0) continue;
      final statDef = _manifest.getStat(statHash);
      final name = (statDef?['displayProperties']?['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      effects.add(PerkStatEffect(hash: statHash, name: name, value: value));
    }
    return effects;
  }

  // The intrinsic-traits socket category (a stable game constant). A weapon's
  // frame plug lives here; its marker sandbox perk carries a frame-granted
  // breaker for legendaries that have no intrinsic breakerTypeHash.
  static const _intrinsicCategory = 3956125808;

  /// The item's champion breaker, resolved from the definition. First the
  /// item's own intrinsic `breakerTypeHash` (exotics), then — as on the
  /// inventory tab — the frame-granted breaker expressed as a marker sandbox
  /// perk on the intrinsic frame plug (e.g. "[Stagger] Unstoppable"), which is
  /// how legendaries carry their breaker. Null when neither is present.
  BreakerType? _resolveBreaker(Map<String, dynamic> def) {
    // 1. Intrinsic breaker on the item definition.
    final hash = (def['breakerTypeHash'] as num?)?.toInt();
    if (hash != null && hash != 0) {
      final display =
          _manifest.getBreakerType(hash)?['displayProperties']
              as Map<String, dynamic>?;
      final name = (display?['name'] as String?) ?? '';
      if (name.isNotEmpty) {
        return BreakerType(
            name: name, iconPath: (display?['icon'] as String?) ?? '');
      }
    }
    // 2. Frame-granted breaker: a marker perk on the intrinsic frame plug.
    for (final index in _socketIndexesOf(def, _intrinsicCategory)) {
      final entry = _socketEntry(def, index);
      final plugHash = (entry?['singleInitialItemHash'] as num?)?.toInt();
      if (plugHash == null || plugHash == 0) continue;
      final breaker = _frameMarkerBreaker(plugHash);
      if (breaker != null) return breaker;
    }
    return null;
  }

  /// A frame-granted [BreakerType] from an intrinsic plug's marker sandbox perk
  /// (e.g. "[Stagger] Unstoppable"), or null when the plug carries none. Cached
  /// per plug hash — many weapons share a frame plug.
  BreakerType? _frameMarkerBreaker(int plugHash) {
    return _frameBreakerCache.putIfAbsent(plugHash, () {
      final perks = _manifest.getInventoryItem(plugHash)?['perks'];
      if (perks is! List) return null;
      for (final perk in perks) {
        final perkHash = ((perk as Map)['perkHash'] as num?)?.toInt();
        if (perkHash == null) continue;
        final display = _manifest.getSandboxPerk(perkHash)?['displayProperties']
            as Map<String, dynamic>?;
        final name = _breakerFromMarker((display?['name'] as String?) ?? '');
        if (name != null) {
          return BreakerType(
              name: name, iconPath: (display?['icon'] as String?) ?? '');
        }
      }
      return null;
    });
  }

  final Map<int, BreakerType?> _frameBreakerCache = {};

  /// Maps a marker perk name like "[Stagger] Unstoppable" to the champion label
  /// (matching the inventory tab's mapping), or null when it carries no marker.
  static String? _breakerFromMarker(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('[stagger]')) return 'Unstoppable';
    if (lower.contains('[disruption]')) return 'Overload';
    if (lower.contains('[shield-piercing]') ||
        lower.contains('[shield piercing]')) {
      return 'Barrier';
    }
    return null;
  }

  /// The champion breaker for the gear [itemHash], for the list row. Resolved
  /// lazily and cached — the list is virtualised, so only visible rows pay the
  /// definition decode, and repeat scrolls are instant.
  BreakerType? rowBreaker(int itemHash) {
    return _rowBreakerCache.putIfAbsent(itemHash, () {
      final def = _manifest.getInventoryItem(itemHash);
      return def == null ? null : _resolveBreaker(def);
    });
  }

  final Map<int, BreakerType?> _rowBreakerCache = {};

  /// The socket indexes belonging to [categoryHash] in the definition's
  /// `sockets.socketCategories`.
  List<int> _socketIndexesOf(Map<String, dynamic> def, int categoryHash) {
    final categories = def['sockets']?['socketCategories'];
    if (categories is! List) return const [];
    for (final c in categories) {
      final m = c as Map<String, dynamic>;
      if ((m['socketCategoryHash'] as num?)?.toInt() != categoryHash) continue;
      final indexes = m['socketIndexes'];
      if (indexes is! List) return const [];
      return [for (final i in indexes) (i as num).toInt()];
    }
    return const [];
  }

  Map<String, dynamic>? _socketEntry(Map<String, dynamic> def, int index) {
    final entries = def['sockets']?['socketEntries'];
    if (entries is! List || index < 0 || index >= entries.length) return null;
    return entries[index] as Map<String, dynamic>;
  }
}
