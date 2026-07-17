import '../../core/config/app_config.dart';

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
