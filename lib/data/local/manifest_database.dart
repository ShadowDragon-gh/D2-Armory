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

  @override
  Map<String, dynamic>? getPlugSet(int hash) =>
      getDefinition('DestinyPlugSetDefinition', hash);

  /// The layered icon definition (`foreground`/`background`/watermark paths)
  /// referenced by an item's `displayProperties.iconHash`.
  Map<String, dynamic>? getIcon(int hash) =>
      getDefinition('DestinyIconDefinition', hash);

  /// Enumerate all real gear of [kind] (weapons or armor), projecting only the
  /// fields a list row needs via `json_extract` — no full-JSON decode per row
  /// (measured ~400ms cheaper than decoding every blob). Excludes redacted,
  /// non-equippable, and ornament (itemSubType 21) items, and restricts to the
  /// equipment-slot buckets, so the result is real gear pieces — not cosmetics,
  /// dummies, or skins.
  ///
  /// Each returned map holds the projected columns keyed by their alias (hash,
  /// name, icon, tierType, itemType, itemSubType, itemTypeDisplayName,
  /// classType, damageType, damageTypeHash, ammoType, bucketHash, watermark,
  /// idx); the repository builds `GearSummary`s from them. This is the
  /// full-table scan
  /// (measured ~800ms), so callers cache the result per kind rather than
  /// re-running it per facet change.
  ///
  /// Table and JSON paths are fixed constants; every value is a bound
  /// parameter, so there is no SQL-injection surface.
  List<Map<String, Object?>> queryGearSummaries(GearKind kind) {
    final buckets = EquipmentBucket.forKind(kind);
    final bucketPlaceholders = List.filled(buckets.length, '?').join(',');
    // json_extract reads values stored *inside* the JSON blob, which hold
    // Bungie's original unsigned hashes — unlike the signed `id` primary key.
    // So bucket hashes are bound unsigned here, not sign-converted.
    final params = <Object?>[kind.itemType, for (final b in buckets) b.hash];

    final rows = _db.select(
      "SELECT "
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
      "json_extract(json,'\$.index') AS idx "
      "FROM DestinyInventoryItemDefinition WHERE "
      "json_extract(json,'\$.itemType') = ? AND "
      "json_extract(json,'\$.redacted') = 0 AND "
      "json_extract(json,'\$.equippable') = 1 AND "
      "json_extract(json,'\$.itemSubType') != 21 AND "
      "json_extract(json,'\$.inventory.bucketTypeHash') IN ($bucketPlaceholders)",
      params,
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
