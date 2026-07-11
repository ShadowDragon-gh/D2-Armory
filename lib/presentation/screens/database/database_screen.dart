import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/destiny/destiny_enums.dart';
import '../../../domain/models/item_detail.dart';
import '../../providers/database_provider.dart';
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
    // bar (is:exotic, is:handcannon, is:arc, ammo:heavy, frame:"…").
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _KindToggle(kind: filter.kind, onChanged: notifier.setKind),
          const SizedBox(width: 12),
          const Expanded(child: _DatabaseSearchField()),
        ],
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
    final async = ref.watch(databaseResultsProvider);
    final selected = ref.watch(selectedDatabaseItemProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Could not load the database.',
            style:
                TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (results) => _buildList(context, ref, results, selected),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<GearSummary> results, int? selected) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No gear matches the current filters.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${results.length} items',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          // Virtualised: only visible rows build, so thousands of items scroll
          // without jank and without resolving each row's full detail.
          child: ListView.builder(
            itemCount: results.length,
            itemExtent: 56,
            itemBuilder: (context, i) {
              final gear = results[i];
              return _GearRow(
                gear: gear,
                selected: gear.itemHash == selected,
                onTap: () => ref
                    .read(selectedDatabaseItemProvider.notifier)
                    .toggle(gear.itemHash),
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
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: gear.iconUrl == null
                    ? const ColoredBox(color: Colors.black26)
                    : CachedNetworkImage(
                        imageUrl: gear.iconUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: Colors.black26),
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
