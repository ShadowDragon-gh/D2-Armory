import '../../core/destiny/destiny_buckets.dart';
import '../../core/destiny/plug_category.dart';
import '../../core/search/item_filter.dart';
import '../../domain/models/destiny_character.dart';
import '../../domain/models/destiny_item.dart';
import '../../domain/models/inventory_grid.dart';
import '../../domain/models/item_detail.dart';
import '../remote/bungie_api.dart';
import 'facet_builder.dart';
import 'manifest_repository.dart';
import 'membership_service.dart';

/// Builds the DIM-style inventory grid: character + vault columns, each with
/// items grouped by equipment bucket, names/icons resolved from the manifest.
class InventoryRepository {
  InventoryRepository({
    required BungieApi api,
    required this._manifest,
  })  : _api = api,
        _memberships = MembershipService(api);

  final BungieApi _api;
  final ManifestRepository _manifest;
  final MembershipService _memberships;

  // Instance-keyed detail components from the last fetch, kept so the detail
  // panel can resolve a selected item without another network call.
  Map<String, dynamic> _stats = const {};
  Map<String, dynamic> _sockets = const {};
  // Instance-keyed rolled plug options per socket (component 310). A weapon's
  // trait sockets list all the perks that copy can roll to, so `perk1:`/`perk2:`
  // search matches any of a column's options, not just the equipped one.
  Map<String, dynamic> _reusablePlugs = const {};
  Map<String, dynamic> _plugObjectives = const {};
  // Record hash -> record component (catalyst/triumph progress), merged from
  // the profile- and character-scoped Records (900) components.
  Map<String, dynamic> _records = const {};

  // Bungie's `responseMintedTimestamp` from the last fetch: when Bungie minted
  // the profile snapshot. Bungie's edge cache can serve a profile older than
  // one already held, so a background refresh compares this to skip rebuilding
  // the grid from a staler response. Null before the first fetch.
  DateTime? _lastMintedTimestamp;

  /// When Bungie minted the profile from the last [fetchInventory], or null if
  /// not yet fetched / not provided. Used to detect a stale background refresh.
  DateTime? get lastMintedTimestamp => _lastMintedTimestamp;

  /// Patch the cached ItemSockets (305) and ItemStats (304) components for
  /// instance [instanceId] so [socketIndex] now reads [plugHash] — applied
  /// optimistically the moment an in-game socket insert is dispatched so the
  /// detail's stat bars and equipped plug update immediately, and after it
  /// succeeds so a later [resolveDetail] still reflects the new plug even when
  /// Bungie's edge cache serves the pre-insert profile (its
  /// `responseMintedTimestamp` can lag a write, so the refetch is discarded and
  /// this cache would otherwise stay stale until a genuinely newer snapshot).
  /// The cached stats (which Bungie computes with the old plug baked in) are
  /// adjusted by the old→new plug's *applied* stat delta — the raw investment
  /// change run through [item]'s stat interpolation, so an inverted/scaled stat
  /// (Heat Generated: +10 raw → -2 applied) shifts by the real in-game amount,
  /// not the raw. The next fresh [fetchInventory] overwrites both components, so
  /// this is a stop-gap a real refresh supersedes.
  ///
  /// Returns the plug hash previously in the socket, so a failed insert can be
  /// rolled back by patching it back (which reverses the stat delta); null when
  /// the instance or socket is not cached (a no-op).
  int? patchSocketPlug(
      DestinyItem item, int socketIndex, int plugHash) {
    final instanceId = item.itemInstanceId;
    if (instanceId == null) return null;
    final data = _sockets[instanceId] as Map<String, dynamic>?;
    final sockets = data?['sockets'];
    if (sockets is! List || socketIndex < 0 || socketIndex >= sockets.length) {
      return null;
    }
    final socket = sockets[socketIndex];
    if (socket is! Map<String, dynamic>) return null;
    final oldHash = (socket['plugHash'] as num?)?.toInt();
    socket['plugHash'] = plugHash;
    if (oldHash != plugHash) {
      _applyStatDelta(item, fromPlug: oldHash, toPlug: plugHash);
    }
    return oldHash;
  }

  /// Shift the cached ItemStats (304) for [item] by the *applied* difference
  /// between [fromPlug] and [toPlug]: the net raw investment change per stat,
  /// run through [item]'s stat interpolation so the cached displayed value moves
  /// by the real in-game amount (an inverted stat like Heat Generated shifts by
  /// its interpolated delta, not the raw investment). No-op when the instance
  /// has no cached stats.
  void _applyStatDelta(DestinyItem item,
      {int? fromPlug, required int toPlug}) {
    final instanceId = item.itemInstanceId;
    final statsData =
        instanceId == null ? null : _stats[instanceId] as Map<String, dynamic>?;
    final statsMap = statsData?['stats'];
    if (statsMap is! Map) return;

    // The net raw investment change per stat (new plug adds, old plug removes).
    final rawDelta = <int, int>{};
    void accumulate(int? plugHash, int sign) {
      if (plugHash == null || plugHash == 0) return;
      final invStats = _manifest.getInventoryItem(plugHash)?['investmentStats'];
      if (invStats is! List) return;
      for (final s in invStats) {
        final st = s as Map<String, dynamic>;
        if (st['isConditionallyActive'] == true) continue;
        final statHash = (st['statTypeHash'] as num?)?.toInt();
        final value = (st['value'] as num?)?.toInt() ?? 0;
        if (statHash == null || value == 0) continue;
        rawDelta[statHash] = (rawDelta[statHash] ?? 0) + sign * value;
      }
    }

    accumulate(toPlug, 1);
    accumulate(fromPlug, -1);

    // Convert each raw investment change to its applied (interpolated) change
    // against the current displayed base, matching what a real refetch yields.
    final interpolator = _statInterpolatorFor(item, statsData);
    final delta = <int, int>{
      for (final e in rawDelta.entries)
        e.key: interpolator.appliedFromRaw(e.key, e.value),
    };

    delta.forEach((statHash, d) {
      if (d == 0) return;
      final entry = statsMap['$statHash'];
      if (entry is Map<String, dynamic>) {
        final current = (entry['value'] as num?)?.toInt() ?? 0;
        entry['value'] = current + d;
      }
    });
  }

  // Search facets per item instance id, resolved lazily by [inventoryFacetsFor]
  // (the socket/stat/catalyst decode is the same work the detail panel does, so
  // a search only pays for the items it tests) and cached. Cleared on each
  // fetch so a refresh never serves facets from a stale instance.
  final Map<String, SearchFacets> _facetsByInstance = {};

  // Per-instance decode cache: the fully-built [DestinyItem] from the last fetch
  // plus a signature of every raw input its decode depended on. A background
  // refresh reuses the cached item when the signature is unchanged, skipping the
  // manifest definition lookup, ornament socket walk, and icon-layer resolution
  // — the dominant per-item cost. NOT cleared on fetch (it persists so a poll
  // can diff against the prior fetch); a changed signature re-decodes and
  // replaces the entry. Only consulted when [fetchInventory] is asked to reuse.
  final Map<String, ({String sig, DestinyItem item})> _decodeByInstance = {};

  static const _components = [
    100, // Profiles
    200, // Characters
    102, // ProfileInventories (vault)
    201, // CharacterInventories
    205, // CharacterEquipment
    300, // ItemInstances (power, damage type, breaker)
    304, // ItemStats
    305, // ItemSockets
    310, // ItemReusablePlugs (rolled options per socket)
    309, // ItemPlugObjectives (kill-tracker counts)
    900, // Records (catalyst progress)
  ];

  /// The classic "Empty Catalyst Socket" plug — a stable well-known hash,
  /// used as an icon fallback for era-specific shells that have none.
  static const _classicEmptyCatalystHash = 1498917124;

  /// Items to resolve per chunk before yielding to the event loop, so the
  /// synchronous manifest lookups never block a frame for the whole profile.
  static const _resolveBatch = 40;

  /// The "Default Ornament" plugs (weapon, armor, and weapon-tiering
  /// variants) that restore an item's original appearance — socketed by
  /// default, never an icon override.
  static const _defaultOrnamentHashes = {
    2931483505,
    1959648454,
    702981643,
    3854296178,
  };

