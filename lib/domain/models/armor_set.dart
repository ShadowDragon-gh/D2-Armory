import '../../core/config/app_config.dart';

/// An item's set-search facets: the set [name] (lowercased) and its effect
/// names by required piece count (lowercased) — what `set:`/`set2:`/`set4:`
/// match against.
typedef SetSearchFacets = ({String name, Map<int, Set<String>> perks});

/// Build the reverse item hash → [SetSearchFacets] index from every set
/// definition ([setDefs]), resolving each set-perk's effect name via
/// [sandboxPerkName] (a `sandboxPerkHash → name` lookup). Shared by the Database
/// and Inventory facet builders so both resolve `set:`/`set2:`/`set4:`
/// identically. Names are lowercased for case-insensitive matching.
Map<int, SetSearchFacets> buildSetSearchIndex(
  List<Map<String, dynamic>> setDefs,
  String? Function(int perkHash) sandboxPerkName,
) {
  final byItem = <int, SetSearchFacets>{};
  for (final def in setDefs) {
    if (def['redacted'] == true) continue;
    final name =
        (def['displayProperties']?['name'] as String?)?.toLowerCase() ?? '';
    final perks = <int, Set<String>>{};
    for (final p in (def['setPerks'] as List? ?? const [])) {
      final count = ((p as Map)['requiredSetCount'] as num?)?.toInt();
      final perkHash = (p['sandboxPerkHash'] as num?)?.toInt();
      if (count == null || perkHash == null) continue;
      final pName = sandboxPerkName(perkHash)?.toLowerCase();
      if (pName == null || pName.isEmpty) continue;
      (perks[count] ??= {}).add(pName);
    }
    final facets = (name: name, perks: perks);
    for (final m in (def['setItems'] as List? ?? const [])) {
      final h = (m as num?)?.toInt();
      if (h != null) byItem[h] = facets;
    }
  }
  return byItem;
}

/// One set-bonus perk: the [requiredSetCount] of set pieces that unlocks it
/// (typically 2 or 4) and its resolved [name] / [description] / icon.
class SetPerk {
  const SetPerk({
    required this.requiredSetCount,
    required this.name,
    this.description = '',
    this.iconPath = '',
  });

  final int requiredSetCount;
  final String name;
  final String description;
  final String iconPath;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';
}

/// An armor set (`DestinyEquipableItemSetDefinition`): its [name], the item
/// hashes of its [memberHashes], and its [perks] (the 2-piece / 4-piece
/// bonuses, ascending by required count).
class ArmorSet {
  const ArmorSet({
    required this.hash,
    required this.name,
    required this.memberHashes,
    required this.perks,
    this.isLegacy = false,
  });

  final int hash;
  final String name;
  final List<int> memberHashes;
  final List<SetPerk> perks;

  /// True for a set grouped only by shared name (older armor with no
  /// `DestinyEquipableItemSetDefinition`): it collapses in the list but has no
  /// defined set bonuses ([perks] is empty).
  final bool isLegacy;
}
