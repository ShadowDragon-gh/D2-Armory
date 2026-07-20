import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/sqlite3.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../repositories/facet_builder.dart' show FacetSource;

/// Read-only access to a downloaded Destiny manifest SQLite file.
///
/// Every definition table has the same shape: an `id` column (the definition
/// hash, stored as a *signed* 32-bit int) and a `json` text column. API
/// responses use *unsigned* hashes, so lookups convert to the signed form.
class ManifestDatabase implements FacetSource {
  ManifestDatabase._(this._db);

  final Database _db;

  /// Open the manifest at [path]. The file must already exist.
  factory ManifestDatabase.open(String path) =>
      ManifestDatabase._(sqlite3.open(path, mode: OpenMode.readOnly));

  /// Wrap an already-open [Database] (an in-memory fixture) for tests that
  /// exercise the query methods without a manifest file on disk.
  @visibleForTesting
  factory ManifestDatabase.forTest(Database db) = ManifestDatabase._;

  /// Look up a single definition by unsigned [hash] from [table]
  /// (e.g. `DestinyInventoryItemDefinition`). Returns the decoded JSON, or null
  /// if absent.
  Map<String, dynamic>? getDefinition(String table, int hash) {
    final result =
        _db.select('SELECT json FROM $table WHERE id = ?', [signedHash(hash)]);
    if (result.isEmpty) return null;
    return jsonDecode(result.first['json'] as String) as Map<String, dynamic>;
  }

  /// Convenience for the most-used table.
  @override
  Map<String, dynamic>? getInventoryItem(int hash) =>
      getDefinition('DestinyInventoryItemDefinition', hash);

  Map<String, dynamic>? getDamageType(int hash) =>
      getDefinition('DestinyDamageTypeDefinition', hash);

  @override
  Map<String, dynamic>? getStat(int hash) =>
      getDefinition('DestinyStatDefinition', hash);

  Map<String, dynamic>? getStatGroup(int hash) =>
      getDefinition('DestinyStatGroupDefinition', hash);

  @override
  Map<String, dynamic>? getBreakerType(int hash) =>
      getDefinition('DestinyBreakerTypeDefinition', hash);

  Map<String, dynamic>? getObjective(int hash) =>
      getDefinition('DestinyObjectiveDefinition', hash);

  @override
  Map<String, dynamic>? getCollectible(int hash) =>
      getDefinition('DestinyCollectibleDefinition', hash);

  /// A socket-category definition (its display name), for labelling a
  /// subclass's socket groups (Abilities, Super, Aspects, Fragments).
  Map<String, dynamic>? getSocketCategory(int hash) =>
      getDefinition('DestinySocketCategoryDefinition', hash);

  @override
  Map<String, dynamic>? getPlugSet(int hash) =>
      getDefinition('DestinyPlugSetDefinition', hash);

  /// An armor-set definition (its member item hashes and set-bonus perks).
  Map<String, dynamic>? getEquipableItemSet(int hash) =>
      getDefinition('DestinyEquipableItemSetDefinition', hash);

  /// Every armor-set definition's decoded JSON. Small table (~dozens of sets),
  /// read once to build the reverse item → set index. Fixed table name, no
  /// bound parameters, so there is no SQL-injection surface.
  @override
  List<Map<String, dynamic>> allEquipableItemSets() {
    final rows =
        _db.select('SELECT json FROM DestinyEquipableItemSetDefinition');
    return [
      for (final r in rows)
        jsonDecode(r['json'] as String) as Map<String, dynamic>,
    ];
  }

  /// Every damage-type definition's decoded JSON (a handful of rows), for
  /// lookups keyed by `enumValue` rather than hash (e.g. the Clarity marker
  /// icons). Fixed table name, no bound parameters.
  List<Map<String, dynamic>> allDamageTypes() {
    final rows = _db.select('SELECT json FROM DestinyDamageTypeDefinition');
    return [
      for (final r in rows)
        jsonDecode(r['json'] as String) as Map<String, dynamic>,
    ];
  }

  /// Every breaker-type definition's decoded JSON (three rows), for lookups
  /// keyed by `enumValue`. Fixed table name, no bound parameters.
  List<Map<String, dynamic>> allBreakerTypes() {
    final rows = _db.select('SELECT json FROM DestinyBreakerTypeDefinition');
    return [
      for (final r in rows)
        jsonDecode(r['json'] as String) as Map<String, dynamic>,
    ];
  }