  /// Fetch the profile and build the grid. [reuseDecoded] lets a background
  /// refresh reuse the previous fetch's decoded items whose inputs are
  /// unchanged (see [_decodeByInstance]); the initial load and manual retry
  /// leave it false so they always decode fresh.
  Future<InventoryGrid> fetchInventory({bool reuseDecoded = false}) async {
    final membership = await _memberships.resolvePrimary();
    final profile = await _api.getProfile(
      membershipType: membership.membershipType,
      membershipId: membership.membershipId,
      components: _components,
    );

    final itemComponents = profile['itemComponents'];
    final instances = _dataMap(itemComponents?['instances']);
    _stats = _dataMap(itemComponents?['stats']);
    _sockets = _dataMap(itemComponents?['sockets']);
    _reusablePlugs = _dataMap(itemComponents?['reusablePlugs']);
    _plugObjectives = _dataMap(itemComponents?['plugObjectives']);
    _records = _mergeRecords(profile);
    _lastMintedTimestamp =
        DateTime.tryParse(profile['responseMintedTimestamp'] as String? ?? '');
    // A full (non-reuse) fetch decodes everything fresh, so all cached facets
    // are stale — clear them. A reuse-refresh keeps facets for items it reuses
    // and evicts only those whose decode changes (in [_itemsOf]), then prunes
    // departed instances below — so the perk/stat warm survives a poll intact.
    if (!reuseDecoded) _facetsByInstance.clear();

    // Instance ids seen this fetch, so a reuse-refresh can drop cache entries
    // for items that left the account.
    final seen = <String>{};

    // Characters, newest-played first — these become the leading columns.
    final characters = _dataMap(profile['characters'])
        .values
        .map((c) => DestinyCharacter.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateLastPlayed.compareTo(a.dateLastPlayed));

    final equipment = _dataMap(profile['characterEquipment']);
    final charInventories = _dataMap(profile['characterInventories']);

    final owners = <InventoryOwner>[];
    for (final character in characters) {
      final items = <DestinyItem>[
        ...await _itemsOf(equipment[character.characterId], instances,
            equipped: true, reuseDecoded: reuseDecoded, seen: seen),
        ...await _itemsOf(charInventories[character.characterId], instances,
            reuseDecoded: reuseDecoded, seen: seen),
      ];
      owners.add(InventoryOwner(
        id: character.characterId,
        title: character.className,
        isVault: false,
        character: character,
        itemsByBucket: _groupByBucket(items),
      ));
    }

    // Vault (profile inventory). Equipment-slot items in the vault report the
    // General bucket, so they are re-grouped by their definition's bucket.
    final vaultItems = await _itemsOf(profile['profileInventory'], instances,
        useDefBucket: true, reuseDecoded: reuseDecoded, seen: seen);
    owners.add(InventoryOwner(
      id: 'vault',
      title: 'Vault',
      isVault: true,
      itemsByBucket: _groupByBucket(vaultItems),
    ));

    // Drop cache entries for instances no longer owned (a reuse-refresh keeps
    // the caches across fetches, so departed items would otherwise linger).
    if (reuseDecoded) {
      _decodeByInstance.keys.toSet().difference(seen).forEach((id) {
        _decodeByInstance.remove(id);
        _facetsByInstance.remove(id);
      });
    }

    return InventoryGrid(owners);
  }

  /// Resolve the full detail (stats, sockets, breaker) for [item] from the
  /// components cached by the last [fetchInventory]. Uninstanced items have no
  /// instance-keyed data, so they resolve to empty lists.
  ///
  /// [withPerkColumns] additionally resolves the roll's per-socket perk
  /// options ([ItemDetail.perkColumns]) — off by default because the extra
  /// socket walk is wasted work for the facet warm and the detail panel.
  ItemDetail resolveDetail(DestinyItem item, {bool withPerkColumns = false}) {
    final id = item.itemInstanceId;
    final statsData =
        id == null ? null : _stats[id] as Map<String, dynamic>?;
    final socketsData =
        id == null ? null : _sockets[id] as Map<String, dynamic>?;
    final objectivesData =
        id == null ? null : _plugObjectives[id] as Map<String, dynamic>?;

    final catalyst = _resolveCatalyst(item);
    final interpolator = _statInterpolatorFor(item, statsData);
    var plugs = _resolvePlugs(socketsData);
    // Craftable exotics hide the empty catalyst socket on live instances;
    // stand in with the definition's shell plug so the Masterwork section
    // still shows the empty slot.
    if (catalyst != null &&
        !plugs.any((p) => p.category == PlugCategory.masterwork)) {
      final emptySlot = _emptyCatalystPlug(item);
      if (emptySlot != null) plugs = [...plugs, emptySlot];
    }

    return ItemDetail(
      item: item,
      stats: _resolveStats(statsData,
          _resolveStatModifiers(socketsData, interpolator), interpolator),
      plugs: plugs,
      perkColumns: withPerkColumns
          ? _resolveInstancePerkColumns(item, socketsData, interpolator)
          : const [],
      modColumns: withPerkColumns
          ? _resolveInstanceModColumns(item, socketsData, interpolator)
          : const [],
      breaker: _resolveBreaker(item, socketsData),
      killTracker: _resolveKillTracker(socketsData, objectivesData),
      catalyst: catalyst,
    );
  }

  // The WEAPON PERKS socket category (a stable game constant); its sockets
  // are the barrel/magazine/trait/origin columns.
  static const _weaponPerksCategory = 4241085061;

  /// This roll's perk options per weapon-perk socket: the definition's WEAPON
  /// PERKS sockets (which Bungie aligns by index with the instance socket
  /// components), each holding the copy's own options from ItemReusablePlugs
  /// (310) with the active plug from ItemSockets (305) flagged
  /// ([PerkColumn.activeIndex]). Sockets with no instance-keyed options
  /// (fixed perks) fall back to the active plug alone. Empty for uninstanced
  /// items and non-weapons.
  List<PerkColumn> _resolveInstancePerkColumns(DestinyItem item,
      Map<String, dynamic>? socketsData, _StatInterpolator interpolator) {
    final id = item.itemInstanceId;
    if (id == null) return const [];
    final def = _manifest.getInventoryItem(item.itemHash);
    final sockets = def?['sockets'];
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
    if (indexes.isEmpty) return const [];

    final live = socketsData?['sockets'];
    final reusable = (_reusablePlugs[id] as Map<String, dynamic>?)?['plugs'];

    final columns = <PerkColumn>[];
    for (final index in indexes) {
      if (index is! int || index < 0 || index >= entries.length) continue;

      // The active plug on this socket (305).
      int? activeHash;
      var enabled = true;
      if (live is List && index < live.length) {
        final s = live[index] as Map<String, dynamic>;
        if (s['isVisible'] == false) continue;
        activeHash = (s['plugHash'] as num?)?.toInt();
        enabled = s['isEnabled'] != false;
      }

      // The copy's own options for this socket (310); the active plug leads
      // when the options do not already list it (fixed sockets, or an
      // enhanced trait whose base version is the listed option).
      final optionHashes = <int>[];
      final options = reusable is Map ? reusable['$index'] : null;
      if (options is List) {
        for (final o in options) {
          final h = ((o as Map)['plugItemHash'] as num?)?.toInt();
          if (h != null && h != 0 && !optionHashes.contains(h)) {
            optionHashes.add(h);
          }
        }
      }
      if (activeHash != null &&
          activeHash != 0 &&
          !optionHashes.contains(activeHash)) {
        optionHashes.insert(0, activeHash);
      }

      final activePlug = activeHash == null
          ? null
          : _columnPlugOf(activeHash, interpolator,
              isEnabled: enabled, socketIndex: index);
      final plugs = <ItemPlug>[];
      int? activeIndex;
      for (final hash in optionHashes) {
        if (hash == activeHash) {
          if (activePlug == null) continue;
          activeIndex = plugs.length;
          plugs.add(activePlug);
          continue;
        }
        final plug = _columnPlugOf(hash, interpolator, socketIndex: index);
        // An enhanced active trait shares its name with the base option —
        // keep the single (active) chip.
        if (plug == null ||
            (activePlug != null && plug.name == activePlug.name)) {
          continue;
        }
        plugs.add(plug);
      }
      // Keep only real perk columns (tracker/cosmetic sockets classify
      // otherwise and are dropped, matching the definition columns).
      final hasPerk = plugs.any((p) =>
          p.category == PlugCategory.perk ||
          p.category == PlugCategory.frame);
      if (!hasPerk) continue;

      // Column label — preferred source is the plugs' own type names
      // ("Barrel", "Bowstring", "Launcher Barrel", …), since the socket
      // whitelist identifiers vary per weapon family and don't cover them
      // all; the whitelist mapping is the fallback.
      var label = '';
      for (final hash in optionHashes) {
        label = perkColumnLabelFromPlugType(_manifest
            .getInventoryItem(hash)?['itemTypeDisplayName'] as String?);
        if (label.isNotEmpty) break;
      }
      if (label.isEmpty) {
        final typeHash =
            ((entries[index] as Map)['socketTypeHash'] as num?)?.toInt();
        if (typeHash != null) {
          final whitelist =
              _manifest.getSocketType(typeHash)?['plugWhitelist'];
          if (whitelist is List) {
            for (final w in whitelist) {
              label = perkColumnLabelFor(
                  ((w as Map)['categoryIdentifier'] as String?) ?? '');
              if (label.isNotEmpty) break;
            }
          }
        }
      }
      columns.add(PerkColumn(
          plugs: plugs,
          label: label,
          activeIndex: activeIndex,
          socketIndex: index));
    }
    return columns;
  }

