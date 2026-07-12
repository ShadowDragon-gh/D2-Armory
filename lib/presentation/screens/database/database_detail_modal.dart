import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/destiny/destiny_enums.dart';
import '../../../core/destiny/plug_category.dart';
import '../../../domain/models/item_detail.dart';
import '../../providers/database_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/search_provider.dart';
import '../../theme/armory_palette.dart';

/// The Database tab's purpose-built detail view: a centered modal, rendered
/// over the dimmed list, that shows the full "all-options" nature of a
/// definition — the pre-rendered screenshot, header chips, stat block, the
/// destiny.report-style perk columns (every possible roll, hover for details),
/// and the item's reissue versions.
///
/// Opened via [showGearDetailModal]; it reads the selected item from
/// [databaseItemDetailProvider] and closes when the selection clears.
class DatabaseDetailModal extends ConsumerWidget {
  const DatabaseDetailModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(databaseItemDetailProvider);
    // The selection was cleared (Esc / tap-out / close) — dismiss the route.
    if (detail == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1900, maxHeight: 820),
        child: _ModalBody(detail: detail),
      ),
    );
  }
}

/// Show the gear detail modal. Closing it (button, Esc, or tap-outside)
/// clears the selection so the list is interactive again. No-ops when the
/// modal is already up ([gearModalOpenProvider]) — the Database and Inventory
/// screens both react to the shared selection, so the first open wins.
Future<void> showGearDetailModal(BuildContext context, WidgetRef ref) {
  if (ref.read(gearModalOpenProvider)) return Future<void>.value();
  ref.read(gearModalOpenProvider.notifier).set(true);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const DatabaseDetailModal(),
  ).whenComplete(() {
    ref.read(gearModalOpenProvider.notifier).set(false);
    ref.read(selectedDatabaseItemProvider.notifier).clear();
    ref.read(gearModalInstanceProvider.notifier).clear();
  });
}

