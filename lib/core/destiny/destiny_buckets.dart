import 'package:flutter/material.dart';

/// Well-known Destiny 2 inventory bucket hashes for the equipment slots the
/// inventory grid displays, in DIM row order. These values are stable across
/// game versions, so they are hardcoded rather than discovered from the
/// manifest (a deterministic lookup, not a per-launch resolution).
enum EquipmentBucket {
  kineticWeapons(1498876634, 'Kinetic'),
  energyWeapons(2465295065, 'Energy'),
  powerWeapons(953998645, 'Power'),
  helmet(3448274439, 'Helmet'),
  gauntlets(3551918588, 'Gauntlets'),
  chestArmor(14239492, 'Chest'),
  legArmor(20886954, 'Legs'),
  classArmor(1585787867, 'Class Item');

  const EquipmentBucket(this.hash, this.label);

  final int hash;
  final String label;

  bool get isWeapon => index <= EquipmentBucket.powerWeapons.index;

  static EquipmentBucket? fromHash(int hash) {
    for (final b in EquipmentBucket.values) {
      if (b.hash == hash) return b;
    }
    return null;
  }
}

/// DestinyDamageType enum → display name + colour for weapon element badges.
/// 0/1 = None/Kinetic (no coloured badge).
class DamageType {
  const DamageType._();

  static const int none = 0;
  static const int kinetic = 1;

  static String? name(int damageType) => switch (damageType) {
        2 => 'Arc',
        3 => 'Solar',
        4 => 'Void',
        6 => 'Stasis',
        7 => 'Strand',
        _ => null,
      };

  static Color? color(int damageType) => switch (damageType) {
        1 => const Color(0xFFD6D6D6), // Kinetic (neutral)
        2 => const Color(0xFF7AECF3), // Arc
        3 => const Color(0xFFF2721B), // Solar
        4 => const Color(0xFFB185DF), // Void
        6 => const Color(0xFF4D88FF), // Stasis
        7 => const Color(0xFF00A26B), // Strand
        _ => null,
      };
}
