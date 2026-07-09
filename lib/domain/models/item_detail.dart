import '../../core/config/app_config.dart';
import '../../core/destiny/plug_category.dart';
import 'destiny_item.dart';

/// How a stat renders in the detail panel.
enum StatDisplay { bar, numeric, recoil }

/// A resolved stat line for the detail panel. [display] controls rendering:
/// a 0-100 bar, a bare number (e.g. RPM, Magazine, Zoom), or the recoil
/// direction gauge.
class ItemStat {
  const ItemStat({
    required this.name,
    required this.value,
    this.display = StatDisplay.bar,
  });

  final String name;
  final int value;
  final StatDisplay display;
}

/// A resolved socket plug (perk / mod / masterwork / cosmetic / frame).
class ItemPlug {
  const ItemPlug({
    required this.name,
    required this.iconPath,
    required this.category,
    this.description = '',
    this.isEnabled = true,
  });

  final String name;
  final String iconPath;
  final PlugCategory category;
  final String description;
  final bool isEnabled;

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
  });

  final DestinyItem item;
  final List<ItemStat> stats;
  final List<ItemPlug> plugs;
  final BreakerType? breaker;
  final KillTracker? killTracker;

  Iterable<ItemPlug> plugsOf(PlugCategory c) =>
      plugs.where((p) => p.category == c);
}
