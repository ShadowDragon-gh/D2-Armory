import '../../core/config/app_config.dart';
import '../../core/destiny/plug_category.dart';
import 'destiny_item.dart';

/// How a stat renders in the detail panel.
enum StatDisplay { bar, numeric, recoil }

/// The canonical in-game weapon-stat order by stat hash. Matches how Destiny
/// lists stats on the weapon inspect screen, so the detail panel reads the same
/// — Blast Radius and Velocity lead (grenade/rocket launchers), Accuracy sits
/// just after Impact, Shield Duration just after Range (glaives), Zoom third
/// from the bottom of the bars, and the sword stats in their own order. Stats
/// not listed here sort to the end of their display group in manifest order.
const List<int> _weaponStatOrder = [
  3614673599, // Blast Radius
  2523465841, // Velocity
  4043523819, // Impact
  1591432999, // Accuracy (scouts / bows)
  1240592695, // Range
  1842278586, // Shield Duration (glaives)
  2837207746, // Swing Speed (swords)
  3022301683, // Charge Rate (swords)
  209426660, // Guard Resistance (swords)
  3736848092, // Guard Endurance (swords)
  925767036, // Ammo Capacity (swords)
  155624089, // Stability
  943549884, // Handling
  4188031367, // Reload Speed
  1345609583, // Aim Assistance
  3555269338, // Zoom
  2714457168, // Airborne Effectiveness
  1931675084, // Ammo Generation
  2715839340, // Recoil Direction
  4284893193, // Rounds Per Minute
  3871231066, // Magazine
  3481294762, // Heat Generated
  4006394725, // Cooling Efficiency
];

/// [stats] reordered for the detail panel: bar stats first, then the recoil
/// gauge, then numeric stats, and within each group by the canonical in-game
/// [_weaponStatOrder] (unlisted stats keep their relative order, after the
/// listed ones). Shared by the definition and instance resolvers so both views
/// match the in-game inspect screen.
List<ItemStat> sortStatsForDisplay(List<ItemStat> stats) {
  int rank(ItemStat s) {
    final i = _weaponStatOrder.indexOf(s.statHash);
    return i == -1 ? _weaponStatOrder.length : i;
  }

  return [
    for (final group in const [
      StatDisplay.bar,
      StatDisplay.recoil,
      StatDisplay.numeric
    ])
      ...(() {
        // Decorate with the input index so equal-rank (unlisted) stats keep
        // their original order — List.sort is not guaranteed stable.
        final group_ = [
          for (var i = 0; i < stats.length; i++)
            if (stats[i].display == group) (i: i, stat: stats[i]),
        ]..sort((a, b) {
            final r = rank(a.stat).compareTo(rank(b.stat));
            return r != 0 ? r : a.i.compareTo(b.i);
          });
        return group_.map((e) => e.stat);
      })(),
  ];
}

/// A resolved stat line for the detail panel. [display] controls rendering:
/// a 0-100 bar, a bare number (e.g. RPM, Magazine, Zoom), or the recoil
/// direction gauge. [modBonus] is what equipped weapon *mods* add (a blue bar
/// segment) and [masterworkBonus] is what the masterwork/catalyst adds (a gold
/// segment) — kept separate so the two contributions read distinctly.
/// [reduction] is what equipped plugs of any kind (including barrel/magazine
/// perks) subtract, drawn as a red deficit segment after the bar. Positive perk
/// contributions fold into the base bar, matching the in-game display.
class ItemStat {
  const ItemStat({
    required this.name,
    required this.value,
    this.statHash = 0,
    this.display = StatDisplay.bar,
    this.modBonus = 0,
    this.masterworkBonus = 0,
    this.reduction = 0,
    this.inverted = false,
    this.tuningBoosted = false,
  });

  /// The stat's definition hash, so a selected perk's [PerkStatEffect] can be
  /// aligned to the right row. 0 when unknown (the instance panel does not
  /// need it).
  final int statHash;
  final String name;
  final int value;
  final StatDisplay display;