  /// The layered icon definition (`foreground`/`background`/watermark paths)
  /// referenced by an item's `displayProperties.iconHash`.
  Map<String, dynamic>? getIcon(int hash) =>
      getDefinition('DestinyIconDefinition', hash);

  // The columns every gear/ability list row projects (via json_extract, no
  // full-JSON decode). `pci` (the plug category identifier) is null for
  // weapon/armor rows and carries the taxonomy segment the ability kind derives
  // its class/element from.
  static const _summaryColumns = "SELECT "
      "json_extract(json,'\$.hash') AS hash, "
      "json_extract(json,'\$.displayProperties.name') AS name, "
      "json_extract(json,'\$.displayProperties.icon') AS icon, "
      "json_extract(json,'\$.inventory.tierType') AS tierType, "
      "json_extract(json,'\$.itemType') AS itemType, "
      "json_extract(json,'\$.itemSubType') AS itemSubType, "
      "json_extract(json,'\$.itemTypeDisplayName') AS itemTypeDisplayName, "
      "json_extract(json,'\$.classType') AS classType, "
      "json_extract(json,'\$.defaultDamageType') AS damageType, "
      "json_extract(json,'\$.defaultDamageTypeHash') AS damageTypeHash, "
      "json_extract(json,'\$.equippingBlock.ammoType') AS ammoType, "
      "json_extract(json,'\$.inventory.bucketTypeHash') AS bucketHash, "
      "json_extract(json,'\$.iconWatermark') AS watermark, "
      "json_extract(json,'\$.plug.plugCategoryIdentifier') AS pci, "
      "json_extract(json,'\$.index') AS idx "
      "FROM DestinyInventoryItemDefinition WHERE ";

  /// Enumerate all real definitions of [kind] — weapons/armor as list rows, or
  /// (for [GearKind.ability]) every subclass ability plug — projecting only the
  /// fields a list row needs via `json_extract` (no full-JSON decode per row,
  /// measured ~400ms cheaper than decoding every blob).
  ///
  /// Weapons/armor: excludes redacted, non-equippable, and ornament
  /// (itemSubType 21) items and restricts to the equipment-slot buckets, so the
  /// result is real gear pieces — not cosmetics, dummies, or skins.
  ///
  /// Abilities: ability plugs are not gear (no bucket, itemType 19), so the
  /// query matches `plug.plugCategoryIdentifier` against the ability taxonomy
  /// (`<class|shared>.<element>.<super/ability/aspect/fragment/…>`) and drops
  /// "Empty … Socket" placeholders by name. See [_abilityCategoryClause].
  ///
  /// Each returned map holds the projected columns keyed by their alias (hash,
  /// name, icon, tierType, itemType, itemSubType, itemTypeDisplayName,
  /// classType, damageType, damageTypeHash, ammoType, bucketHash, watermark,
  /// pci, idx); the repository builds `GearSummary`s from them. This is the
  /// full-table scan (measured ~800ms), so callers cache the result per kind
  /// rather than re-running it per facet change.
  ///
  /// Table and JSON paths are fixed constants; every value is a bound
  /// parameter, so there is no SQL-injection surface.
  List<Map<String, Object?>> queryGearSummaries(GearKind kind) {
    if (kind == GearKind.ability) return _queryAbilitySummaries();

    final buckets = EquipmentBucket.forKind(kind);
    final bucketPlaceholders = List.filled(buckets.length, '?').join(',');
    // json_extract reads values stored *inside* the JSON blob, which hold
    // Bungie's original unsigned hashes — unlike the signed `id` primary key.
    // So bucket hashes are bound unsigned here, not sign-converted.
    final params = <Object?>[kind.itemType, for (final b in buckets) b.hash];

    final rows = _db.select(
      "$_summaryColumns"
      "json_extract(json,'\$.itemType') = ? AND "
      "json_extract(json,'\$.redacted') = 0 AND "
      "json_extract(json,'\$.equippable') = 1 AND "
      "json_extract(json,'\$.itemSubType') != 21 AND "
      "json_extract(json,'\$.inventory.bucketTypeHash') IN ($bucketPlaceholders)",
      params,
    );
    return [for (final r in rows) {for (final k in r.keys) k: r[k]}];
  }