class _ModalBody extends ConsumerWidget {
  const _ModalBody({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolled = _rolledFor(ref, detail);
    final showRoll = rolled != null &&
        ref.watch(gearModalViewProvider) == GearModalView.rolled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(detail: detail),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: screenshot render + stats + versions.
                SizedBox(
                  width: 380,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Screenshot(detail: detail),
                      const SizedBox(height: 16),
                      if (detail.frame != null) ...[
                        _Intrinsic(frame: detail.frame!),
                        const SizedBox(height: 16),
                      ],
                      _StatArea(detail: detail),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Middle: the roll's actual plugs, or the clickable
                // all-possible-rolls perk grid (with the catalyst's effect
                // whenever an owned exotic backs the modal).
                Expanded(
                  child: showRoll
                      ? _RolledPlugArea(instance: rolled)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PerkArea(detail: detail),
                            if (rolled?.catalyst != null) ...[
                              const SizedBox(height: 16),
                              _CatalystInfo(catalyst: rolled!.catalyst!),
                            ],
                          ],
                        ),
                ),
                const SizedBox(width: 24),
                // Right: effects — the roll's perks, or the grid selection.
                SizedBox(
                  width: 260,
                  child: showRoll
                      ? _RolledEffects(
                          perks: rolled.plugsOf(PlugCategory.perk).toList())
                      : const _SelectedEffects(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An `is:<keyword>` search term for a facet keyword, or null when the keyword
/// is null (the facet has no matching search keyword, so the chip is inert).
String? _isTerm(String? keyword) => keyword == null ? null : 'is:$keyword';

/// The owned instance backing the modal, but only while the open definition is
/// that item (the modal can switch to another version of the item in place).
ItemDetail? _rolledFor(WidgetRef ref, GearDetail detail) {
  final instance = ref.watch(gearModalInstanceDetailProvider);
  return instance != null && instance.item.itemHash == detail.item.itemHash
      ? instance
      : null;
}

class _Header extends ConsumerWidget {
  const _Header({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = detail.item;
    final damageName =
        item.damageType == null ? null : DamageType.name(item.damageType!);
    final damageColor =
        item.damageType == null ? null : DamageType.color(item.damageType!);

    final kind = item.itemType == GearKind.armor.itemType
        ? GearKind.armor
        : GearKind.weapon;

    // Every chip filters the list through the search bar of the tab that opened
    // the modal, then closes it. Opened from the Inventory tab (an owned
    // instance backs the modal) the term goes to the inventory search; opened
    // from the Database tab it sets the Weapons/Armor kind to match this item
    // and goes to the Database search.
    final fromInventory = ref.watch(gearModalInstanceProvider) != null;
    void applyTermAndClose(String? term) {
      if (term == null) return; // chip not filterable
      if (fromInventory) {
        ref.read(searchQueryProvider.notifier).set(term);
      } else {
        ref.read(databaseFilterProvider.notifier).setKind(kind);
        ref.read(databaseSearchProvider.notifier).set(term);
      }
      Navigator.of(context).maybePop();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      color: ArmoryPalette.scrim26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item icon.
          if (item.iconUrl != null)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: ArmoryRadius.md,
                border: Border.all(
                    color: DestinyEnums.rarityColor(item.tierType), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: item.iconUrl!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: ArmoryPalette.scrim26),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontFamily: ArmoryFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
                if (detail.flavorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail.flavorText,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Every chip filters via a search term. A null term (no
                    // matching keyword) leaves the chip non-clickable.
                    // Element → is:<element>.
                    if (damageName != null)
                      _Chip(
                        icon: item.elementIconUrl,
                        iconColor: damageColor,
                        label: damageName,
                        labelColor: damageColor,
                        onTap: () => applyTermAndClose(_isTerm(
                            DestinyEnums.damageKeyword(item.damageType ?? 0))),
                      ),
                    // Breaker → breaker:<champion> (e.g. breaker:overload).
                    if (detail.breaker != null)
                      _Chip(
                        icon: detail.breaker!.iconUrl,
                        label: detail.breaker!.name,
                        onTap: () => applyTermAndClose(
                            'breaker:${detail.breaker!.name.toLowerCase()}'),
                      ),
                    // Weapon type / armor slot → is:<type|slot>.
                    if (item.itemTypeDisplayName.isNotEmpty)
                      _Chip(
                        label: item.itemTypeDisplayName,
                        onTap: () => applyTermAndClose(_isTerm(
                            kind == GearKind.weapon
                                ? DestinyEnums.weaponTypeKeyword(
                                    item.itemSubType)
                                : DestinyEnums.armorSlotKeyword(
                                    item.itemSubType))),
                      ),
                    // Ammo → ammo:<primary|special|heavy>.
                    if (DestinyEnums.ammoName(item.ammoType) != null)
                      _Chip(
                        label: DestinyEnums.ammoName(item.ammoType)!,
                        onTap: () {
                          final k = DestinyEnums.ammoKeyword(item.ammoType);
                          applyTermAndClose(k == null ? null : 'ammo:$k');
                        },
                      ),
                    // Frame → frame:"<name>".
                    if (detail.frame != null)
                      _Chip(
                        label: detail.frame!.name,
                        onTap: () => applyTermAndClose(
                            'frame:"${detail.frame!.name.toLowerCase()}"'),
                      ),
                    // Rarity → is:<rarity>.
                    if (DestinyEnums.rarityName(item.tierType) != null)
                      _Chip(
                        label: DestinyEnums.rarityName(item.tierType)!,
                        labelColor: DestinyEnums.rarityLabelColor(item.tierType),
                        onTap: () => applyTermAndClose(
                            _isTerm(DestinyEnums.rarityKeyword(item.tierType))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_rolledFor(ref, detail) != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ViewToggle(view: ref.watch(gearModalViewProvider)),
            ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// A small pill for the header facets (element, breaker, type, rarity…). When
/// [onTap] is set the chip is clickable — used to jump the list to that facet.
class _Chip extends StatelessWidget {
  const _Chip({
    this.icon,
    this.iconColor,
    required this.label,
    this.labelColor,
    this.onTap,
  });

  final String? icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CachedNetworkImage(
                imageUrl: icon!,
                color: iconColor,
                colorBlendMode: iconColor != null ? BlendMode.srcIn : null,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor ?? theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: MouseRegion(
                  cursor: SystemMouseCursors.click, child: content),
            ),
    );
  }
}

/// The pre-rendered 1920×1080 screenshot from the manifest — the app's "3D
/// item display" for the modal (a static render; the shaded interactive 3D
/// viewer is a separate, larger feature per doc/gear_preview_implementation.md).
class _Screenshot extends StatelessWidget {
  const _Screenshot({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context) {
    final url = detail.screenshotUrl;
    return ClipRRect(
      borderRadius: ArmoryRadius.md,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url == null
            ? const ColoredBox(color: ArmoryPalette.scrim26)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: ArmoryPalette.scrim26),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: ArmoryPalette.scrim26,
                  child: Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: ArmoryPalette.textMuted)),
                ),
              ),
      ),
    );
  }
}

/// The modal's stat area. In the roll view it shows the instance's actual
/// stats; in the definition view (or when no owned item backs the modal) it
/// shows the definition's base values with the interactive perk preview.
class _StatArea extends ConsumerWidget {
  const _StatArea({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolled = _rolledFor(ref, detail);
    if (detail.stats.isEmpty && (rolled == null || rolled.stats.isEmpty)) {
      return const SizedBox.shrink();
    }
    final showRoll = rolled != null &&
        ref.watch(gearModalViewProvider) == GearModalView.rolled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Stats'),
        const SizedBox(height: 6),
        if (showRoll)
          _RolledStats(stats: rolled.stats)
        else
          _StatBlock(stats: detail.stats),
      ],
    );
  }
}

/// The This Roll | Definition toggle in the modal header, shown when an owned
/// item backs the modal. Switches the stats, perk area, and effects column
/// between the instance's actual roll and the item definition.
class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.view});

  final GearModalView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<GearModalView>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(value: GearModalView.rolled, label: Text('This Roll')),
        ButtonSegment(
            value: GearModalView.definition, label: Text('Definition')),
      ],
      selected: {view},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(gearModalViewProvider.notifier).set(s.first),
    );
  }
}

