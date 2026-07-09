/// Destiny enum values and keyword mappings used by the search filters.
/// All values are stable game constants (deterministic lookup tables).
class DestinyEnums {
  const DestinyEnums._();

  // DestinyItemType
  static const int typeArmor = 2;
  static const int typeWeapon = 3;

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
}