  // The subclass-ability plug-category suffixes (the taxonomy's second half).
  // Prefixes are titan/hunter/warlock/shared; a matching `pci` is
  // `<prefix>.<element>.<suffix>`. "supers" is plural, "melee" is singular;
  // stasis uses "totems" (aspects) and "trinkets" (fragments) from the pre-3.0
  // naming. Kept in sync with the ability taxonomy documented in the plan.
  static const _abilitySuffixes = [
    'class_abilities',
    'movement',
    'melee',
    'supers',
    'aspects',
    'totems',
    'grenades',
    'fragments',
    'trinkets',
  ];

  /// Query every subclass ability plug by plug category. Matches any
  /// `plug.plugCategoryIdentifier` ending in one of [_abilitySuffixes]
  /// (`LIKE '%.<suffix>'`), dropping "Empty … Socket" placeholders by name.
  List<Map<String, Object?>> _queryAbilitySummaries() {
    // One `pci LIKE '%.<suffix>'` per suffix, OR'd together, on the full
    // json_extract expression (not the alias — matching the existing WHERE
    // style). The suffixes are fixed constants (not user input), bound as
    // parameters regardless so there is no injection surface.
    const pciExpr = "json_extract(json,'\$.plug.plugCategoryIdentifier')";
    const nameExpr = "json_extract(json,'\$.displayProperties.name')";
    final likeClause =
        _abilitySuffixes.map((_) => "$pciExpr LIKE ?").join(' OR ');
    final params = <Object?>[
      for (final s in _abilitySuffixes) '%.$s',
    ];
    final rows = _db.select(
      "$_summaryColumns"
      "json_extract(json,'\$.itemType') = 19 AND "
      "json_extract(json,'\$.redacted') = 0 AND "
      "$nameExpr IS NOT NULL AND $nameExpr != '' AND "
      "$nameExpr NOT LIKE 'Empty %' AND "
      "$pciExpr IS NOT NULL AND ($likeClause)",
      params,
    );
    return [for (final r in rows) {for (final k in r.keys) k: r[k]}];
  }

  /// Every subclass definition (itemType 16), projecting the fields the
  /// inventory grid needs to show a subclass the character may not own: hash,
  /// name, icon, classType, its element (`talentGrid.hudDamageType`), and the
  /// manifest `index` (for keeping the newest of same-named generations).
  /// Excludes redacted defs. Fixed table/paths, no user input — no injection
  /// surface.
  List<Map<String, Object?>> querySubclasses() {
    final rows = _db.select(
      "SELECT "
      "json_extract(json,'\$.hash') AS hash, "
      "json_extract(json,'\$.displayProperties.name') AS name, "
      "json_extract(json,'\$.displayProperties.icon') AS icon, "
      "json_extract(json,'\$.classType') AS classType, "
      "json_extract(json,'\$.talentGrid.hudDamageType') AS element, "
      "json_extract(json,'\$.index') AS idx "
      "FROM DestinyInventoryItemDefinition WHERE "
      "json_extract(json,'\$.itemType') = 16 AND "
      "json_extract(json,'\$.redacted') = 0",
    );
    return [for (final r in rows) {for (final k in r.keys) k: r[k]}];
  }

  /// Find the catalyst record for a weapon, matched by the convention that its
  /// name is `weaponName Catalyst`. Returns null when no such record exists.
  Map<String, dynamic>? findCatalystRecord(String weaponName) {
    if (weaponName.isEmpty) return null;
    final target = '$weaponName Catalyst';
    final result = _db.select(
      "SELECT json FROM DestinyRecordDefinition WHERE json LIKE ?",
      ['%"name":"${target.replaceAll('"', '')}"%'],
    );
    for (final row in result) {
      final def = jsonDecode(row['json'] as String) as Map<String, dynamic>;
      if ((def['displayProperties']?['name'] as String?) == target) {
        return def;
      }
    }
    return null;
  }

  @override
  Map<String, dynamic>? getSandboxPerk(int hash) =>
      getDefinition('DestinySandboxPerkDefinition', hash);

  @override
  Map<String, dynamic>? getSocketType(int hash) =>
      getDefinition('DestinySocketTypeDefinition', hash);

  void close() => _db.close();

  /// Manifest hashes are unsigned 32-bit but stored signed. Map values above
  /// the signed max into the negative range used as the table's primary key.
  static int signedHash(int unsignedHash) {
    final masked = unsignedHash & 0xFFFFFFFF;
    return masked > 0x7FFFFFFF ? masked - 0x100000000 : masked;
  }
}
