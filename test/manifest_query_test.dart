import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:destiny2_loadout_planner/core/destiny/destiny_buckets.dart';
import 'package:destiny2_loadout_planner/data/local/manifest_database.dart';

/// Build an in-memory manifest with the real (id INTEGER, json TEXT) schema and
/// seed it with the given definitions, keyed by their unsigned hash.
ManifestDatabase _fixture(Map<int, Map<String, dynamic>> defs) {
  final db = sqlite3.openInMemory();
  db.execute(
      'CREATE TABLE DestinyInventoryItemDefinition (id INTEGER PRIMARY KEY, json TEXT)');
  final stmt = db.prepare(
      'INSERT INTO DestinyInventoryItemDefinition (id, json) VALUES (?, ?)');
  defs.forEach((hash, def) {
    stmt.execute([ManifestDatabase.signedHash(hash), jsonEncode(def)]);
  });
  stmt.close();
  return ManifestDatabase.forTest(db);
}

/// A weapon/armor definition builder with sane defaults for the fields the
/// gear query projects/inspects.
Map<String, dynamic> _def({
  required int hash,
  required String name,
  int itemType = 3,
  int itemSubType = 9,
  int tierType = 5,
  int classType = 3,
  int bucketHash = 1498876634, // kinetic
  int redacted = 0,
  int equippable = 1,
  int defaultDamageType = 1,
}) =>
    {
      'hash': hash,
      'displayProperties': {'name': name, 'icon': '/icon/$name.jpg'},
      'itemType': itemType,
      'itemSubType': itemSubType,
      'classType': classType,
      'redacted': redacted,
      'equippable': equippable,
      'defaultDamageType': defaultDamageType,
      'inventory': {'bucketTypeHash': bucketHash, 'tierType': tierType},
    };

List<String> _names(List<Map<String, Object?>> rows) => [
      for (final r in rows) r['name'] as String,
    ];

void main() {
  group('queryGearSummaries', () {
    late ManifestDatabase db;

    setUp(() {
      db = _fixture({
        // Real legendary hand cannon (kinetic weapon slot).
        1: _def(hash: 1, name: 'RealHC'),
        // Real exotic auto rifle (energy slot).
        2: _def(
            hash: 2,
            name: 'ExoticAR',
            itemSubType: 6,
            tierType: 6,
            bucketHash: 2465295065,
            defaultDamageType: 3),
        // Redacted weapon — excluded.
        3: _def(hash: 3, name: 'Redacted', redacted: 1),
        // Non-equippable weapon — excluded.
        4: _def(hash: 4, name: 'NotEquip', equippable: 0),
        // Weapon in a non-equipment bucket (general) — excluded.
        5: _def(hash: 5, name: 'WrongBucket', bucketHash: 138197802),
        // Ornament (armor-typed, subType 21) in a helmet bucket — excluded.
        6: _def(
            hash: 6,
            name: 'HelmOrnament',
            itemType: 2,
            itemSubType: 21,
            bucketHash: 3448274439),
        // Real Titan exotic helmet.
        7: _def(
            hash: 7,
            name: 'TitanHelm',
            itemType: 2,
            itemSubType: 26,
            tierType: 6,
            classType: 0,
            bucketHash: 3448274439),
        // Real Warlock legendary chest.
        8: _def(
            hash: 8,
            name: 'WarlockChest',
            itemType: 2,
            itemSubType: 27,
            classType: 2,
            bucketHash: 14239492),
      });
    });

    tearDown(() => db.close());

    test('weapons: only real equippable weapons in weapon buckets', () {
      final rows = db.queryGearSummaries(GearKind.weapon);
      expect(_names(rows)..sort(), ['ExoticAR', 'RealHC']);
    });

    test('armor: excludes ornaments (subType 21), keeps real armor', () {
      final rows = db.queryGearSummaries(GearKind.armor);
      expect(_names(rows)..sort(), ['TitanHelm', 'WarlockChest']);
    });

    test('projects the fields a list row needs', () {
      final rows = db.queryGearSummaries(GearKind.weapon);
      final ar = rows.firstWhere((r) => r['name'] == 'ExoticAR');
      // json_extract returns Bungie's original unsigned values.
      expect(ar['hash'], 2);
      expect(ar['tierType'], 6);
      expect(ar['itemSubType'], 6);
      expect(ar['damageType'], 3);
      expect(ar['bucketHash'], 2465295065);
    });
  });
}
