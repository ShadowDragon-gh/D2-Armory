import '../../core/config/app_config.dart';

/// A resolved inventory item ready to render: the raw item component merged
/// with its instance data (power, element) and manifest definition (name,
/// icon). Uninstanced items (materials, some mods) have no [itemInstanceId]
/// and no power/element.
class DestinyItem {
  const DestinyItem({
    required this.itemHash,
    required this.bucketHash,
    required this.name,
    required this.iconPath,
    this.ornamentIconPath,
    this.ornamentForegroundPath,
    this.rarityPlatePath,
    this.itemType = 0,
    this.itemSubType = 0,
    this.tierType = 0,
    this.classType,
    this.ammoType = 0,
    this.itemTypeDisplayName = '',
    this.itemInstanceId,
    this.power,
    this.damageType,
    this.elementIconPath,
    this.isEquipped = false,
    this.isMasterwork = false,
    this.isLocked = false,
  });

  final int itemHash;
  final int bucketHash;
  final String name;
  final String iconPath;

  /// Icon of the applied (non-default) ornament, shown in place of [iconPath]
  /// when cosmetics display is enabled. Null when no ornament is socketed.
  final String? ornamentIconPath;

  /// The applied ornament's transparent foreground art (its icon definition's
  /// `foreground`), composited over [rarityPlatePath] so an ornamented exotic
  /// keeps the exotic background instead of the ornament's legendary one. Both
  /// this and [rarityPlatePath] are set together, only when that composite is
  /// warranted; null otherwise (fall back to [ornamentIconPath]).
  final String? ornamentForegroundPath;

  /// The base item's rarity plate (its icon definition's `background`) — the
  /// gold plate for exotics — drawn beneath [ornamentForegroundPath].
  final String? rarityPlatePath;

  /// DestinyItemType: 2=Armor, 3=Weapon (and others).
  final int itemType;

  /// DestinyItemSubType: weapon type (6=AutoRifle…) or armor slot (26=Helmet…).
  final int itemSubType;

  /// TierType: 4=Rare, 5=Legendary(Superior), 6=Exotic, 3=Common, 2=Basic.
  final int tierType;

  /// DestinyClass: 0=Titan, 1=Hunter, 2=Warlock, 3=any/none. Null when the
  /// definition does not specify class affinity.
  final int? classType;

  /// DestinyAmmunitionType: 1=Primary, 2=Special, 3=Heavy, 0=None.
  final int ammoType;

  /// Human-readable subtitle, e.g. "Hand Cannon", "Leg Armor".
  final String itemTypeDisplayName;

  final String? itemInstanceId;
  final int? power;
  final int? damageType;

  /// Bungie-relative path to the element glyph (from the damage-type
  /// definition), null for non-elemental items.
  final String? elementIconPath;

  final bool isEquipped;
  final bool isMasterwork;
  final bool isLocked;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';

  String? get ornamentIconUrl =>
      (ornamentIconPath == null || ornamentIconPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$ornamentIconPath';

  String? get ornamentForegroundUrl =>
      (ornamentForegroundPath == null || ornamentForegroundPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$ornamentForegroundPath';

  String? get rarityPlateUrl =>
      (rarityPlatePath == null || rarityPlatePath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$rarityPlatePath';

  String? get elementIconUrl =>
      (elementIconPath == null || elementIconPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$elementIconPath';

  /// A copy of this item marked not-equipped. A transferred item always lands
  /// unequipped in its new owner, so the in-memory grid patch after a move uses
  /// this rather than refetching. Returns the same instance when already
  /// unequipped.
  DestinyItem asUnequipped() {
    if (!isEquipped) return this;
    return DestinyItem(
      itemHash: itemHash,
      bucketHash: bucketHash,
      name: name,
      iconPath: iconPath,
      ornamentIconPath: ornamentIconPath,
      ornamentForegroundPath: ornamentForegroundPath,
      rarityPlatePath: rarityPlatePath,
      itemType: itemType,
      itemSubType: itemSubType,
      tierType: tierType,
      classType: classType,
      ammoType: ammoType,
      itemTypeDisplayName: itemTypeDisplayName,
      itemInstanceId: itemInstanceId,
      power: power,
      damageType: damageType,
      elementIconPath: elementIconPath,
      isEquipped: false,
      isMasterwork: isMasterwork,
      isLocked: isLocked,
    );
  }
}
