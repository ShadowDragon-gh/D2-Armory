import '../../core/config/app_config.dart';
import '../../core/destiny/plug_category.dart';
import 'destiny_item.dart';

/// How a stat renders in the detail panel.
enum StatDisplay { bar, numeric, recoil }

/// A resolved stat line for the detail panel. [display] controls rendering:
/// a 0-100 bar, a bare number (e.g. RPM, Magazine, Zoom), or the recoil
/// direction gauge. [bonus] is what equipped masterwork/catalyst/mod plugs
/// add, drawn as a gold segment within the bar; [reduction] is what equipped
/// plugs of any kind (including barrel/magazine perks) subtract, drawn as a
/// red deficit segment after the bar. Positive perk contributions fold into
/// the base bar, matching the in-game display.
class ItemStat {
  const ItemStat({
    required this.name,
    required this.value,
    this.statHash = 0,
    this.display = StatDisplay.bar,
    this.bonus = 0,
    this.reduction = 0,
  });

  /// The stat's definition hash, so a selected perk's [PerkStatEffect] can be
  /// aligned to the right row. 0 when unknown (the instance panel does not
  /// need it).
  final int statHash;
  final String name;
  final int value;
  final StatDisplay display;
  final int bonus;
  final int reduction;
}

/// A stat a plug changes when selected: the stat's [hash] (to align it with
/// the weapon's own stat rows), its display [name], and the signed [value] it
/// adds (negative for a penalty).
class PerkStatEffect {
  const PerkStatEffect({
    required this.hash,
    required this.name,
    required this.value,
  });

  final int hash;
  final String name;
  final int value;
}

/// A resolved socket plug (perk / mod / masterwork / cosmetic / frame).
class ItemPlug {
  const ItemPlug({
    required this.name,
    required this.iconPath,
    required this.category,
    this.description = '',
    this.isEnabled = true,
    this.isEnhanced = false,
    this.statEffects = const [],
  });

  final String name;
  final String iconPath;
  final PlugCategory category;
  final String description;
  final bool isEnabled;

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
  });

  final String name;
  final List<CatalystEffect> effects;
  final List<CatalystStatBonus> statBonuses;
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
  const PerkColumn({required this.plugs, this.label = '', this.activeIndex});

  final List<ItemPlug> plugs;
  final String label;

  /// Index in [plugs] of the plug currently active on the owning instance
  /// (the roll's equipped perk in this column); null for definition columns.
  final int? activeIndex;
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
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<PerkColumn> perkColumns;

  /// The intrinsic frame / exotic intrinsic plug, shown as its own row.
  final ItemPlug? frame;
  final BreakerType? breaker;
  final String flavorText;
  final String screenshotPath;

  String? get screenshotUrl => screenshotPath.isEmpty
      ? null
      : '${AppConfig.bungieBaseUrl}$screenshotPath';
}

/// Everything the detail panel shows for a single item: the base [item] plus
/// resolved stats, sockets (grouped by category), champion breaker, and the
/// masterwork kill tracker.
class ItemDetail {
  const ItemDetail({
    required this.item,
    required this.stats,
    required this.plugs,
    this.perkColumns = const [],
    this.breaker,
    this.killTracker,
    this.catalyst,
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<ItemPlug> plugs;

  /// This roll's perk options per weapon-perk socket, with the active plug
  /// flagged ([PerkColumn.activeIndex]). Resolved only on request (see
  /// `InventoryRepository.resolveDetail`); empty otherwise.
  final List<PerkColumn> perkColumns;

  final BreakerType? breaker;
  final KillTracker? killTracker;
  final CatalystProgress? catalyst;

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