  // The WEAPON MODS socket category (a stable game constant); its sockets are
  // the weapon's mod slots (e.g. Backup Mag, Freehand Grip, Boss Spec).
  static const _weaponModsCategory = 2685412949;

  /// This roll's weapon *mod* sockets as columns of selectable options: the
  /// definition's WEAPON MODS sockets, each holding the copy's available mod
  /// plugs (from ItemReusablePlugs (310), falling back to the definition's
  /// reusable plug set) with the equipped plug from ItemSockets (305) flagged
  /// ([PerkColumn.activeIndex]). Empty for uninstanced items and non-weapons, or
  /// when the mod socket offers no alternatives.
  List<PerkColumn> _resolveInstanceModColumns(DestinyItem item,
      Map<String, dynamic>? socketsData, _StatInterpolator interpolator) {
    final id = item.itemInstanceId;
    if (id == null) return const [];
    final def = _manifest.getInventoryItem(item.itemHash);
    final sockets = def?['sockets'];
    if (sockets is! Map) return const [];
    final categories = sockets['socketCategories'];
    final entries = sockets['socketEntries'];
    if (categories is! List || entries is! List) return const [];

    List indexes = const [];
    for (final c in categories) {
      if ((c as Map)['socketCategoryHash'] == _weaponModsCategory) {
        indexes = c['socketIndexes'] as List? ?? const [];
        break;
      }
    }
    if (indexes.isEmpty) return const [];

    final live = socketsData?['sockets'];
    final reusable = (_reusablePlugs[id] as Map<String, dynamic>?)?['plugs'];

    final columns = <PerkColumn>[];
    for (final index in indexes) {
      if (index is! int || index < 0 || index >= entries.length) continue;

      // The equipped mod on this socket (305).
      int? activeHash;
      var enabled = true;
      if (live is List && index < live.length) {
        final s = live[index] as Map<String, dynamic>;
        if (s['isVisible'] == false) continue;
        activeHash = (s['plugHash'] as num?)?.toInt();
        enabled = s['isEnabled'] != false;
      }

      // The socket's available options: the copy's own (310) first, then the
      // definition's reusable plug set as a fallback (crafted/static weapons).
      final optionHashes = <int>[];
      void addOption(int? h) {
        if (h != null && h != 0 && !optionHashes.contains(h)) {
          optionHashes.add(h);
        }
      }

      final options = reusable is Map ? reusable['$index'] : null;
      if (options is List) {
        for (final o in options) {
          addOption(((o as Map)['plugItemHash'] as num?)?.toInt());
        }
      }
      if (optionHashes.isEmpty) {
        final entry = entries[index] as Map<String, dynamic>;
        final setHash = (entry['reusablePlugSetHash'] as num?)?.toInt();
        final setItems =
            setHash == null ? null : _manifest.getPlugSet(setHash)?['reusablePlugItems'];
        if (setItems is List) {
          for (final pi in setItems) {
            addOption(((pi as Map)['plugItemHash'] as num?)?.toInt());
          }
        }
      }
      if (activeHash != null && activeHash != 0) addOption(activeHash);

      final plugs = <ItemPlug>[];
      int? activeIndex;
      for (final hash in optionHashes) {
        final plug = _columnPlugOf(hash, interpolator,
            isEnabled: hash == activeHash ? enabled : true,
            socketIndex: index);
        // Only real mod plugs (the socket may list an empty placeholder).
        if (plug == null || plug.category != PlugCategory.mod) continue;
        if (hash == activeHash) activeIndex = plugs.length;
        plugs.add(plug);
      }
      // A single-option socket (only the equipped mod, no alternatives) is not
      // worth a picker.
      if (plugs.length < 2) continue;

      // No label: the mod picker is a popup off the equipped chip, not a
      // headed column like the perk grid.
      columns.add(PerkColumn(
          plugs: plugs, activeIndex: activeIndex, socketIndex: index));
    }
    return columns;
  }

  /// Resolve [plugHash] for an instance perk column: name, icon, description,
  /// and the enhanced flag. Null for placeholder plugs with no display name
  /// and for kill trackers. Unlike [_resolvePlugs], the origin trait keeps its
  /// clean name — its column label already reads "Origin Trait".
  ItemPlug? _columnPlugOf(int plugHash, _StatInterpolator interpolator,
      {bool isEnabled = true, int socketIndex = -1}) {
    final def = _manifest.getInventoryItem(plugHash);
    if (def == null) return null;
    final display = def['displayProperties'] as Map<String, dynamic>?;
    final name = (display?['name'] as String?) ?? '';
    if (name.isEmpty) return null;
    final plugCategory = def['plug']?['plugCategoryIdentifier'] as String?;
    if (plugCategory != null &&
        plugCategory.contains('masterworks.trackers')) {
      return null;
    }
    final statEffects = _plugStatEffects(def, interpolator);
    return ItemPlug(
      name: name,
      iconPath: (display?['icon'] as String?) ?? '',
      description: _plugDescription(def, display, hasStatEffects: statEffects.isNotEmpty),
      category: classifyPlug(plugCategory),
      isEnabled: isEnabled,
      isEnhanced: isEnhancedPlugDef(def),
      plugHash: plugHash,
      socketIndex: socketIndex,
      statEffects: statEffects,
    );
  }