  /// The gain from equipped weapon mods (the blue bar segment).
  final int modBonus;

  /// The gain from the masterwork/catalyst (the gold bar segment).
  final int masterworkBonus;
  final int reduction;

  /// Whether this is an inverted "lower is better" stat (e.g. Heat Generated),
  /// so a [reduction] is beneficial rather than a penalty — the UI colours the
  /// net effect by this.
  final bool inverted;

  /// Whether the equipped armor stat-tuning ("+X / -Y") trade-off boosts this
  /// stat — the game shows a small up/down glyph on the boosted stat only. The
  /// tuning's value itself is already folded into [value]/[modBonus].
  final bool tuningBoosted;

  /// The combined mod + masterwork gain (for callers that don't distinguish
  /// the two).
  int get bonus => modBonus + masterworkBonus;

  /// The net applied mod/masterwork effect, signed for display: gains minus the
  /// reduction. Negative when the stat's displayed value dropped.
  int get netEffect => modBonus + masterworkBonus - reduction;

  /// Whether [netEffect] helps the item: a rise for a normal stat, or a drop
  /// for an [inverted] one. False when there is no net effect.
  bool get netBeneficial =>
      netEffect != 0 && (inverted ? netEffect < 0 : netEffect > 0);
}

/// A stat a plug changes when selected: the stat's [hash] (to align it with
/// the weapon's own stat rows), its display [name], and the signed raw
/// investment [value] it adds (the number the game advertises on the mod, e.g.
/// -10 Heat Generated). [applied] is the *actual* change to the displayed stat
/// after the weapon's interpolation (e.g. -2), or null when it equals [value]
/// (a 1:1 stat, where showing both would be redundant). [beneficial] is whether
/// the change helps the item — usually a positive [value], but for an inverted
/// "lower is better" stat (Heat Generated) a negative one is the beneficial one,
/// so the UI colours by this flag rather than the raw sign.
class PerkStatEffect {
  const PerkStatEffect({
    required this.hash,
    required this.name,
    required this.value,
    this.applied,
    this.beneficial = true,
  });

  final int hash;
  final String name;
  final int value;
  final int? applied;
  final bool beneficial;
}

/// A resolved socket plug (perk / mod / masterwork / cosmetic / frame).
class ItemPlug {
  const ItemPlug({
    required this.name,
    required this.iconPath,
    required this.category,
    this.description = '',
    this.note = '',
    this.energyCost = 0,
    this.isTuning = false,
    this.isEnabled = true,
    this.isEnhanced = false,
    this.statEffects = const [],
    this.plugHash = 0,
    this.socketIndex = -1,
    this.platePath,
    this.foregroundPath,
  });

  final String name;
  final String iconPath;
  final PlugCategory category;
  final String description;

  /// A background plate + transparent foreground glyph to composite in place of
  /// the flat [iconPath], both non-null together. Used for subclass class-
  /// ability / movement plugs, whose flat icon bakes in the wrong (Stasis-blue)
  /// plate — the composite draws the glyph over the subclass's correct element
  /// plate. Null for every other plug (draw [iconPath] as-is).
  final String? platePath;
  final String? foregroundPath;

