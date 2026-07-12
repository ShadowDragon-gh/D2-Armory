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

/// Whether a plug is a real weapon *trait* or *origin trait* — the perks the
/// `perk:` autocomplete offers (what destiny.report lists), as distinct from the
/// broader `perk:` search pool that also matches barrels, magazines, and the
/// like. Judged from the plug's `plugCategoryIdentifier`:
///   • trait perks (Rampage, Firefly, Zen Moment, …) are `frames`, or an id
///     with a `traits` segment (`frames.traits`, `v300.weapon.traits`, …);
///   • origin traits are `origins`.
/// Everything else is excluded: barrels/magazines/stocks/scopes/…, and — the
/// user-visible ask — exotic `intrinsics`, which are unique per-weapon perks
/// (e.g. "Alone as a God"), not shared trait perks. `intrinsics` also carries
/// the weapon's archetype frame, so excluding it drops "Adaptive Frame" too.
bool isSuggestableTraitPerk(String? plugCategoryIdentifier) {
  final id = (plugCategoryIdentifier ?? '').toLowerCase();
  if (id.isEmpty) return false;
  if (id == 'frames' || id == 'origins') return true;
  // A `traits` path segment: the whole id is `traits`, ends with `.traits`, or
  // contains `.traits.` (enhanced/exotic trait variants).
  return id == 'traits' ||
      id.endsWith('.traits') ||
      id.contains('.traits.');
}

// Weapon perk-socket whitelist category identifiers → column label. Barrel
// and magazine sockets vary by weapon family (blades/scopes/hafts/tubes for
// swords/bows/GLs; batteries/arrows/guards for fusions/bows/swords).
const _barrelWhitelistIds = {'barrels', 'blades', 'scopes', 'hafts', 'tubes'};
const _magazineWhitelistIds = {
  'magazines',
  'magazines_gl',
  'batteries',
  'arrows',
  'guards',
};

/// A human perk-column label ("Barrel", "Magazine", "Trait", "Origin Trait")
/// for a weapon perk socket's plug-whitelist category identifier, or an empty
/// string when the identifier names no known column. Shared by the definition
/// (Database) and instance (Inventory) perk-column resolvers; prefer
/// [perkColumnLabelFromPlugType] when a plug definition is at hand.
String perkColumnLabelFor(String whitelistId) {
  if (_barrelWhitelistIds.contains(whitelistId)) return 'Barrel';
  if (_magazineWhitelistIds.contains(whitelistId)) return 'Magazine';
  if (whitelistId == 'frames') return 'Trait';
  if (whitelistId == 'origins') return 'Origin Trait';
  return '';
}

/// A column label from a plug's own `itemTypeDisplayName` — "Launcher Barrel",
/// "Bowstring", "Arrow", "Origin Trait", … with any "Enhanced " prefix
/// stripped — or empty when the plug names no type. Preferred over
/// [perkColumnLabelFor]: the whitelist identifiers vary per weapon family and
/// do not cover them all, while the plugs themselves always say what they are.
String perkColumnLabelFromPlugType(String? typeName) {
  final t = (typeName ?? '').trim();
  const prefix = 'Enhanced ';
  return t.startsWith(prefix) ? t.substring(prefix.length) : t;
}

/// Whether a plug definition is the *enhanced* version of a perk. The
/// authoritative signal is the game's own enhanced tooltip style — an entry in
/// `tooltipNotifications` with `displayStyle` = `ui_display_style_enhanced_perk`
/// — which flags enhanced origin traits whose `itemTypeDisplayName` still
/// reads a plain "Origin Trait". The "Enhanced " prefix on
/// `itemTypeDisplayName` ("Enhanced Trait", "Enhanced Barrel", …) is a
/// fallback for any plug that carries it without the tooltip.
bool isEnhancedPlugDef(Map<String, dynamic> def) {
  final tips = def['tooltipNotifications'];
  if (tips is List) {
    for (final t in tips) {
      if ((t as Map)['displayStyle'] == 'ui_display_style_enhanced_perk') {
        return true;
      }
    }
  }
  return (def['itemTypeDisplayName'] as String? ?? '').startsWith('Enhanced ');
}