/// The roll view's middle column: the roll's own perk options per socket with
/// the active perks highlighted, its mods, the masterwork state with catalyst
/// objective progress (the detail panel's Masterwork section), and the
/// catalyst's granted effect.
class _RolledPlugArea extends StatelessWidget {
  const _RolledPlugArea({required this.instance});

  final ItemDetail instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perks = instance.plugsOf(PlugCategory.perk).toList();
    final mods = instance.plugsOf(PlugCategory.mod).toList();
    final masterwork = instance.plugsOf(PlugCategory.masterwork).toList();
    final catalyst = instance.catalyst;
    // Objectives show while the catalyst is acquired but not yet complete.
    final objectives =
        catalyst != null && catalyst.acquired && !catalyst.complete
            ? catalyst.objectives
            : const <CatalystObjective>[];

    Widget chips(List<ItemPlug> plugs, {bool rolled = false}) => Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            for (final plug in plugs)
              Opacity(
                opacity: plug.isEnabled ? 1 : 0.4,
                child: _PerkChip(plug: plug, selected: rolled),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (instance.perkColumns.isNotEmpty || perks.isNotEmpty) ...[
          const _SectionLabel('Perks'),
          if (instance.perkColumns.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Highlighted perks are active on this roll.',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            _RolledPerkGrid(columns: instance.perkColumns),
          ] else ...[
            const SizedBox(height: 8),
            chips(perks, rolled: true),
          ],
          const SizedBox(height: 16),
        ],
        if (mods.isNotEmpty) ...[
          const _SectionLabel('Mods'),
          const SizedBox(height: 8),
          chips(mods),
          const SizedBox(height: 16),
        ],
        if (masterwork.isNotEmpty || objectives.isNotEmpty) ...[
          const _SectionLabel('Masterwork'),
          const SizedBox(height: 8),
          if (masterwork.isNotEmpty) chips(masterwork),
          for (final o in objectives) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 360,
              child: Row(
                children: [
                  Expanded(
                    child: Text(o.name, style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                    '${o.progress} / ${o.completionValue}',
                    style: TextStyle(
                        fontSize: 11,
                        color: o.complete
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 360,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: o.completionValue > 0
                      ? (o.progress / o.completionValue).clamp(0.0, 1.0)
                      : (o.complete ? 1.0 : 0.0),
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        if (catalyst != null) _CatalystInfo(catalyst: catalyst),
      ],
    );
  }
}

/// The roll view's perk grid: this instance's own per-socket options
/// ([ItemDetail.perkColumns]) laid out like the definition grid, with each
/// column's active perk ([PerkColumn.activeIndex]) highlighted. Read-only —
/// perk preview belongs to the definition view.
class _RolledPerkGrid extends StatelessWidget {
  const _RolledPerkGrid({required this.columns});

  final List<PerkColumn> columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in columns)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _chipWidth,
                    child: Text(
                      column.label.isEmpty ? '—' : column.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < column.plugs.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Opacity(
                        opacity: column.plugs[i].isEnabled ? 1 : 0.4,
                        child: _PerkChip(
                          plug: column.plugs[i],
                          selected: i == column.activeIndex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The catalyst's granted effect (perks + stat bonuses), resolved from the
/// weapon definition so it shows regardless of unlock state — the detail
/// panel's Catalyst section, shared by the roll and definition views.
class _CatalystInfo extends StatelessWidget {
  const _CatalystInfo({required this.catalyst});

  final CatalystProgress catalyst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Catalyst'),
        const SizedBox(height: 8),
        Text(catalyst.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        for (final option in catalyst.options) ...[
          const SizedBox(height: 6),
          // With several selectable options (crafting-era catalysts) the
          // option name is the heading; a lone option leads with its effect.
          if (catalyst.options.length > 1)
            Text(option.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          for (final effect in option.effects) ...[
            if (catalyst.options.length == 1)
              Text(effect.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            if (effect.description.isNotEmpty)
              Text(
                effect.description,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
          for (final bonus in option.statBonuses) ...[
            const SizedBox(height: 4),
            Text(
              '+${bonus.value} ${bonus.name}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary),
            ),
          ],
        ],
      ],
    );
  }
}

/// The roll view's right column: the rolled perks' stat changes and gameplay
/// effects (what the Selected Perks list shows in the definition view).
class _RolledEffects extends StatelessWidget {
  const _RolledEffects({required this.perks});

  final List<ItemPlug> perks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Perk Effects'),
        const SizedBox(height: 8),
        if (perks.isEmpty)
          Text('No perks on this roll.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          _EffectsColumn(plugs: perks),
      ],
    );
  }
}

/// The owned instance's stat rows: the actual roll, with any masterwork/mod
/// bonus as the gold bar segment and any penalty as the red deficit. Static —
/// the perk-preview deltas apply to the definition view only.
class _RolledStats extends StatelessWidget {
  const _RolledStats({required this.stats});

  final List<ItemStat> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(stat.name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${stat.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: stat.display == StatDisplay.bar
                      ? _StatBar(
                          value: stat.value,
                          bonus: stat.bonus,
                          reduction: stat.reduction)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The definition's stat rows. Each bar shows the base value plus the net
/// change from the selected perks — a gold segment for a gain, a red deficit
/// for a penalty — and the displayed number reflects the modified total. The
/// deltas come from [databaseSelectedStatDeltasProvider].
class _StatBlock extends ConsumerWidget {
  const _StatBlock({required this.stats});

  final List<ItemStat> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deltas = ref.watch(databaseSelectedStatDeltasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats)
          Builder(builder: (context) {
            final delta = deltas[stat.statHash] ?? 0;
            final total = stat.value + delta;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(stat.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text('$total',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: delta == 0
                                ? theme.colorScheme.onSurface
                                : (delta > 0
                                    ? ArmoryPalette.masterworkGold
                                    : ArmoryPalette.statPenaltyRed))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: stat.display == StatDisplay.bar
                        ? _StatBar(
                            value: stat.value + delta,
                            bonus: delta > 0 ? delta : 0,
                            reduction: delta < 0 ? -delta : 0,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// A 0-100 stat bar: the plain portion in steel, a gold segment for the part
/// granted by bonuses or perk gains, and a red deficit segment after the
/// current value for a penalty — shared by the rolled and definition views.
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.value,
    required this.bonus,
    required this.reduction,
  });

  final int value;
  final int bonus;
  final int reduction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = value.clamp(0, 100);
    final gain = bonus.clamp(0, total);
    final loss = reduction.clamp(0, 100 - total);
    final solid = total - gain; // plain portion
    final rest = 100 - total - loss;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (solid > 0)
              Expanded(
                  flex: solid,
                  // Steel, not bronze, so the gold gain segment reads apart.
                  child: ColoredBox(color: theme.colorScheme.secondary)),
            if (gain > 0)
              Expanded(
                  flex: gain,
                  child:
                      const ColoredBox(color: ArmoryPalette.masterworkGold)),
            if (loss > 0)
              Expanded(
                  flex: loss,
                  child:
                      const ColoredBox(color: ArmoryPalette.statPenaltyRed)),
            if (rest > 0)
              Expanded(
                  flex: rest,
                  child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest)),
          ],
        ),
      ),
    );
  }
}

/// The intrinsic frame (with the selected-perk effects list beside it) plus the
/// clickable perk-column grid. A toggle by the "Perks" title switches the grid
/// between showing enhanced-only and regular-only perks (shown only when the
/// weapon actually has enhanced perks to switch to).
class _PerkArea extends ConsumerWidget {
  const _PerkArea({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(databasePerkViewProvider);
    final hasEnhanced = detail.perkColumns
        .any((c) => c.plugs.any((p) => p.isEnhanced));
    final hasRegular = detail.perkColumns
        .any((c) => c.plugs.any((p) => !p.isEnhanced));
    final canToggle = hasEnhanced && hasRegular;

    // Filter each column to the chosen enhancement state, keeping each plug's
    // *original* index so selection stays keyed to the full column.
    List<_IndexedPlug> visible(PerkColumn column) => [
          for (var i = 0; i < column.plugs.length; i++)
            if (!canToggle ||
                column.plugs[i].isEnhanced == (view == PerkView.enhanced))
              _IndexedPlug(index: i, plug: column.plugs[i]),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.perkColumns.isNotEmpty) ...[
          // Wrap so the toggle drops below the title on a narrow modal instead
          // of overflowing the row.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const _SectionLabel('Perks'),
              if (canToggle) _PerkViewToggle(view: view),
            ],
          ),
          const SizedBox(height: 4),
          Text('Click perks to preview their effect on the weapon.',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          _PerkGrid(
            columns: [
              for (final column in detail.perkColumns)
                (label: column.label, plugs: visible(column)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A perk paired with its index in the full (unfiltered) column, so selection
/// stays consistent whichever enhancement view is shown.
class _IndexedPlug {
  const _IndexedPlug({required this.index, required this.plug});
  final int index;
  final ItemPlug plug;
}

/// The Enhanced | Regular toggle beside the Perks title.
class _PerkViewToggle extends ConsumerWidget {
  const _PerkViewToggle({required this.view});

  final PerkView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<PerkView>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(value: PerkView.regular, label: Text('Regular')),
        ButtonSegment(value: PerkView.enhanced, label: Text('Enhanced')),
      ],
      selected: {view},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(databasePerkViewProvider.notifier).set(s.first),
    );
  }
}

class _Intrinsic extends StatelessWidget {
  const _Intrinsic({required this.frame});

  final ItemPlug frame;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Intrinsic'),
        const SizedBox(height: 8),
        // Icon on the left, name + description stacked to its right.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PerkIcon(plug: frame, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(frame.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (frame.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(frame.description,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The running list of the currently-selected perks, shown in its own column on
/// the right of the modal. Each perk lists its stat changes (gold for a gain,
/// red for a penalty) and its gameplay effect description — so descriptive perks
/// with no stat numbers (e.g. an origin trait like "Gun and Run") still show
/// what they do. Empty-state prompts the user to pick perks.
class _SelectedEffects extends ConsumerWidget {
  const _SelectedEffects();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = ref.watch(databaseItemDetailProvider);
    final selection = ref.watch(databasePerkSelectionProvider);
    if (detail == null) return const SizedBox.shrink();

    // Gather the selected plugs (in column order) and their effects.
    final selectedPlugs = <ItemPlug>[];
    for (var c = 0; c < detail.perkColumns.length; c++) {
      final idx = selection[c];
      if (idx == null) continue;
      final plugs = detail.perkColumns[c].plugs;
      if (idx >= 0 && idx < plugs.length) selectedPlugs.add(plugs[idx]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Selected Perks'),
        const SizedBox(height: 8),
        if (selectedPlugs.isEmpty)
          Text(
            'No perks selected. Click perks in the grid to see their effect on '
            'the weapon.',
            style: TextStyle(
                fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          )
        else
          _EffectsColumn(plugs: selectedPlugs),
      ],
    );
  }
}

/// One vertical column of selected-perk effect blocks (icon + name, stat
/// changes, and gameplay description).
class _EffectsColumn extends StatelessWidget {
  const _EffectsColumn({required this.plugs});

  final List<ItemPlug> plugs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final plug in plugs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PerkIcon(plug: plug, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(plug.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                // Stat changes (gold gains / red penalties).
                for (final e in plug.statEffects)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 1),
                    child: Text(
                      '${e.value > 0 ? '+' : ''}${e.value} ${e.name}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: e.value > 0
                              ? ArmoryPalette.masterworkGold
                              : ArmoryPalette.statPenaltyRed),
                    ),
                  ),
                // Gameplay effect description — the non-stat effect, so
                // descriptive-only perks still show what they do.
                if (plug.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 3),
                    child: Text(
                      plug.description,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                // Only when a perk has neither stats nor a description.
                if (plug.statEffects.isEmpty && plug.description.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, top: 1),
                    child: Text('No listed effect',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A perk column filtered for display: its label plus the (index-tagged) plugs
/// to show. The index is the plug's position in the *full* column, so selection
/// stays consistent across the enhanced/regular view.
typedef _VisibleColumn = ({String label, List<_IndexedPlug> plugs});

/// The destiny.report-style perk grid: each socket is a column, laid out
/// left-to-right, holding a vertical stack of the visible plugs in that column.
class _PerkGrid extends StatelessWidget {
  const _PerkGrid({required this.columns});

  final List<_VisibleColumn> columns;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _PerkColumnView(columnIndex: i, column: columns[i]),
            ),
        ],
      ),
    );
  }
}

/// Perk-chip layout widths. [_perkTextWidth] is sized so the longest single
/// perk word fits on one line — measured against every perk in the manifest,
/// the widest is "Photoinhibition" at ~165px (fontSize 11). So text wraps only
/// on whole-word boundaries, never mid-word.
const double _perkIconSize = 30;
const double _perkTextWidth = 168; // ≥ widest single perk word at fontSize 11
// The chip's inner content width (icon + gap + text). Its clickable container
// adds padding + a 1px border on each side, so the outer width is a bit wider.
const double _chipContentWidth = _perkIconSize + 8 + _perkTextWidth;
const double _chipHPad = 4;
const double _chipWidth = _chipContentWidth + 2 * _chipHPad + 2;

class _PerkColumnView extends ConsumerWidget {
  const _PerkColumnView({required this.columnIndex, required this.column});

  final int columnIndex;
  final _VisibleColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex =
        ref.watch(databasePerkSelectionProvider)[columnIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _chipWidth,
          child: Text(
            column.label.isEmpty ? '—' : column.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in column.plugs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _PerkChip(
              plug: entry.plug,
              // Selection is keyed to the plug's index in the full column, so
              // it survives switching the enhanced/regular view.
              selected: selectedIndex == entry.index,
              onTap: () => ref
                  .read(databasePerkSelectionProvider.notifier)
                  .toggle(columnIndex, entry.index),
            ),
          ),
      ],
    );
  }
}

/// A single perk in a column: its circular icon and name, wrapped in a rich
/// hover tooltip. With an [onTap] it is clickable to select; without one it is
/// a plain display chip (the roll view's fixed perks). When [selected] it gets
/// a highlight ring and tinted background. The tooltip carries the manifest
/// description now; a Clarity community-research block can be added later
/// (see [_PerkTooltip]).
class _PerkChip extends StatelessWidget {
  const _PerkChip({
    required this.plug,
    required this.selected,
    this.onTap,
  });

  final ItemPlug plug;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PerkTooltip(
      plug: plug,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: _chipWidth,
            padding:
                const EdgeInsets.symmetric(horizontal: _chipHPad, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: ArmoryRadius.md,
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PerkIcon(plug: plug, size: _perkIconSize, selected: selected),
                const SizedBox(width: 8),
                SizedBox(
                  width: _perkTextWidth,
                  child: Text(
                    plug.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Wrap on word boundaries; the width fits the longest single
                    // word so a word is never split across lines.
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.15,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular perk/plug icon, with the golden glow for enhanced traits and a
/// primary-colour ring when [selected].
class _PerkIcon extends StatelessWidget {
  const _PerkIcon({required this.plug, this.size = 30, this.selected = false});

  final ItemPlug plug;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = plug.iconUrl == null
        ? const ColoredBox(color: ArmoryPalette.scrim26)
        : CachedNetworkImage(
            imageUrl: plug.iconUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) =>
                const ColoredBox(color: ArmoryPalette.scrim26),
          );
    // A selected non-enhanced perk gets a primary ring; enhanced keeps its gold
    // ring/glow (a selected enhanced perk is highlighted by the chip's border).
    final borderColor = selected && !plug.isEnhanced
        ? theme.colorScheme.primary
        : plug.isEnhanced
            ? ArmoryPalette.masterworkGold
            : ArmoryPalette.borderStronger;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ArmoryPalette.scrim26,
        border: Border.all(
          color: borderColor,
          width: plug.isEnhanced || selected ? 1.5 : 1,
        ),
        boxShadow: plug.isEnhanced
            ? [
                BoxShadow(
                    color:
                        ArmoryPalette.masterworkGold.withValues(alpha: 0.4),
                    blurRadius: 4)
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

/// Rich hover tooltip for a perk. Shows the name and manifest description.
///
/// Clarity seam: [ItemPlug] carries only manifest data today. When the Clarity
/// community-research pipeline (doc/clarity_community_insights_plan.md) lands,
/// pass its text in here and render it under a "Community Research" divider —
/// the layout below already leaves the spot.
class _PerkTooltip extends StatelessWidget {
  const _PerkTooltip({required this.plug, required this.child});

  final ItemPlug plug;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // Let scroll/pointer events pass through the tooltip overlay to the modal
      // beneath, so hovering a perk does not block scrolling the perk grid.
      ignorePointer: true,
      decoration: BoxDecoration(
        color: ArmoryPalette.tooltipSurface,
        borderRadius: ArmoryRadius.md,
        border: Border.all(color: ArmoryPalette.borderStrong),
      ),
      padding: const EdgeInsets.all(12),
      richMessage: WidgetSpan(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plug.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: ArmoryPalette.textPrimary)),
              if (plug.isEnhanced)
                const Text('Enhanced',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ArmoryPalette.masterworkGold)),
              if (plug.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(plug.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: ArmoryPalette.textPrimary
                            .withValues(alpha: 0.82))),
              ],
              // Clarity community-research block goes here once wired.
            ],
          ),
        ),
      ),
      preferBelow: false,
      margin: const EdgeInsets.all(8),
      child: MouseRegion(cursor: SystemMouseCursors.help, child: child),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}
