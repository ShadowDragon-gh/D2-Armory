import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Read-only access to a downloaded Destiny manifest SQLite file.
///
/// Every definition table has the same shape: an `id` column (the definition
/// hash, stored as a *signed* 32-bit int) and a `json` text column. API
/// responses use *unsigned* hashes, so lookups convert to the signed form.
class ManifestDatabase {
  ManifestDatabase._(this._db);

  final Database _db;

  /// Open the manifest at [path]. The file must already exist.
  factory ManifestDatabase.open(String path) =>
      ManifestDatabase._(sqlite3.open(path, mode: OpenMode.readOnly));

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
  Map<String, dynamic>? getInventoryItem(int hash) =>
      getDefinition('DestinyInventoryItemDefinition', hash);

  Map<String, dynamic>? getDamageType(int hash) =>
      getDefinition('DestinyDamageTypeDefinition', hash);

  Map<String, dynamic>? getStat(int hash) =>
      getDefinition('DestinyStatDefinition', hash);

  Map<String, dynamic>? getBreakerType(int hash) =>
      getDefinition('DestinyBreakerTypeDefinition', hash);

  Map<String, dynamic>? getObjective(int hash) =>
      getDefinition('DestinyObjectiveDefinition', hash);

  Map<String, dynamic>? getPlugSet(int hash) =>
      getDefinition('DestinyPlugSetDefinition', hash);

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

  Map<String, dynamic>? getSandboxPerk(int hash) =>
      getDefinition('DestinySandboxPerkDefinition', hash);

  void close() => _db.close();

  /// Manifest hashes are unsigned 32-bit but stored signed. Map values above
  /// the signed max into the negative range used as the table's primary key.
  static int signedHash(int unsignedHash) {
    final masked = unsignedHash & 0xFFFFFFFF;
    return masked > 0x7FFFFFFF ? masked - 0x100000000 : masked;
  }
}
