import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/destiny/destiny_enums.dart';
import '../../../domain/models/armor_set.dart';
import '../../../domain/models/item_detail.dart';
import '../../providers/database_provider.dart';
import '../../theme/armory_palette.dart';
import '../../widgets/search_bar_field.dart';
import 'database_detail_modal.dart';

/// The Database tab: a browsable list of every weapon and every armor piece in
/// the game, sourced entirely from the local manifest (no account). A
/// filter/sort bar drives a virtualised list; selecting a row opens the
/// purpose-built detail modal ([DatabaseDetailModal]) centered over the list.
class DatabaseScreen extends ConsumerStatefulWidget {
  const DatabaseScreen({super.key});

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> {
  bool _modalOpen = false;

  @override
  Widget build(BuildContext context) {
    // Opening the detail modal is a side effect of selecting an item, so it is
    // driven from a listener rather than the build. The modal reads the
    // selection itself and switches items in place (e.g. via "All Versions"),
    // so it is opened once and only re-opened after it fully closes.
    ref.listen(selectedDatabaseItemProvider, (previous, next) {
      if (next != null && !_modalOpen) {
        _modalOpen = true;
        showGearDetailModal(context, ref)
            .whenComplete(() => _modalOpen = false);
      }
    });

    return const Column(
      children: [
        _FilterBar(),
        Divider(height: 1, thickness: 1),
        Expanded(child: _GearList()),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(databaseFilterProvider);
    final notifier = ref.read(databaseFilterProvider.notifier);

    // The Weapons/Armor toggle selects which gear index is browsed; every other
    // facet (rarity, type, element, ammo, …) is expressed through the search
    // bar (is:exotic, is:handcannon, is:arc, ammo:heavy, frame:"…"). The class
    // filter is the one structured armor facet, shown only when browsing armor.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _KindToggle(kind: filter.kind, onChanged: notifier.setKind),
          if (filter.kind == GearKind.armor) ...[
            const SizedBox(width: 12),
            _ClassFilter(
                classType: filter.classType,
                onChanged: notifier.setClassType),
          ],
          const SizedBox(width: 12),
          // The view/filter toggles, grouped together. Rarity is on both tabs;
          // Sets and Modern-sets are armor-only.
          Wrap(
            spacing: 6,
            children: [
              // Sets leads (armor only). The remaining toggles are framed as the
              // non-default action (both hide by default), so each reads as what
              // turning it on does.
              if (filter.kind == GearKind.armor) ...[
                _ChipToggle(
                  icon: Icons.dns,
                  label: 'Sets',
                  tooltipOn: 'Collapsing armor into sets',
                  tooltipOff: 'Showing armor piece by piece',
                  selected: filter.collapseSets,
                  onChanged: notifier.setCollapseSets,
                ),
                _ChipToggle(
                  icon: Icons.star,
                  label: 'Exotics',
                  tooltipOn: 'Showing Exotic gear only',
                  tooltipOff: 'Showing all rarities',
                  selected: filter.exoticsOnly,
                  onChanged: notifier.setExoticsOnly,
                ),
              ],
              _ChipToggle(
                icon: Icons.visibility,
                label: 'Low Rarity',
                tooltipOn: 'Showing all rarities',
                tooltipOff: 'Showing Legendary and Exotic only',
                selected: !filter.hideBelowLegendary,
                onChanged: (show) => notifier.setHideBelowLegendary(!show),
              ),
              if (filter.kind == GearKind.armor)
                _ChipToggle(
                  icon: Icons.history,
                  label: 'Legacy gear',
                  tooltipOn: 'Showing legacy gear (no set bonus)',
                  tooltipOff: 'Hiding legacy gear (no set bonus)',
                  selected: !filter.hideLegacy,
                  onChanged: (show) => notifier.setHideLegacy(!show),
                ),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(child: _DatabaseSearchField()),
        ],
      ),
    );
  }
}

/// The armor class filter: All / Titan / Hunter / Warlock. "All" is the null
/// [classType] (no constraint). Shown only while browsing armor.
class _ClassFilter extends StatelessWidget {
  const _ClassFilter({required this.classType, required this.onChanged});

  /// DestinyClass (0=Titan, 1=Hunter, 2=Warlock), or null for all classes.
  final int? classType;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int?>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: null, label: Text('All')),
        ButtonSegment(value: 0, label: Text('Titan')),
        ButtonSegment(value: 1, label: Text('Hunter')),
        ButtonSegment(value: 2, label: Text('Warlock')),
      ],
      selected: {classType},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// A compact on/off filter-bar chip: a leading [icon] avatar (filled when on,
/// its outlined variant when off — no checkmark) plus a [label], with a tooltip
/// describing the current state. Used for all of the view/filter toggles so
/// they read as one consistent group.
class _ChipToggle extends StatelessWidget {
  const _ChipToggle({
    required this.icon,
    required this.label,
    required this.tooltipOn,
    required this.tooltipOff,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String tooltipOn;
  final String tooltipOff;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? tooltipOn : tooltipOff,
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        selected: selected,
        // Bronze accent when on, so an active (non-default) filter stands out.
        selectedColor: ArmoryPalette.accent500,
        avatar: Icon(icon,
            size: 18,
            color: selected ? ArmoryPalette.onAccent : null),
        label: Text(label,
            style: selected
                ? const TextStyle(color: ArmoryPalette.onAccent)
                : null),
        onSelected: onChanged,
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final GearKind kind;
  final ValueChanged<GearKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GearKind>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: GearKind.weapon, label: Text('Weapons')),
        ButtonSegment(value: GearKind.armor, label: Text('Armor')),
      ],
      selected: {kind},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// The Database tab's search bar: the shared [SearchBarField] bound to the
/// Database query. `instanceData: false` so it does not suggest live-only
/// filters (power/count/catalyst states) it cannot evaluate on definitions.
class _DatabaseSearchField extends ConsumerWidget {
  const _DatabaseSearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SearchBarField(
      // `text` (watched) lets the field reflect an externally-set query — e.g. a
      // detail-modal Frame chip setting `frame:"…"` — while still owning the
      // controller during the user's own typing.
      text: ref.watch(databaseSearchProvider),
      names: ref.watch(databaseItemNamesProvider),
      perks: ref.watch(perkCatalogProvider),
      frames: ref.watch(frameCatalogProvider),
      // The visible kind's facet warm gates its perk:/stat:/source: search and
      // the perk autocomplete, so show the spinner while it is still running.
      warming: ref
          .watch(databaseFacetsWarmProvider(
              ref.watch(databaseFilterProvider.select((f) => f.kind))))
          .isLoading,
      unsupported: ref.watch(databaseUnsupportedTermsProvider),
      instanceData: false,
      height: 38,
      fontSize: 13,
      hintText: 'Search — e.g. is:exotic perk:rampage',
      onChanged: (v) => ref.read(databaseSearchProvider.notifier).set(v),
    );
  }
}

class _GearList extends ConsumerWidget {
  const _GearList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(databaseRowsProvider);
    final selected = ref.watch(selectedDatabaseItemProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Could not load the database.',
            style:
                TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (rows) => _buildList(context, ref, rows, selected),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<DatabaseRow> rows, int? selected) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No gear matches the current filters.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final setCount = rows.where((r) => r.isSet).length;
    final pieceCount = rows.length - setCount;
    // Show only the parts that apply — the set view is all sets (0 pieces), the
    // flat view all pieces (0 sets); a mixed view shows both.
    final label = [
      if (pieceCount > 0 || setCount == 0) '$pieceCount items',
      if (setCount > 0) '$setCount sets',
    ].join(' · ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          // Virtualised: only visible rows build, so thousands of items scroll
          // without jank and without resolving each row's full detail. Set rows
          // are taller (two lines of bonus badges), so extent varies per row.
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row.isSet) {
                // Sets usually have no icon of their own; fall back to a member.
                final iconUrl = row.members
                    .map((m) => m.iconUrl)
                    .firstWhere((u) => u != null, orElse: () => null);
                return _SetRow(
                  set: row.set!,
                  memberCount: row.members.length,
                  iconUrl: iconUrl,
                  onTap: () => ref
                      .read(selectedArmorSetProvider.notifier)
                      .toggle(row.set!.hash),
                );
              }
              final gear = row.piece!;
              return SizedBox(
                height: 56,
                child: _GearRow(
                  gear: gear,
                  selected: gear.itemHash == selected,
                  onTap: () => ref
                      .read(selectedDatabaseItemProvider.notifier)
                      .toggle(gear.itemHash),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GearRow extends ConsumerWidget {
  const _GearRow({
    required this.gear,
    required this.selected,
    required this.onTap,
  });

  final GearSummary gear;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rarity = DestinyEnums.rarityColor(gear.tierType);
    final elementColor = DamageType.color(gear.damageType);
    // Resolved lazily per visible row (the list is virtualised) and cached.
    final breaker = ref.read(databaseRepositoryProvider).rowBreaker(gear.itemHash);

    final subtitle = [
      if (gear.itemTypeDisplayName.isNotEmpty) gear.itemTypeDisplayName,
      if (DestinyEnums.rarityName(gear.tierType) != null)
        DestinyEnums.rarityName(gear.tierType)!,
    ].join(' · ');

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Rarity accent bar.
              Container(width: 3, height: 40, color: rarity),
              const SizedBox(width: 10),
              // Icon.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: ArmoryRadius.sm,
                  border: Border.all(color: ArmoryPalette.borderStronger),
                ),
                clipBehavior: Clip.antiAlias,
                child: gear.iconUrl == null
                    ? const ColoredBox(color: ArmoryPalette.scrim26)
                    : CachedNetworkImage(
                        imageUrl: gear.iconUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: ArmoryPalette.scrim26),
                      ),
              ),
              const SizedBox(width: 12),
              // Name + subtitle — sized to content (up to the available width)
              // so the element/breaker icons sit right beside it, not pinned to
              // the far edge.
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gear.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Element glyph (all weapons, kinetic included) then the champion
              // breaker glyph, immediately after the name/subtitle content.
              if (elementColor != null && gear.elementIconUrl != null) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CachedNetworkImage(
                    imageUrl: gear.elementIconUrl!,
                    color: elementColor,
                    colorBlendMode: BlendMode.srcIn,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (breaker?.iconUrl != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CachedNetworkImage(
                    imageUrl: breaker!.iconUrl!,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              // Fill the rest so the icons hug the content, not the row edge.
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsed armor-set row: the set name, its piece count, and small
/// 2-piece / 4-piece bonus-name badges. Tapping it opens the set detail modal.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.memberCount,
    required this.iconUrl,
    required this.onTap,
  });

  final ArmorSet set;
  final int memberCount;
  final String? iconUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Set accent bar (bronze, distinct from a piece's rarity bar).
              Container(width: 3, height: 44, color: ArmoryPalette.accent500),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: ArmoryRadius.sm,
                  border: Border.all(color: ArmoryPalette.borderStronger),
                ),
                clipBehavior: Clip.antiAlias,
                child: iconUrl == null
                    ? const Icon(Icons.dns, size: 22)
                    : CachedNetworkImage(
                        imageUrl: iconUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, _, _) => const Icon(Icons.dns, size: 22),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            set.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$memberCount pieces',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (set.perks.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          for (final perk in set.perks)
                            _SetPerkBadge(perk: perk),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small "Npc: Name" badge for a set bonus on a collapsed set row.
class _SetPerkBadge extends StatelessWidget {
  const _SetPerkBadge({required this.perk});

  final SetPerk perk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ArmoryPalette.scrim26,
        borderRadius: ArmoryRadius.sm,
        border: Border.all(color: ArmoryPalette.borderStrong),
      ),
      child: Text(
        '${perk.requiredSetCount}pc: ${perk.name}',
        style: TextStyle(
            fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
