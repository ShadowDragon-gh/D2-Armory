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
    this.display = StatDisplay.bar,
    this.bonus = 0,
    this.reduction = 0,
  });

  final String name;
  final int value;
  final StatDisplay display;
  final int bonus;
  final int reduction;
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
  });

  final String name;
  final String iconPath;
  final PlugCategory category;
  final String description;
  final bool isEnabled;

  /// True for the enhanced version of a weapon trait, which the panel marks
  /// with a golden glow and an upward arrow.
  final bool isEnhanced;

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

/// Everything the detail panel shows for a single item: the base [item] plus
/// resolved stats, sockets (grouped by category), champion breaker, and the
/// masterwork kill tracker.
class ItemDetail {
  const ItemDetail({
    required this.item,
    required this.stats,
    required this.plugs,
    this.breaker,
    this.killTracker,
    this.catalyst,
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<ItemPlug> plugs;
  final BreakerType? breaker;
  final KillTracker? killTracker;
  final CatalystProgress? catalyst;

  Iterable<ItemPlug> plugsOf(PlugCategory c) =>
      plugs.where((p) => p.category == c);
}
