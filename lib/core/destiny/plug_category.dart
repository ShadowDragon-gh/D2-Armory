/// How a socket plug is grouped in the item detail panel, derived from the
/// plug definition's `plug.plugCategoryIdentifier` (a stable string key).
enum PlugCategory { frame, perk, mod, masterwork, cosmetic, other }

/// Classify a plug by its category identifier. Heuristic but covers the common
/// cases; anything unrecognised falls back to [PlugCategory.perk] for weapon
/// trait-like plugs or [PlugCategory.other].
PlugCategory classifyPlug(String? plugCategoryIdentifier) {
  final id = (plugCategoryIdentifier ?? '').toLowerCase();
  if (id.isEmpty) return PlugCategory.other;
  if (id == 'intrinsics' || id.contains('intrinsic')) {
    return PlugCategory.frame;
  }
  if (id.contains('masterwork') ||
      id.contains('tracker') ||
      // Crafting-era selectable catalysts ("Rapid Hit Refit"...) belong with
      // the masterwork/catalyst display, not the weapon's traits.
      id == 'catalysts') {
    return PlugCategory.masterwork;
  }
  if (id.contains('skins') ||
      id.contains('shader') ||
      id.contains('ornament') ||
      id.contains('cosmetic') ||
      id.contains('vfx') ||
      id.contains('memento')) {
    // Weapon cosmetics include shaders, ornaments, mementos, and kill-effect
    // flair like "weapon_tiering_kill_vfx".
    return PlugCategory.cosmetic;
  }
  if (id.contains('.mods.') ||
      id.endsWith('.mods') ||
      id.contains('armor_mods') ||
      id.contains('weapon_mods') ||
      id.contains('weapon.mod') || // e.g. v400.weapon.mod_magazine
      id.contains('.mod_') ||
      id.contains('enhancements')) {
    return PlugCategory.mod;
  }
  // Weapon perks live under things like "barrels", "magazines", "frames",
  // "stocks", "grips", "traits", "origins"… treat the remainder as perks.
  return PlugCategory.perk;
}
