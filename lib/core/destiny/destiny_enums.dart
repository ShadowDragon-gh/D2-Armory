import 'package:flutter/material.dart';

/// Destiny enum values and keyword mappings used by the search filters.
/// All values are stable game constants (deterministic lookup tables).
class DestinyEnums {
  const DestinyEnums._();

  // DestinyItemType
  static const int typeArmor = 2;
  static const int typeWeapon = 3;
  static const int typeSubclass = 16;

  // TierType (rarity). Superior == Legendary in DIM terms.
  static const Map<String, int> tierByKeyword = {
    'common': 3,
    'white': 3,
    'rare': 4,
    'blue': 4,
    'legendary': 5,
    'purple': 5,
    'exotic': 6,
    'yellow': 6,
  };
  // 'uncommon'/'green' == 2 (Basic) in Destiny's scheme.
  static const Map<String, int> tierBasicByKeyword = {
    'uncommon': 2,
    'green': 2,
  };

  /// DestinyItemSubType by DIM weapon-type keyword.
  static const Map<String, int> weaponSubTypeByKeyword = {
    'autorifle': 6,
    'shotgun': 7,
    'machinegun': 8,
    'lmg': 8,
    'handcannon': 9,
    'rocketlauncher': 10,
    'fusionrifle': 11,
    'sniperrifle': 12,
    'pulserifle': 13,
    'scoutrifle': 14,
    'sidearm': 17,
    'sword': 18,
    'linearfusionrifle': 22,
    'linear': 22,
    'grenadelauncher': 23,
    'submachine': 24,
    'smg': 24,
    'tracerifle': 25,
    'bow': 31,
    'glaive': 33,
  };

  /// DestinyDamageType by keyword (for is:solar etc.).
  static const Map<String, int> damageTypeByKeyword = {
    'kinetic': 1,
    'arc': 2,
    'solar': 3,
    'void': 4,
    'stasis': 6,
    'strand': 7,
  };

  static const Set<int> lightDamageTypes = {2, 3, 4}; // arc, solar, void
  static const Set<int> darkDamageTypes = {6, 7}; // stasis, strand

  // DestinyClass affinity.
  static const Map<String, int> classByKeyword = {
    'titan': 0,
    'hunter': 1,
    'warlock': 2,
  };

  /// DestinyAmmunitionType → label. 0=None, 1=Primary, 2=Special, 3=Heavy.
  static String? ammoName(int ammoType) => switch (ammoType) {
        1 => 'Primary',
        2 => 'Special',
        3 => 'Heavy',
        _ => null,
      };

  /// TierType → rarity label.
  static String? rarityName(int tierType) => switch (tierType) {
        2 => 'Basic',
        3 => 'Common',
        4 => 'Rare',
        5 => 'Legendary',
        6 => 'Exotic',
        _ => null,
      };

  /// TierType → the in-game rarity accent colour. Saturated, for fills/accents
  /// like the list-row bar and the modal icon border.
  static Color rarityColor(int tierType) => switch (tierType) {
        2 => const Color(0xFFC3BCB4), // Basic
        3 => const Color(0xFFC3BCB4), // Common
        4 => const Color(0xFF5076A3), // Rare (blue)
        5 => const Color(0xFF522F65), // Legendary (purple)
        6 => const Color(0xFFCEAE33), // Exotic (gold)
        _ => const Color(0xFF5A5A5A),
      };

  /// TierType → a rarity colour tuned for readable *text* on a dark chip. Same
  /// hues as [rarityColor] but lightened where the accent is too dark to read —
  /// notably Legendary, whose deep purple is illegible as text (this lighter
  /// purple matches the Void element tone).
  static Color rarityLabelColor(int tierType) => switch (tierType) {
        4 => const Color(0xFF7AA0D0), // Rare (lighter blue)
        5 => const Color(0xFFB185DF), // Legendary (lighter purple)
        6 => const Color(0xFFE5C15B), // Exotic (gold)
        _ => const Color(0xFFC3BCB4), // Basic/Common (neutral)
      };

  /// The `is:` search keyword for a weapon [itemSubType] (e.g. 9 → `handcannon`),
  /// or null when the subtype has no keyword. Inverse of
  /// [weaponSubTypeByKeyword]; the shorter keyword wins for aliased values
  /// (e.g. `smg` over `submachine`).
  static String? weaponTypeKeyword(int itemSubType) {
    String? best;
    for (final e in weaponSubTypeByKeyword.entries) {
      if (e.value != itemSubType) continue;
      if (best == null || e.key.length < best.length) best = e.key;
    }
    return best;
  }

  /// The `is:` slot keyword for an armor [itemSubType] (Helmet 26 → `helmet`,
  /// etc.), or null when it is not an armor slot. Matches the `is:` bucket
  /// keywords the search grammar supports.
  static String? armorSlotKeyword(int itemSubType) => switch (itemSubType) {
        26 => 'helmet',
        27 => 'gauntlets',
        28 => 'chest',
        29 => 'legs',
        30 => 'classitem',
        _ => null,
      };

  /// The `is:` element keyword for a [damageType] (2 → `arc`, …), or null for
  /// none/kinetic (kinetic is a valid keyword; included). Inverse of
  /// [damageTypeByKeyword].
  static String? damageKeyword(int damageType) {
    for (final e in damageTypeByKeyword.entries) {
      if (e.value == damageType) return e.key;
    }
    return null;
  }

  /// The `is:` rarity keyword for a [tierType] (6 → `exotic`, …), or null.
  static String? rarityKeyword(int tierType) => switch (tierType) {
        3 => 'common',
        4 => 'rare',
        5 => 'legendary',
        6 => 'exotic',
        _ => null,
      };

  /// The `ammo:` value keyword for an [ammoType] (3 → `heavy`), or null.
  static String? ammoKeyword(int ammoType) => switch (ammoType) {
        1 => 'primary',
        2 => 'special',
        3 => 'heavy',
        _ => null,
      };
}