  /// A plug's effect description: the plug's own `displayProperties.description`
  /// when present, else — only for a plug that has no stat effects — the
  /// description of its first displayable sandbox perk. The sandbox-perk
  /// fallback surfaces prose for descriptive-only perks (e.g. an origin trait),
  /// but is skipped when [hasStatEffects] is true because a bare stat mod's
  /// perk "description" merely restates the stat line ("+10 Stability"), which
  /// the stat-effects row already shows — the fallback would duplicate it.
  String _plugDescription(Map<String, dynamic> def,
      Map<String, dynamic>? display,
      {required bool hasStatEffects}) {
    final direct = (display?['description'] as String?) ?? '';
    if (direct.isNotEmpty) return direct;
    if (hasStatEffects) return '';
    final perks = def['perks'];
    if (perks is List) {
      for (final p in perks) {
        final perkHash = ((p as Map)['perkHash'] as num?)?.toInt();
        if (perkHash == null) continue;
        final perkDef = _manifest.getSandboxPerk(perkHash);
        if (perkDef?['isDisplayable'] == false) continue;
        final text =
            (perkDef?['displayProperties']?['description'] as String?) ?? '';
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  /// The stat changes a plug applies, from its unconditional `investmentStats`.
  /// The tooltip shows the *raw investment* value the game advertises on the mod
  /// (e.g. "−10 Heat Generated"), signed by the stat's effect direction: for an
  /// inverted "lower is better" stat like Heat Generated the curve decreases, so
  /// a positive raw investment reads as a negative (beneficial) number, matching
  /// in-game. (This is distinct from the *applied* delta the bars use — the game
  /// shows the raw here and the smaller applied change on the stat.)
  /// Conditionally-active and zero-valued stats are skipped.
  List<PerkStatEffect> _plugStatEffects(
      Map<String, dynamic> def, _StatInterpolator interpolator) {
    final invStats = def['investmentStats'];
    if (invStats is! List) return const [];
    final effects = <PerkStatEffect>[];
    for (final s in invStats) {
      final st = s as Map<String, dynamic>;
      if (st['isConditionallyActive'] == true) continue;
      final statHash = (st['statTypeHash'] as num?)?.toInt();
      final raw = (st['value'] as num?)?.toInt() ?? 0;
      if (statHash == null || raw == 0) continue;
      final statDef = _manifest.getStat(statHash);
      final name = (statDef?['displayProperties']?['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      // Raw = the number the game advertises (sign-flipped for inverted stats);
      // applied = the actual change to the displayed stat after interpolation.
      // A positive raw investment is always beneficial — it raises a normal stat
      // or lowers an inverted one — so colour by that, not the sign.
      final signedRaw = interpolator.signedRaw(statHash, raw);
      final applied = interpolator.appliedFromRaw(statHash, raw);
      effects.add(PerkStatEffect(
        hash: statHash,
        name: name,
        value: signedRaw,
        // Only carry `applied` when it differs from the shown raw (an
        // interpolated stat); otherwise it would just duplicate the number.
        applied: applied == signedRaw ? null : applied,
        beneficial: raw > 0,
      ));
    }
    return effects;
  }

  /// The searchable [SearchFacets] for an inventory [item], resolved from the
  /// same live components the detail panel uses, plus the item definition's
  /// source and description. Lets the inventory search evaluate the
  /// definition-backed filters (perk/stat/source/breaker/description/keyword)
  /// and the account-only `catalyst:` state. Resolved lazily and cached by
  /// instance id; uninstanced items still resolve (definition facets only).
  SearchFacets inventoryFacetsFor(DestinyItem item) {
    final id = item.itemInstanceId;
    if (id != null) {
      final cached = _facetsByInstance[id];
      if (cached != null) return cached;
    }

    final detail = resolveDetail(item);
    // Socketed perk/frame plugs are the item's rolled traits — the DIM `perk:`
    // target (barrels/mags fold in too, matching the definition-side pool).
    final perks = <String>{
      for (final plug in detail.plugs)
        if (plug.category == PlugCategory.perk ||
            plug.category == PlugCategory.frame)
          plug.name.toLowerCase(),
    };
    final stats = <String, int>{
      for (final s in detail.stats)
        if (s.name.isNotEmpty) s.name.toLowerCase(): s.value,
    };

    final def = _manifest.getInventoryItem(item.itemHash);

    final facets = SearchFacets(
      perks: perks,
      perkColumns: def == null ? const [] : _perkColumnsFor(item, def),
      stats: stats,
      breaker: detail.breaker?.name.toLowerCase(),
      sources: def == null ? const {} : _sourceStringsOf(def),
      description: def == null ? '' : _descriptionOf(def),
      catalyst: _catalystStateOf(detail.catalyst),
    );
    if (id != null) _facetsByInstance[id] = facets;
    return facets;
  }

  /// The rolled perk options for each random *trait* column of this weapon
  /// instance, in column order — the `perk1:`/`perk2:` search targets. Reads the
  /// copy's own options from the live ItemReusablePlugs (310) component at the
  /// definition's trait socket indexes (Bungie aligns the two by index), so a
  /// search matches any perk the column can roll to, not just the equipped one.
  /// Empty for uninstanced items or weapons without random trait sockets.
  List<Set<String>> _perkColumnsFor(DestinyItem item, Map<String, dynamic> def) {
    final id = item.itemInstanceId;
    if (id == null) return const [];
    final builder = FacetBuilder(_manifest);
    final indexes = builder.traitSocketIndexes(def);
    if (indexes.isEmpty) return const [];
    final plugs = (_reusablePlugs[id] as Map<String, dynamic>?)?['plugs'];
    if (plugs is! Map) return const [];

    final columns = <Set<String>>[];
    for (final index in indexes) {
      final options = plugs['$index'];
      if (options is! List) continue;
      final names = <String>{};
      for (final option in options) {
        final plugHash = ((option as Map)['plugItemHash'] as num?)?.toInt();
        final name = plugHash == null ? null : builder.perkNameFor(plugHash);
        if (name != null) names.add(name);
      }
      if (names.isNotEmpty) columns.add(names);
    }
    return columns;
  }

  /// Resolve and cache the search facets for every item in [items] so the first
  /// facet-backed search (`perk:`/`stat:`/`breaker:`/`source:`/`catalyst:`) is
  /// instant instead of decoding lazily on the first keystroke. Purely a warm:
  /// [inventoryFacetsFor] resolves and caches any untouched item on demand, so
  /// search is correct with or without it.
  ///
  /// Each item's socket/stat/catalyst decode is heavy (tens of ms) and must run
  /// on the UI isolate — it reads the live profile components in memory, which a
  /// background isolate cannot see. So the warm resolves exactly ONE item then
  /// yields, keeping every decode inside its own gap between frames rather than
  /// blocking a stretch of them. [onYield] is the yield: the presentation layer
  /// passes a frame-scheduler wait (so a decode lands after the current frame
  /// paints); without it the warm falls back to a microtask yield. Keeping the
  /// yield injected leaves this data-layer class free of a Flutter dependency.
  /// [isCancelled], when it returns true, stops the warm early — the caller
  /// uses it to supersede a stale warm when the grid changes, so a rapid series
  /// of grid updates never leaves several warm loops running concurrently.
  Future<void> warmFacets(
    Iterable<DestinyItem> items, {
    Future<void> Function()? onYield,
    bool Function()? isCancelled,
  }) async {
    for (final item in items) {
      if (isCancelled?.call() ?? false) return;
      // inventoryFacetsFor caches by instance id, so this fills the cache.
      inventoryFacetsFor(item);
      await (onYield?.call() ?? Future<void>.delayed(Duration.zero));
    }
  }

  /// Map a resolved [CatalystProgress] to a search [CatalystState]: not
  /// acquired → missing; acquired and complete → complete; acquired but not
  /// complete → incomplete. Null when the item has no catalyst.
  CatalystState? _catalystStateOf(CatalystProgress? catalyst) {
    if (catalyst == null) return null;
    if (!catalyst.acquired) return CatalystState.missing;
    return catalyst.complete
        ? CatalystState.complete
        : CatalystState.incomplete;
  }

  /// The item's collectible source string(s), lowercased. Empty when the item
  /// has no collectible or source text.
  Set<String> _sourceStringsOf(Map<String, dynamic> def) {
    final collectibleHash = (def['collectibleHash'] as num?)?.toInt();
    if (collectibleHash == null || collectibleHash == 0) return const {};
    final source =
        _manifest.getCollectible(collectibleHash)?['sourceString'] as String?;
    if (source == null || source.isEmpty) return const {};
    return {source.toLowerCase()};
  }

  /// The item's searchable description text: mechanical description plus flavor
  /// (lore) text, lowercased. Empty when it carries neither.
  String _descriptionOf(Map<String, dynamic> def) {
    final parts = [
      (def['displayProperties']?['description'] as String?) ?? '',
      (def['flavorText'] as String?) ?? '',
    ].where((s) => s.isNotEmpty);
    return parts.join(' ').toLowerCase();
  }

  /// The exotic catalyst: its effect (from the weapon definition, so it is
  /// known even before the catalyst is obtained) and its unlock state from the
  /// Records (900) component. The weapon is linked to its catalyst record via
  /// DIM's bundled map, falling back to matching a record named
  /// `<weapon> Catalyst`. Null when the weapon has no catalyst record.
  CatalystProgress? _resolveCatalyst(DestinyItem item) {
    // Preferred: DIM's authoritative itemHash -> recordHash map.
    int? recordHash = _manifest.catalystRecordHashFor(item.itemHash);
    Map<String, dynamic>? record =
        recordHash == null ? null : _manifest.getRecord(recordHash);
    // Fallback: match a record by the "<weapon> Catalyst" name convention.
    record ??= _manifest.findCatalystRecord(item.name);
    if (record == null) return null;
    recordHash = (record['hash'] as num?)?.toInt();
    if (recordHash == null) return null;

    final state = _records['$recordHash'] as Map<String, dynamic>?;
    // DestinyRecordState bit 4 (ObjectiveNotCompleted): set = not yet done.
    // Bit 8 (Obscured): the player has not obtained the catalyst yet. A
    // missing record state is treated the same as not obtained.
    final stateFlags = (state?['state'] as num?)?.toInt() ?? 8;
    final complete = state != null && (stateFlags & 4) == 0;
    final acquired = state != null && (stateFlags & 8) == 0;

    // Each objective, named from its definition (e.g. "Arc Mode Kills").
    final objectives = <CatalystObjective>[];
    final rawObjectives = state?['objectives'];
    if (rawObjectives is List) {
      for (final o in rawObjectives) {
        final obj = o as Map<String, dynamic>;
        final objHash = (obj['objectiveHash'] as num?)?.toInt();
        final objDef = objHash == null ? null : _manifest.getObjective(objHash);
        final name =
            (objDef?['progressDescription'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue; // skip unnamed / trivial insert steps
        objectives.add(CatalystObjective(
          name: name,
          progress: (obj['progress'] as num?)?.toInt() ?? 0,
          completionValue: (obj['completionValue'] as num?)?.toInt() ?? 0,
          complete: obj['complete'] == true,
        ));
      }
    }

    final display = record['displayProperties'] as Map<String, dynamic>?;
    return CatalystProgress(
      name: (display?['name'] as String?) ?? 'Catalyst',
      complete: complete,
      acquired: acquired,
      options: _resolveCatalystOptions(item),
      objectives: objectives,
    );
  }

  /// The catalyst option plugs, resolved from the weapon definition's catalyst
  /// socket: listed inline (classic exotics, Graviton Spike) or in the
  /// socket's plug set (crafted exotics like Slayer's Fang). Each option
  /// carries sandbox perks (e.g. "Ionic Interment") and/or flat stat bonuses
  /// (e.g. +30 Stability); placeholder shell plugs carry neither and are
  /// dropped.
  List<CatalystOption> _resolveCatalystOptions(DestinyItem item) {
    final weaponDef = _manifest.getInventoryItem(item.itemHash);
    final entries = weaponDef?['sockets']?['socketEntries'];
    if (entries is! List) return const [];

    for (final entry in entries) {
      final options = <CatalystOption>[];
      for (final plugHash in _catalystSocketCandidates(entry as Map)) {
        final option = _catalystOptionFrom(plugHash);
        if (option != null) options.add(option);
      }
      // The catalyst socket is unique; stop once it yielded options.
      if (options.isNotEmpty) return options;
    }
    return const [];
  }

  /// Candidate plug hashes of a definition socket entry: the initial plug,
  /// inline entries, and — for sockets that look like the catalyst socket
  /// (masterwork initial plug or no initial plug at all) — the socket's plug
  /// sets. Trait/perk sockets have a real initial plug so their large plug
  /// sets are never fetched.
  List<int> _catalystSocketCandidates(Map socket) {
    final candidates = <int>[];
    final seen = <int>{};
    void add(int? h) {
      if (h != null && h != 0 && seen.add(h)) candidates.add(h);
    }

    final initHash = (socket['singleInitialItemHash'] as num?)?.toInt() ?? 0;
    add(initHash);
    final plugItems = socket['reusablePlugItems'];
    if (plugItems is List) {
      for (final pi in plugItems) {
        add(((pi as Map)['plugItemHash'] as num?)?.toInt());
      }
    }
    final initCat = initHash == 0
        ? ''
        : _manifest.getInventoryItem(initHash)?['plug']
                ?['plugCategoryIdentifier'] as String? ??
            '';
    final catalystish = initHash == 0 ||
        (initCat.contains('masterwork') && !initCat.contains('tracker'));
    if (catalystish) {
      for (final key in ['reusablePlugSetHash', 'randomizedPlugSetHash']) {
        final setHash = (socket[key] as num?)?.toInt();
        if (setHash == null) continue;
        final plugSet = _manifest.getPlugSet(setHash);
        final setItems = plugSet?['reusablePlugItems'];
        if (setItems is! List) continue;
        for (final pi in setItems) {
          add(((pi as Map)['plugItemHash'] as num?)?.toInt());
        }
      }
    }
    return candidates;
  }

  /// The definition's empty-catalyst-socket shell plug, as a Masterwork row.
  /// Craftable exotics hide the empty catalyst socket on live instances, so
  /// when the live sockets yield no masterwork plug this stands in. Null when
  /// the definition has no shell plug.
  ItemPlug? _emptyCatalystPlug(DestinyItem item) {
    final weaponDef = _manifest.getInventoryItem(item.itemHash);
    final entries = weaponDef?['sockets']?['socketEntries'];
    if (entries is! List) return null;

    for (final entry in entries) {
      for (final plugHash in _catalystSocketCandidates(entry as Map)) {
        final def = _manifest.getInventoryItem(plugHash);
        final cat = def?['plug']?['plugCategoryIdentifier'] as String? ?? '';
        final isCatalyst = cat == 'catalysts' ||
            (cat.contains('masterwork') && !cat.contains('tracker'));
        // A shell is a catalyst-category plug with no effect content.
        if (!isCatalyst || _catalystOptionFrom(plugHash) != null) continue;
        final display = def?['displayProperties'] as Map<String, dynamic>?;
        final name = (display?['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        var iconPath = (display?['icon'] as String?) ?? '';
        if (iconPath.isEmpty) {
          // Era-specific shells (e.g. Choir of One's) carry no icon of their
          // own; borrow the classic empty-catalyst-socket plug's icon.
          final classic =
              _manifest.getInventoryItem(_classicEmptyCatalystHash);
          iconPath =
              (classic?['displayProperties']?['icon'] as String?) ?? '';
        }
        return ItemPlug(
          name: name,
          iconPath: iconPath,
          description: (display?['description'] as String?) ?? '',
          category: PlugCategory.masterwork,
          isEnabled: true,
          isEnhanced: false,
        );
      }
    }
    return null;
  }

  /// Build a [CatalystOption] from a plug definition, or null when the plug is
  /// not a catalyst (or is an empty placeholder shell). Catalyst plug
  /// categories vary per weapon era: "catalysts" on crafting-era refits,
  /// otherwise "...masterwork" variants ("v620.exotic.weapon.masterwork",
  /// "v710.new.scout_rifle0.masterwork", "v320_repackage_..._masterwork");
  /// kill trackers share "masterworks" and are excluded.
  CatalystOption? _catalystOptionFrom(int plugHash) {
    final def = _manifest.getInventoryItem(plugHash);
    final cat = def?['plug']?['plugCategoryIdentifier'] as String? ?? '';
    final isCatalyst = cat == 'catalysts' ||
        (cat.contains('masterwork') && !cat.contains('tracker'));
    if (!isCatalyst) return null;

    // Sandbox perks on the plug describe the effect.
    final effects = <CatalystEffect>[];
    final perks = def?['perks'];
    if (perks is List) {
      for (final p in perks) {
        final perkHash = ((p as Map)['perkHash'] as num?)?.toInt();
        if (perkHash == null) continue;
        final perkDef = _manifest.getSandboxPerk(perkHash);
        if (perkDef?['isDisplayable'] == false) continue;
        final display = perkDef?['displayProperties'] as Map<String, dynamic>?;
        final name = (display?['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        effects.add(CatalystEffect(
          name: name,
          description:
              _cleanDisplayText((display?['description'] as String?) ?? ''),
        ));
      }
    }

    // Investment stats are the flat stat bonuses (e.g. +30 Stability).
    final statBonuses = <CatalystStatBonus>[];
    final invStats = def?['investmentStats'];
    if (invStats is List) {
      for (final s in invStats) {
        final statHash = ((s as Map)['statTypeHash'] as num?)?.toInt();
        final value = (s['value'] as num?)?.toInt() ?? 0;
        if (statHash == null || value == 0) continue;
        final statDef = _manifest.getStat(statHash);
        final name = (statDef?['displayProperties']?['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        statBonuses.add(CatalystStatBonus(name: name, value: value));
      }
    }

    if (effects.isEmpty && statBonuses.isEmpty) return null;
    final name =
        (def?['displayProperties']?['name'] as String?) ?? 'Catalyst';
    return CatalystOption(
        name: name, effects: effects, statBonuses: statBonuses);
  }

  /// Replace Bungie's `[###DestinyNamedSubstitutions...###]` template tokens
  /// (platform-specific button glyphs in game) with readable text, stripping
  /// any unrecognised token.
  static String _cleanDisplayText(String text) {
    if (!text.contains('[###')) return text;
    const substitutions = {
      '[###DestinyNamedSubstitutions.ui_player_action_interact_button###]':
          '[Interact]',
      '[###DestinyNamedSubstitutions.ui_player_action_interact_verb###]': '',
      '[###DestinyNamedSubstitutions.ui_player_action_jump_button###]':
          '[Jump]',
    };
    var out = text;
    substitutions.forEach((token, word) => out = out.replaceAll(token, word));
    out = out.replaceAll(RegExp(r'\[###[^\]]*###\]'), '');
    return out.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  /// The masterwork kill tracker: the tracker plug's icon plus its objective
  /// progress from the plugObjectives (309) component. Null when the item has
  /// no tracker socket.
  KillTracker? _resolveKillTracker(
    Map<String, dynamic>? socketsData,
    Map<String, dynamic>? objectivesData,
  ) {
    final sockets = socketsData?['sockets'];
    if (sockets is! List) return null;
    final objectivesPerPlug =
        objectivesData?['objectivesPerPlug'] as Map<String, dynamic>?;

    for (final socket in sockets) {
      final plugHash = ((socket as Map)['plugHash'] as num?)?.toInt();
      if (plugHash == null) continue;
      final def = _manifest.getInventoryItem(plugHash);
      final cat = def?['plug']?['plugCategoryIdentifier'] as String?;
      if (cat == null || !cat.contains('masterworks.trackers')) continue;

      final display = def?['displayProperties'] as Map<String, dynamic>?;
      final iconPath = (display?['icon'] as String?) ?? '';
      // Objective progress for this plug (first objective is the kill count).
      final objectives = objectivesPerPlug?['$plugHash'];
      var count = 0;
      if (objectives is List && objectives.isNotEmpty) {
        count = ((objectives.first as Map)['progress'] as num?)?.toInt() ?? 0;
      }
      return KillTracker(iconPath: iconPath, count: count);
    }
    return null;
  }

  /// The item's champion breaker. Exotics carry it as `breakerTypeHash` on
  /// their own definition; legendaries express it as a marker sandbox perk on
  /// their intrinsic frame plug (e.g. "[Stagger] Unstoppable"), so the socket
  /// plugs' perks are scanned for one.
  BreakerType? _resolveBreaker(
      DestinyItem item, Map<String, dynamic>? socketsData) {
    // 1. Exotic intrinsic breaker on the item definition.
    final def = _manifest.getInventoryItem(item.itemHash);
    final hash = (def?['breakerTypeHash'] as num?)?.toInt();
    if (hash != null && hash != 0) {
      final breakerDef = _manifest.getBreakerType(hash);
      final display = breakerDef?['displayProperties'] as Map<String, dynamic>?;
      final name = (display?['name'] as String?) ?? '';
      if (name.isNotEmpty) {
        return BreakerType(
            name: name, iconPath: (display?['icon'] as String?) ?? '');
      }
    }

    // 2. Frame-granted breaker: a marker sandbox perk on a socket plug.
    final sockets = socketsData?['sockets'];
    if (sockets is! List) return null;
    for (final socket in sockets) {
      final plugHash = ((socket as Map)['plugHash'] as num?)?.toInt();
      if (plugHash == null) continue;
      final plugDef = _manifest.getInventoryItem(plugHash);
      final perks = plugDef?['perks'];
      if (perks is! List) continue;
      for (final perk in perks) {
        final perkHash = ((perk as Map)['perkHash'] as num?)?.toInt();
        if (perkHash == null) continue;
        final perkDef = _manifest.getSandboxPerk(perkHash);
        final display =
            perkDef?['displayProperties'] as Map<String, dynamic>?;
        final rawName = (display?['name'] as String?) ?? '';
        final breaker = _breakerFromMarker(rawName);
        if (breaker != null) {
          return BreakerType(
              name: breaker, iconPath: (display?['icon'] as String?) ?? '');
        }
      }
    }
    return null;
  }

  /// Maps a marker perk name like "[Stagger] Unstoppable" to a clean breaker
  /// label, or null when the name carries no breaker marker.
  static String? _breakerFromMarker(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('[stagger]') || lower.contains('unstoppable')) {
      return 'Unstoppable';
    }
    if (lower.contains('[disruption]') || lower.contains('overload')) {
      return 'Overload';
    }
    if (lower.contains('[shield-piercing]') ||
        lower.contains('[shield piercing]') ||
        lower.contains('barrier')) {
      return 'Barrier';
    }
    return null;
  }

  // Stats shown as an absolute number rather than a 0-100 bar (their values are
  // not on a 0-100 scale). Matched by name, case-insensitively.
  static const _numericStatNames = {
    'rounds per minute',
    'rpm',
    'draw time',
    'charge time',
    'magazine',
    'rounds per magazine',
    'zoom',
    'swing speed',
    'ammo capacity',
    'guard efficiency',
    'guard resistance',
    'guard endurance',
    'charge rate',
    'heat generated',
    'cooling efficiency',
  };

  /// Build the stat interpolator for [item] from its weapon stat group and the
  /// live [statsData] (304) base values. The group's
  /// `scaledStats[].displayInterpolation` maps a stat's raw investment to the
  /// displayed value; a plug's *applied* effect is the change in that displayed
  /// value it causes — what the bars must show, not the raw investment (which
  /// the game scales/inverts). Empty (identity) when the item has no stat group.
  _StatInterpolator _statInterpolatorFor(
      DestinyItem item, Map<String, dynamic>? statsData) {
    final bases = <int, int>{};
    final map = statsData?['stats'];
    if (map is Map) {
      for (final entry in map.values) {
        final h = ((entry as Map)['statHash'] as num?)?.toInt();
        final v = (entry['value'] as num?)?.toInt();
        if (h != null && v != null) bases[h] = v;
      }
    }
    final def = _manifest.getInventoryItem(item.itemHash);
    final groupHash = (def?['stats']?['statGroupHash'] as num?)?.toInt();
    final scaled =
        groupHash == null ? null : _manifest.getStatGroup(groupHash)?['scaledStats'];
    final curves = <int, List<({double input, double output})>>{};
    if (scaled is List) {
      for (final s in scaled) {
        final statHash = ((s as Map)['statHash'] as num?)?.toInt();
        final interp = s['displayInterpolation'];
        if (statHash == null || interp is! List) continue;
        // Bungie/DIM convention: a knot's `value` is the investment input and
        // its `weight` is the displayed output.
        final knots = <({double input, double output})>[
          for (final k in interp)
            (
              input: ((k as Map)['value'] as num?)?.toDouble() ?? 0,
              output: (k['weight'] as num?)?.toDouble() ?? 0,
            ),
        ]..sort((a, b) => a.input.compareTo(b.input));
        if (knots.isNotEmpty) curves[statHash] = knots;
      }
    }
    return _StatInterpolator(curves, bases);
  }

  List<ItemStat> _resolveStats(
    Map<String, dynamic>? statsData,
    ({Map<int, int> modGains, Map<int, int> masterworkGains, Map<int, int> losses})
        modifiers,
    _StatInterpolator interpolator,
  ) {
    final map = statsData?['stats'];
    if (map is! Map) return const [];
    final result = <ItemStat>[];
    for (final entry in map.values) {
      final e = entry as Map<String, dynamic>;
      final statHash = (e['statHash'] as num?)?.toInt();
      final value = (e['value'] as num?)?.toInt();
      if (statHash == null || value == null) continue;
      final def = _manifest.getStat(statHash);
      final name = (def?['displayProperties']?['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      final display = lower == 'recoil direction'
          ? StatDisplay.recoil
          : _numericStatNames.contains(lower)
              ? StatDisplay.numeric
              : StatDisplay.bar;
      // Clamp the two gains so their combined segment never exceeds the value
      // (stat values can go negative — armor tuning — so a non-positive value
      // shows no gain segment). The mod segment takes precedence in the clamp
      // budget; the masterwork segment fills what remains.
      final headroom = value > 0 ? value : 0;
      final mod = (modifiers.modGains[statHash] ?? 0).clamp(0, headroom);
      final mw = (modifiers.masterworkGains[statHash] ?? 0)
          .clamp(0, headroom - mod);
      result.add(ItemStat(
        name: name,
        value: value,
        display: display,
        modBonus: mod,
        masterworkBonus: mw,
        reduction: modifiers.losses[statHash] ?? 0,
        inverted: interpolator.isInverted(statHash),
      ));
    }
    return sortStatsForDisplay(result);
  }

  /// Per-stat *applied* contributions of the equipped plugs (their investment
  /// stats run through the weapon's [interpolator]), keyed by stat hash, split
  /// by source: [modGains] is what weapon *mods* add (the blue bar segment) and
  /// [masterworkGains] is what the masterwork / catalyst adds (the gold segment);
  /// [losses] is what plugs of any kind subtract (the red deficit segment).
  /// Positive perk contributions count as part of the base roll.
  ///
  /// The applied value — not the raw investment — is used, so an inverted or
  /// scaled stat (e.g. Heat Generated, where +10 raw investment applies as -1)
  /// shows the real in-game effect. Routing is by the sign of that *applied*
  /// delta: a mod whose raw value is positive but applies negatively lands in
  /// [losses]. [displayedBase] per stat comes from ItemStats (304), already
  /// interpolated by the game, so the plug's applied delta is measured against
  /// it.
  ({Map<int, int> modGains, Map<int, int> masterworkGains, Map<int, int> losses})
      _resolveStatModifiers(
    Map<String, dynamic>? socketsData,
    _StatInterpolator interpolator,
  ) {
    final modGains = <int, int>{};
    final masterworkGains = <int, int>{};
    final losses = <int, int>{};
    final sockets = socketsData?['sockets'];
    if (sockets is! List) {
      return (
        modGains: modGains,
        masterworkGains: masterworkGains,
        losses: losses
      );
    }
    for (final socket in sockets) {
      final s = socket as Map<String, dynamic>;
      if (s['isEnabled'] == false) continue;
      final plugHash = (s['plugHash'] as num?)?.toInt();
      if (plugHash == null) continue;
      final def = _manifest.getInventoryItem(plugHash);
      final plugCategory =
          def?['plug']?['plugCategoryIdentifier'] as String?;
      final category = classifyPlug(plugCategory);
      // A mod's applied gain shows blue; the masterwork/catalyst's shows gold.
      final gainsForCategory = category == PlugCategory.masterwork
          ? masterworkGains
          : category == PlugCategory.mod
              ? modGains
              : null;
      final invStats = def?['investmentStats'];
      if (invStats is! List) continue;
      for (final stat in invStats) {
        final st = stat as Map<String, dynamic>;
        if (st['isConditionallyActive'] == true) continue;
        final statHash = (st['statTypeHash'] as num?)?.toInt();
        final raw = (st['value'] as num?)?.toInt() ?? 0;
        if (statHash == null || raw == 0) continue;
        final applied = interpolator.appliedFromRaw(statHash, raw);
        if (applied == 0) continue;
        if (applied < 0) {
          losses[statHash] = (losses[statHash] ?? 0) - applied;
        } else if (gainsForCategory != null) {
          gainsForCategory[statHash] = (gainsForCategory[statHash] ?? 0) + applied;
        }
      }
    }
    return (
      modGains: modGains,
      masterworkGains: masterworkGains,
      losses: losses
    );
  }

  List<ItemPlug> _resolvePlugs(Map<String, dynamic>? socketsData) {
    final sockets = socketsData?['sockets'];
    if (sockets is! List) return const [];
    final result = <ItemPlug>[];
    // The socket's position in this list is its socket index, which pairs with
    // the plug hash to insert a selected plug in-game (weapon mods). Enumerate
    // by position — a skipped (invisible) socket must not shift the index.
    for (var socketIndex = 0; socketIndex < sockets.length; socketIndex++) {
      final s = sockets[socketIndex] as Map<String, dynamic>;
      if (s['isVisible'] == false) continue;
      final plugHash = (s['plugHash'] as num?)?.toInt();
      if (plugHash == null) continue;
      final def = _manifest.getInventoryItem(plugHash);
      if (def == null) continue;
      final display = def['displayProperties'] as Map<String, dynamic>?;
      var name = (display?['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final plug = def['plug'] as Map<String, dynamic>?;
      final plugCategory = plug?['plugCategoryIdentifier'] as String?;
      // The kill tracker is surfaced in the header instead of a plug section.
      if (plugCategory != null &&
          plugCategory.contains('masterworks.trackers')) {
        continue;
      }
      // Label the weapon's origin trait so it stands out among the perks.
      if (plugCategory == 'origins') {
        name = '$name - Origin Trait';
      }
      final enhanced = isEnhancedPlugDef(def);
      var category = classifyPlug(plugCategory);
      // Craftables' "Empty Memento Socket" shares the generic crafting
      // empty-socket category with trait/frame sockets; mementos (empty or
      // filled) belong with the cosmetics.
      if (plugCategory == 'crafting.recipes.empty_socket' &&
          name.toLowerCase().contains('memento')) {
        category = PlugCategory.cosmetic;
      }
      result.add(ItemPlug(
        name: name,
        iconPath: (display?['icon'] as String?) ?? '',
        description: (display?['description'] as String?) ?? '',
        category: category,
        isEnabled: s['isEnabled'] != false,
        isEnhanced: enhanced,
        plugHash: plugHash,
        socketIndex: socketIndex,
      ));
    }
    return result;
  }

  /// Resolve the `items` list of an inventory/equipment component into display
  /// items, keeping only those in a known equipment bucket.
  ///
  /// Each item costs several synchronous manifest lookups (definition, ornament
  /// sockets, damage/icon layers), so resolving a full profile in one stretch
  /// blocks the frame that keeps the loading spinner animating. Yielding every
  /// [_resolveBatch] items breaks the work into chunks the event loop can
  /// interleave with frame rendering, so the spinner stays smooth up to the
  /// handoff — the same batching the facet warm and gear index scan use.
  Future<List<DestinyItem>> _itemsOf(
    dynamic component,
    Map<String, dynamic> instances, {
    bool equipped = false,
    bool useDefBucket = false,
    bool reuseDecoded = false,
    Set<String>? seen,
  }) async {
    final map = component is Map<String, dynamic> ? component : null;
    final data = map?['data'];
    final items = (data is Map<String, dynamic> ? data['items'] : null) ??
        (map?['items']);
    if (items is! List) return const [];

    final result = <DestinyItem>[];
    var processed = 0;
    for (final raw in items) {
      if (++processed % _resolveBatch == 0) await Future<void>.delayed(Duration.zero);
      final item = raw as Map<String, dynamic>;
      final itemHash = (item['itemHash'] as num?)?.toInt();
      if (itemHash == null) continue;

      // Reuse the previously-decoded item when every input its decode reads is
      // unchanged (background refresh only). The signature captures the raw
      // item, its instance data, and its socket plugs — so a re-ornamented,
      // re-rolled, moved, (un)locked, or masterworked item re-decodes.
      final instanceId = item['itemInstanceId']?.toString();
      final instance = instanceId == null
          ? null
          : instances[instanceId] as Map<String, dynamic>?;
      final signature =
          instanceId == null ? null : _decodeSignature(item, instance, equipped);
      if (instanceId != null) seen?.add(instanceId);
      if (reuseDecoded && instanceId != null && signature != null) {
        final cached = _decodeByInstance[instanceId];
        if (cached != null && cached.sig == signature) {
          // Unchanged: reuse the decode AND keep its cached facets.
          result.add(cached.item);
          continue;
        }
      }
      // Reaching here means this item is (re)decoding, so its cached facets may
      // be stale — evict them on a reuse-refresh (a full fetch already cleared
      // them). Unchanged items above skip this and keep their warm facets.
      if (reuseDecoded && instanceId != null) {
        _facetsByInstance.remove(instanceId);
      }

      final def = _manifest.getInventoryItem(itemHash);
      if (def == null) continue;

      // Bucket: the item's own bucketHash, unless it sits in the vault's
      // general bucket, in which case fall back to the definition's bucket.
      final defBucket =
          (def['inventory']?['bucketTypeHash'] as num?)?.toInt();
      final itemBucket = (item['bucketHash'] as num?)?.toInt();
      final bucketHash = useDefBucket ? (defBucket ?? itemBucket) : itemBucket;
      if (bucketHash == null || EquipmentBucket.fromHash(bucketHash) == null) {
        continue; // only weapon/armor slots are shown
      }

      final display = def['displayProperties'] as Map<String, dynamic>?;
      final state = (item['state'] as num?)?.toInt() ?? 0;
      final tierType = (def['inventory']?['tierType'] as num?)?.toInt() ?? 0;

      // Element glyph comes from the damage-type definition (its transparent
      // icon), resolved via the instance's damageTypeHash.
      final damageTypeHash =
          (instance?['damageTypeHash'] as num?)?.toInt();
      String? elementIconPath;
      if (damageTypeHash != null) {
        final dmgDef = _manifest.getDamageType(damageTypeHash);
        elementIconPath = (dmgDef?['transparentIconPath'] as String?) ??
            (dmgDef?['displayProperties']?['icon'] as String?);
      }

      // An applied ornament's flat icon carries the ornament's own (legendary)
      // background. For exotics we instead composite the ornament's transparent
      // foreground over the exotic's rarity plate, so the tile keeps the exotic
      // background (mirrors how DIM layers the icon definition).
      final ornamentDef =
          instanceId == null ? null : _appliedOrnamentDef(instanceId);
      final ornamentIconPath =
          ornamentDef?['displayProperties']?['icon'] as String?;
      String? ornamentForegroundPath;
      String? rarityPlatePath;
      if (ornamentDef != null && tierType == 6) {
        final fg = _foregroundPath(ornamentDef);
        final plate = _backgroundPath(def);
        if (fg != null && plate != null) {
          ornamentForegroundPath = fg;
          rarityPlatePath = plate;
        }
      }

      final decoded = DestinyItem(
        itemHash: itemHash,
        bucketHash: bucketHash,
        name: (display?['name'] as String?) ?? '',
        iconPath: (display?['icon'] as String?) ?? '',
        ornamentIconPath: ornamentIconPath,
        ornamentForegroundPath: ornamentForegroundPath,
        rarityPlatePath: rarityPlatePath,
        itemType: (def['itemType'] as num?)?.toInt() ?? 0,
        itemSubType: (def['itemSubType'] as num?)?.toInt() ?? 0,
        tierType: tierType,
        classType: (def['classType'] as num?)?.toInt(),
        ammoType: (def['equippingBlock']?['ammoType'] as num?)?.toInt() ?? 0,
        itemTypeDisplayName:
            (def['itemTypeDisplayName'] as String?) ?? '',
        itemInstanceId: instanceId,
        power: (instance?['primaryStat']?['value'] as num?)?.toInt(),
        damageType: (instance?['damageType'] as num?)?.toInt(),
        elementIconPath: elementIconPath,
        isEquipped: equipped,
        // ItemState bit flags: Locked=1, Masterwork=4.
        isLocked: state & 1 != 0,
        isMasterwork: state & 4 != 0,
      );
      result.add(decoded);
      // Cache the fresh decode + its signature so a later refresh can reuse it.
      if (instanceId != null && signature != null) {
        _decodeByInstance[instanceId] = (sig: signature, item: decoded);
      }
    }
    return result;
  }

  /// A value signature of every raw input [_itemsOf]'s decode depends on for an
  /// instanced item: the raw item component (hash/bucket/state), whether it is
  /// equipped, its instance data (power/damage), and the enabled socket plug
  /// hashes (which drive the applied-ornament icon). Two fetches producing the
  /// same signature decode to an identical [DestinyItem], so the prior decode
  /// can be reused. Cheap: field reads plus a plain plug-hash join, no manifest
  /// lookups — the work the reuse avoids.
  String _decodeSignature(
      Map<String, dynamic> item, Map<String, dynamic>? instance, bool equipped) {
    final itemHash = (item['itemHash'] as num?)?.toInt();
    final bucketHash = (item['bucketHash'] as num?)?.toInt();
    final state = (item['state'] as num?)?.toInt() ?? 0;
    final power = (instance?['primaryStat']?['value'] as num?)?.toInt();
    final damageType = (instance?['damageType'] as num?)?.toInt();
    final damageTypeHash = (instance?['damageTypeHash'] as num?)?.toInt();

    final instanceId = item['itemInstanceId']?.toString();
    final socketsData =
        instanceId == null ? null : _sockets[instanceId] as Map<String, dynamic>?;
    final sockets = socketsData?['sockets'];
    final plugs = StringBuffer();
    if (sockets is List) {
      for (final socket in sockets) {
        final s = socket as Map<String, dynamic>;
        if (s['isEnabled'] == false) continue;
        plugs
          ..write((s['plugHash'] as num?)?.toInt() ?? 0)
          ..write(',');
      }
    }
    return '$itemHash|$bucketHash|$state|$equipped|$power|$damageType|'
        '$damageTypeHash|$plugs';
  }

  /// The applied ornament's plug definition for an instance, or null when none
  /// (or only the default ornament) is socketed. Ornament plugs are
  /// itemSubType 21 / skin-category plugs; shaders ("shader") are not icon
  /// overrides.
  Map<String, dynamic>? _appliedOrnamentDef(String instanceId) {
    final socketsData = _sockets[instanceId] as Map<String, dynamic>?;
    final sockets = socketsData?['sockets'];
    if (sockets is! List) return null;
    for (final socket in sockets) {
      final s = socket as Map<String, dynamic>;
      if (s['isEnabled'] == false) continue;
      final plugHash = (s['plugHash'] as num?)?.toInt();
      if (plugHash == null || _defaultOrnamentHashes.contains(plugHash)) {
        continue;
      }
      final def = _manifest.getInventoryItem(plugHash);
      if (def == null) continue;
      // New eras add fresh "Default Ornament" plug hashes; match the name too
      // so unknown variants never override the item icon.
      if (def['displayProperties']?['name'] == 'Default Ornament') continue;
      final cat = def['plug']?['plugCategoryIdentifier'] as String? ?? '';
      final isOrnament =
          (def['itemSubType'] as num?)?.toInt() == 21 || cat.contains('skins');
      if (!isOrnament) continue;
      final icon = def['displayProperties']?['icon'] as String?;
      if (icon != null && icon.isNotEmpty) return def;
    }
    return null;
  }

  /// The `foreground` (transparent art) path from a definition's layered icon,
  /// resolved via `displayProperties.iconHash`. Null when absent.
  String? _foregroundPath(Map<String, dynamic>? def) {
    final iconHash = (def?['displayProperties']?['iconHash'] as num?)?.toInt();
    if (iconHash == null) return null;
    final fg = _manifest.getIcon(iconHash)?['foreground'] as String?;
    return (fg == null || fg.isEmpty) ? null : fg;
  }

  /// The `background` (rarity plate) path from a definition's layered icon.
  /// Null when absent.
  String? _backgroundPath(Map<String, dynamic> def) {
    final iconHash = (def['displayProperties']?['iconHash'] as num?)?.toInt();
    if (iconHash == null) return null;
    final bg = _manifest.getIcon(iconHash)?['background'] as String?;
    return (bg == null || bg.isEmpty) ? null : bg;
  }

  Map<int, List<DestinyItem>> _groupByBucket(List<DestinyItem> items) {
    final grouped = <int, List<DestinyItem>>{};
    for (final item in items) {
      (grouped[item.bucketHash] ??= []).add(item);
    }
    // Equipped first, then by power descending (the shared canonical order).
    return grouped.map((k, v) => MapEntry(k, sortBucketItems(v)));
  }

  Map<String, dynamic> _dataMap(dynamic component) {
    if (component is Map<String, dynamic>) {
      final data = component['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return const {};
  }

  /// Merge the record components into a single record-hash -> record map.
  /// Catalyst records may be tracked at the profile scope or per-character;
  /// combining both means a lookup finds the record wherever it lives.
  Map<String, dynamic> _mergeRecords(Map<String, dynamic> profile) {
    final merged = <String, dynamic>{};

    void addFrom(dynamic recordsHolder) {
      final records = recordsHolder is Map<String, dynamic>
          ? recordsHolder['records']
          : null;
      if (records is Map<String, dynamic>) merged.addAll(records);
    }

    // Profile scope: profileRecords.data.records
    final profileRecordsData =
        (profile['profileRecords'] is Map<String, dynamic>)
            ? (profile['profileRecords'] as Map<String, dynamic>)['data']
            : null;
    addFrom(profileRecordsData);

    // Character scope: characterRecords.data.<charId>.records
    final charRecords = _dataMap(profile['characterRecords']);
    for (final entry in charRecords.values) {
      addFrom(entry);
    }
    return merged;
  }
}

/// Converts a stat's raw investment value to its displayed value using the
/// weapon stat group's per-stat `displayInterpolation`, a piecewise-linear
/// curve. Bungie's field convention (matching DIM): each knot's `value` is the
/// investment input and `weight` is the displayed output. A plug's *applied*
/// effect is the change in displayed value it causes —
/// `interp(base + plug) − interp(base)` — not its raw investment, which the
/// game scales and can invert (Zealous Ideal's Heat Generated: +10 raw
/// investment on a base of 18 applies as −2). Stats with no curve map 1:1.
class _StatInterpolator {
  const _StatInterpolator(this._curves, this._bases);

  /// Per stat, the interpolation knots as `(input: investment, output:
  /// displayed)`, sorted by input ascending.
  final Map<int, List<({double input, double output})>> _curves;

  /// The base investment value per stat (ItemStats 304), the point a plug's
  /// applied delta is measured from.
  final Map<int, int> _bases;

  /// The displayed value for an [investment] of [statHash], via linear
  /// interpolation between the curve's knots (clamped to the endpoints).
  /// Returns [investment] unchanged when the stat has no curve (a 1:1 stat).
  double _display(int statHash, double investment) {
    final knots = _curves[statHash];
    if (knots == null || knots.isEmpty) return investment;
    if (investment <= knots.first.input) return knots.first.output;
    if (investment >= knots.last.input) return knots.last.output;
    for (var i = 0; i < knots.length - 1; i++) {
      final lo = knots[i], hi = knots[i + 1];
      if (investment >= lo.input && investment <= hi.input) {
        final span = hi.input - lo.input;
        if (span == 0) return lo.output;
        final t = (investment - lo.input) / span;
        return lo.output + t * (hi.output - lo.output);
      }
    }
    return knots.last.output;
  }

  /// The applied (displayed) effect on [statHash] of a plug contributing
  /// [rawValue] raw investment: the displayed value with this plug's investment
  /// added minus the displayed value at the base — `interp(base + raw) −
  /// interp(base)`. Rounded to the nearest integer, matching the game. For a 1:1
  /// stat — or one with no known base — this equals [rawValue].
  int appliedFromRaw(int statHash, int rawValue) {
    if (rawValue == 0) return 0;
    final base = _bases[statHash];
    if (base == null || !_curves.containsKey(statHash)) return rawValue;
    final withPlug = _display(statHash, (base + rawValue).toDouble());
    final without = _display(statHash, base.toDouble());
    return (withPlug - without).round();
  }

  /// The raw investment [rawValue] signed by [statHash]'s effect direction: for
  /// an [isInverted] stat (the curve's displayed output decreases as investment
  /// rises, e.g. Heat Generated) the sign is flipped so a beneficial reduction
  /// reads negative, matching the mod's in-game tooltip. Unchanged otherwise.
  int signedRaw(int statHash, int rawValue) =>
      isInverted(statHash) ? -rawValue : rawValue;

  /// Whether [statHash]'s displayed value *decreases* as investment increases —
  /// a "lower is better" stat (Heat Generated), where the effect direction is
  /// the opposite of the raw investment sign. False for a stat with no curve.
  bool isInverted(int statHash) {
    final knots = _curves[statHash];
    if (knots == null || knots.length < 2) return false;
    return knots.last.output < knots.first.output;
  }
}