  String? get plateUrl =>
      (platePath == null || platePath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$platePath';

  String? get foregroundUrl =>
      (foregroundPath == null || foregroundPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$foregroundPath';

  /// A secondary informational note the game shows in smaller, dimmer text
  /// below the effect — e.g. an armor mod's "Multiple copies of this mod can be
  /// stacked…" stacking note. Empty when the plug has none.
  final String note;

  /// The armor energy this mod costs to install (its "Any Energy Type Cost" /
  /// "Mod Cost" stat), shown as a small badge on the mod icon. 0 for plugs with
  /// no energy cost (weapon mods, perks, empty sockets).
  final int energyCost;

  /// Whether this is an armor stat-tuning ("+X / -Y") plug. The mods row orders
  /// the tuning chip right after the primary mod rather than by socket index.
  final bool isTuning;

  final bool isEnabled;

  /// The plug's own item hash — the plug to insert when selecting this option
  /// in-game. 0 for plugs resolved without it (definition-only perk columns,
  /// which are not selectable). The `socketIndex` on the owning [PerkColumn]
  /// (perks) or on this plug (mods) pairs with it for an insert.
  final int plugHash;

  /// The instance socket this plug sits in, for a per-plug insert (weapon
  /// mods, whose chips are not grouped in a [PerkColumn]). -1 when unknown or
  /// not applicable. Perk-column plugs use the column's [PerkColumn.socketIndex]
  /// instead.
  final int socketIndex;

  /// True for the enhanced version of a weapon trait, which the panel marks
  /// with a golden glow and an upward arrow.
  final bool isEnhanced;

  /// The stat changes this plug applies when selected (its unconditional
  /// investment stats). Empty for plugs that do not alter stats. Used by the
  /// Database modal to update the stat bars and list a selection's effects.
  final List<PerkStatEffect> statEffects;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';
}

/// The item's champion breaker (Disruption / Stagger / Shield Piercing), or
/// null when it has none.
class BreakerType {
  const BreakerType({required this.name, required this.iconPath});

  final String name;
  final String iconPath;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';
}

/// A single catalyst effect perk (name + description).
class CatalystEffect {
  const CatalystEffect({required this.name, required this.description});

  final String name;
  final String description;
}

/// A stat bonus granted by a catalyst, e.g. "+30 Stability".
class CatalystStatBonus {
  const CatalystStatBonus({required this.name, required this.value});

  final String name;
  final int value;
}

/// A single named catalyst objective (e.g. "Arc Mode Kills 38/150").
class CatalystObjective {
  const CatalystObjective({
    required this.name,
    required this.progress,
    required this.completionValue,
    required this.complete,
  });

  final String name;
  final int progress;
  final int completionValue;
  final bool complete;
}

/// One selectable catalyst plug and what it grants. Classic exotics have a
/// single option; crafting-era exotics (e.g. Slayer's Fang) offer several.
class CatalystOption {
  const CatalystOption({
    required this.name,
    this.effects = const [],
    this.statBonuses = const [],
    this.plugHash = 0,
  });

  final String name;
  final List<CatalystEffect> effects;
  final List<CatalystStatBonus> statBonuses;

  /// The catalyst plug's inventory-item hash — the Clarity community-insight
  /// join key. 0 when unknown.
  final int plugHash;
}

/// An exotic weapon's catalyst: its granted effect [options] (resolved from
/// the weapon definition so they are known even before the catalyst is
/// obtained) and its unlock state — [acquired] (the player owns the catalyst),
/// [complete] (fully unlocked), and the [objectives] tracked while it is
/// acquired but not yet complete.
class CatalystProgress {
  const CatalystProgress({
    required this.name,
    required this.complete,
    required this.acquired,
    this.options = const [],
    this.objectives = const [],
  });

  final String name;
  final bool complete;
  final bool acquired;
  final List<CatalystOption> options;
  final List<CatalystObjective> objectives;
}

/// The weapon's masterwork kill tracker: its icon and current count.
class KillTracker {
  const KillTracker({required this.iconPath, required this.count});

  final String iconPath;
  final int count;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';
}

/// One weapon perk socket rendered as a column of its possible plugs — the
/// destiny.report layout. For a random-roll weapon this is every candidate that
/// can appear in that column, gathered from the definition's plug sets. [label]
/// names the column (e.g. "Barrel", "Magazine", "Trait"), derived from the
/// socket's plug whitelist.
class PerkColumn {
  const PerkColumn({
    required this.plugs,
    this.label = '',
    this.activeIndex,
    this.socketIndex = -1,
  });

  final List<ItemPlug> plugs;
  final String label;

  /// Index in [plugs] of the plug currently active on the owning instance
  /// (the roll's equipped perk in this column); null for definition columns.
  final int? activeIndex;

  /// The instance socket index this column maps to, used to insert a selected
  /// plug in-game. -1 for definition columns (not tied to a live socket).
  final int socketIndex;
}

/// The full, definition-sourced detail for the Database tab's modal: the
/// destiny.report-style view of a single item. Distinct from [ItemDetail]
/// (the instance-based inventory panel) — this one adds the pre-rendered
/// [screenshotUrl], [flavorText], and labeled [perkColumns] showing every
/// possible perk. Resolved from the manifest only.
class GearDetail {
  const GearDetail({
    required this.item,
    required this.stats,
    required this.perkColumns,
    this.frame,
    this.breaker,
    this.flavorText = '',
    this.screenshotPath = '',
    this.ornamentScreenshotPath,
    this.ornamentIconPath,
    this.source,
    this.questOrigin,
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<PerkColumn> perkColumns;

  /// The intrinsic frame / exotic intrinsic plug, shown as its own row.
  final ItemPlug? frame;
  final BreakerType? breaker;
  final String flavorText;
  final String screenshotPath;

  /// How the item is acquired — the collectible's source hint (d2ai override
  /// else the manifest sourceString), or null when it has none.
  final String? source;

  /// The name of the quest this weapon originates from, or null when it is not
  /// quest-sourced.
  final String? questOrigin;

  /// When an owned instance wears an ornament, its screenshot / icon paths —
  /// so the modal shows the ornamented look the instance actually displays.
  /// Null for definition-only detail (Database tab) or an un-ornamented item.
  final String? ornamentScreenshotPath;
  final String? ornamentIconPath;

  /// The screenshot to show: the applied ornament's when present, else the
  /// base definition's.
  String? get screenshotUrl {
    final path = (ornamentScreenshotPath != null &&
            ornamentScreenshotPath!.isNotEmpty)
        ? ornamentScreenshotPath!
        : screenshotPath;
    return path.isEmpty ? null : '${AppConfig.bungieBaseUrl}$path';
  }

  /// The item icon to show: the applied ornament's when present, else the
  /// base item's own icon.
  String? get iconUrl =>
      (ornamentIconPath != null && ornamentIconPath!.isNotEmpty)
          ? '${AppConfig.bungieBaseUrl}$ornamentIconPath'
          : item.iconUrl;

  GearDetail withOrnamentArt({String? screenshot, String? icon}) => GearDetail(
        item: item,
        stats: stats,
        perkColumns: perkColumns,
        frame: frame,
        breaker: breaker,
        flavorText: flavorText,
        screenshotPath: screenshotPath,
        ornamentScreenshotPath: screenshot,
        ornamentIconPath: icon,
        source: source,
        questOrigin: questOrigin,
      );
}

/// An armor piece's energy meter: the total [capacity] and how much its
/// installed mods [used]. Shown above the stats like the in-game armor display.
class ArmorEnergy {
  const ArmorEnergy({required this.capacity, required this.used});

  final int capacity;
  final int used;

  /// Whether swapping the mod currently in a socket (costing [equippedCost])
  /// for one costing [candidateCost] keeps used energy within [capacity].
  /// [used] already includes the equipped mod, so the swap changes it by
  /// (candidate − equipped).
  bool canAffordSwap({required int equippedCost, required int candidateCost}) =>
      used - equippedCost + candidateCost <= capacity;
}

/// Everything the detail panel shows for a single item: the base [item] plus
/// resolved stats, sockets (grouped by category), champion breaker, and the
/// masterwork kill tracker.
/// An armor piece's gear archetype (Powerhouse, Reaver, Bulwark, …): the name
/// and icon of its equipped `armor_archetypes` plug.
class ArmorArchetype {
  const ArmorArchetype({required this.name, required this.iconPath});

  final String name;
  final String iconPath;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';
}

class ItemDetail {
  const ItemDetail({
    required this.item,
    required this.stats,
    required this.plugs,
    this.perkColumns = const [],
    this.modColumns = const [],
    this.breaker,
    this.killTracker,
    this.catalyst,
    this.armorEnergy,
    this.archetype,
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<ItemPlug> plugs;

  /// This roll's perk options per weapon-perk socket, with the active plug
  /// flagged ([PerkColumn.activeIndex]). Resolved only on request (see
  /// `InventoryRepository.resolveDetail`); empty otherwise.
  final List<PerkColumn> perkColumns;

  /// This roll's weapon *mod* sockets, each as a column of the selectable mod
  /// options at that socket with the equipped one flagged
  /// ([PerkColumn.activeIndex]). Lets the modal offer a mod picker per socket.
  /// Resolved with [perkColumns] (on request); empty otherwise.
  final List<PerkColumn> modColumns;

  final BreakerType? breaker;
  final KillTracker? killTracker;
  final CatalystProgress? catalyst;

  /// The armor energy meter (capacity + used), or null for weapons and for
  /// armor with no energy data.
  final ArmorEnergy? armorEnergy;

  /// The armor piece's gear archetype (its equipped `armor_archetypes` plug),
  /// or null for weapons and armor with no archetype socketed.
  final ArmorArchetype? archetype;

  Iterable<ItemPlug> plugsOf(PlugCategory c) =>
      plugs.where((p) => p.category == c);
}

/// A lightweight list row for the Database tab, built cheaply in bulk from a
/// gear definition (no instance data). The Database list shows thousands of
/// these, so it holds only what a row renders; full detail is resolved lazily
/// for the selected item via a definition resolver.
class GearSummary {
  const GearSummary({
    required this.itemHash,
    required this.name,
    required this.iconPath,
    required this.tierType,
    required this.itemType,
    required this.itemSubType,
    required this.itemTypeDisplayName,
    required this.classType,
    required this.damageType,
    required this.ammoType,
    required this.bucketHash,
    required this.index,
    this.elementIconPath,
  });

  final int itemHash;
  final String name;
  final String iconPath;
  final int tierType;
  final int itemType;
  final int itemSubType;
  final String itemTypeDisplayName;

  /// DestinyClass affinity (0=Titan, 1=Hunter, 2=Warlock, 3=any).
  final int classType;

  /// Weapon default damage type (0/1 = none/kinetic for armor and kinetics).
  final int damageType;
  final int ammoType;
  final int bucketHash;

  /// The definition's manifest `index`, used to keep the newest reissue when
  /// deduping by name and to sort by "recently added".
  final int index;
  final String? elementIconPath;

  String? get iconUrl =>
      iconPath.isEmpty ? null : '${AppConfig.bungieBaseUrl}$iconPath';

  String? get elementIconUrl =>
      (elementIconPath == null || elementIconPath!.isEmpty)
          ? null
          : '${AppConfig.bungieBaseUrl}$elementIconPath';

  /// Adapt this summary to a [DestinyItem] so the existing search grammar
  /// ([CompiledQuery]) filters the Database identically to the inventory.
  /// Instance-only facets (power, equipped, masterwork, locked) are absent, so
  /// keyword filters on them simply never match — documented as unsupported for
  /// the Database tab.
  DestinyItem toDestinyItem() => DestinyItem(
        itemHash: itemHash,
        bucketHash: bucketHash,
        name: name,
        iconPath: iconPath,
        itemType: itemType,
        itemSubType: itemSubType,
        tierType: tierType,
        classType: classType,
        ammoType: ammoType,
        itemTypeDisplayName: itemTypeDisplayName,
        damageType: damageType,
        elementIconPath: elementIconPath,
      );
}
