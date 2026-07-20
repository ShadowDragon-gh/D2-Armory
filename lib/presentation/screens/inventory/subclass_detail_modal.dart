import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/network/item_icon_cache.dart';
import '../../../domain/models/destiny_item.dart';
import '../../../domain/models/exotic_ability_interaction.dart';
import '../../../domain/models/item_detail.dart';
import '../../../domain/models/subclass_detail.dart';
import '../../providers/clarity_provider.dart';
import '../../providers/exotic_ability_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/armory_palette.dart';
import '../../widgets/clarity_insight_view.dart';
import '../../widgets/diamond_shape.dart';

/// The subclass detail modal: the subclass name and element banner, then one
/// section per socket group (Abilities, Super, Aspects, Fragments). Each socket
/// is a chip that opens a grid of its selectable options; picking a non-equipped
/// option selects it in-game via [MoveController.insertPlug]. Backed by
/// [subclassDetailProvider] (set when a subclass tile is tapped) and closes when
/// the selection clears. Distinct from the weapon/armor gear modal — a subclass
/// needs a socket-group layout, not stat bars and perk columns.
class SubclassDetailModal extends ConsumerWidget {
  const SubclassDetailModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(subclassDetailProvider);
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
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
        child: _SubclassBody(detail: detail),
      ),
    );
  }
}

/// Show the subclass detail modal. Closing it clears the selected subclass.
/// No-ops when it is already up (its own open-guard), so re-selecting the same
/// subclass — or the post-insert reconcile re-selecting the instance — never
/// stacks a second dialog.
Future<void> showSubclassDetailModal(BuildContext context, WidgetRef ref) {
  if (ref.read(subclassModalOpenProvider)) return Future<void>.value();
  ref.read(subclassModalOpenProvider.notifier).set(true);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const SubclassDetailModal(),
  ).whenComplete(() {
    ref.read(subclassModalOpenProvider.notifier).set(false);
    ref.read(selectedSubclassProvider.notifier).clear();
  });
}

class _SubclassBody extends StatefulWidget {
  const _SubclassBody({required this.detail});

  final SubclassDetail detail;

  @override
  State<_SubclassBody> createState() => _SubclassBodyState();
}

class _SubclassBodyState extends State<_SubclassBody> {
  @override
  void initState() {
    super.initState();
    // Warm the disk cache for every selectable option icon across all sockets,
    // so a selector's icon grid displays instantly the first time it is opened
    // (options only mount — and would otherwise begin downloading — when the
    // MenuAnchor opens). Fire-and-forget through the same cache the icons read
    // from; a failed prefetch just falls back to the normal on-open download.
    final urls = <String>{
      for (final group in widget.detail.groups)
        for (final socket in group.sockets)
          for (final option in socket.options) ?option.iconUrl,
    };
    for (final url in urls) {
      ItemIconCache.instance.getSingleFile(url).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final theme = Theme.of(context);
    final accent =
        DamageType.color(detail.element) ?? theme.colorScheme.primary;
    final screenshot = detail.screenshotUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: element-tinted banner over the subclass screenshot. Tall
        // enough to reveal a good vertical slice of the 16:9 screenshot while
        // still filling the width edge-to-edge (BoxFit.cover); the crop is
        // biased upward (see the image alignment) so the character's focal
        // content shows rather than being cut off.
        SizedBox(
          height: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (screenshot != null)
                CachedNetworkImage(
                  imageUrl: screenshot,
                  fit: BoxFit.cover,
                  // Bias the crop upward so the character's upper body / face —
                  // the screenshot's focal content — shows, rather than a
                  // vertically-centred slice that cuts it off.
                  alignment: const Alignment(0, -0.4),
                  fadeInDuration: Duration.zero,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      accent.withValues(alpha: 0.55),
                      ArmoryPalette.scrim26,
                    ],
                  ),
                ),
              ),
              // Title pinned to the bottom-left over the darker lower portion of
              // the banner (like the in-game subclass screen), so the taller
              // image reads above it. A not-owned subclass shows a lock pill
              // above the name so it reads as unavailable.
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!detail.owned) ...[
                        const _NotUnlockedPill(),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        detail.item.name,
                        style: const TextStyle(
                          fontFamily: ArmoryFonts.display,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: ArmoryPalette.textPrimary,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: ArmoryPalette.scrim87, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button stays at the top-right, the conventional spot.
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              // Equip button, bottom-right — only for an owned subclass that is
              // not already the equipped one (subclasses equip by button /
              // right-click, not by dragging).
              if (detail.owned && !detail.item.isEquipped)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
                    child: _EquipButton(item: detail.item),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          // The ability socket groups on the left; a column listing exotics with
          // general (any-melee / any-Arc-grenade) ability interactions on the
          // right. Name-scoped exotics are badged on their specific ability
          // instead, so they do not repeat in the right column.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in detail.groups) ...[
                        _SocketGroupSection(
                            item: detail.item,
                            group: group,
                            element: detail.element),
                        const SizedBox(height: 20),
                        // The net fragment stat totals sit directly under the
                        // Fragments section they summarise.
                        if (group.isFragments &&
                            detail.fragmentStatSummary.isNotEmpty) ...[
                          _FragmentStatSummary(
                              effects: detail.fragmentStatSummary),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              _GeneralExoticsPanel(detail: detail),
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in an ability-kind column: the [exotic], plus [affects] — the
/// specific ability it buffs (e.g. "Chaos Reach") for a name-scoped entry, or
/// null for a general (any-ability-of-this-kind) entry.
typedef _ColumnEntry = ({ExoticAbilityInteraction exotic, String? affects});

/// The right-hand column of the subclass modal: exotic armor grouped by ability
/// kind. Each kind lists both its *general* exotics (buff any ability of the
/// kind — e.g. any melee, or any Arc grenade for an element-gated one) and its
/// *name-scoped* exotics whose specific ability the socket can hold (e.g. Geomag
/// Stabilizers under Super with a "Chaos Reach" subtitle). Broad-synergy exotics
/// (general across 2+ kinds) list once in a separate top section. Renders nothing
/// until the map loads or when this subclass has no listed interactions.
class _GeneralExoticsPanel extends ConsumerWidget {
  const _GeneralExoticsPanel({required this.detail});

  final SubclassDetail detail;

  static const double _width = 360;

  // The order kinds are listed in the panel, matching the in-game ability order.
  static const _kindOrder = [
    (AbilityKind.grenade, 'Grenade'),
    (AbilityKind.melee, 'Melee'),
    (AbilityKind.classAbility, 'Class Ability'),
    (AbilityKind.movement, 'Movement'),
    (AbilityKind.superAbility, 'Super'),
    (AbilityKind.aspect, 'Aspect'),
  ];

  // Short kind labels for the synergy row's affected-abilities subtitle.
  static const _shortKindLabel = {
    AbilityKind.grenade: 'Grenade',
    AbilityKind.melee: 'Melee',
    AbilityKind.classAbility: 'Class Ability',
    AbilityKind.movement: 'Movement',
    AbilityKind.superAbility: 'Super',
    AbilityKind.aspect: 'Aspect',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(loadedExoticAbilityRepositoryProvider);
    if (repo == null) return const SizedBox.shrink();

    final classType = detail.item.classType ?? 3;
    // The plug names each present ability kind's socket(s) can hold, so a
    // name-scoped exotic can be listed under its kind whenever the socket could
    // hold the ability it buffs (a discovery listing, unlike the equipped-only
    // badge). Kinds absent from this map have no socket on this subclass.
    final plugNamesByKind = <AbilityKind, Set<String>>{};
    for (final g in detail.groups) {
      for (final s in g.sockets) {
        if (s.abilityKind case final AbilityKind k) {
          final set = plugNamesByKind[k] ??= <String>{};
          if (s.equipped?.name case final String n) set.add(n);
          for (final o in s.options) {
            set.add(o.name);
          }
        }
      }
    }

    // Broad-synergy exotics (general across 2+ kinds) list once at the top; the
    // per-kind sections below exclude them (the repo already does).
    final synergy = repo.synergyExoticsFor(classType, detail.element);

    // One section per present kind: its general exotics (name only) plus its
    // name-scoped exotics (with the specific ability as a subtitle).
    final sections = <(String, List<_ColumnEntry>)>[];
    for (final (kind, label) in _kindOrder) {
      final plugNames = plugNamesByKind[kind];
      if (plugNames == null) continue; // no socket of this kind
      final entries = <_ColumnEntry>[
        for (final e in repo.generalExoticsFor(kind, classType, detail.element))
          (exotic: e, affects: null),
        for (final m in repo.namedColumnExoticsFor(
            kind, classType, detail.element, plugNames))
          (exotic: m.exotic, affects: m.names.join(', ')),
      ]..sort((a, b) => a.exotic.name.compareTo(b.exotic.name));
      if (entries.isNotEmpty) sections.add((label, entries));
    }
    if (synergy.isEmpty && sections.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: _width,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: ArmoryPalette.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXOTIC ARMOR',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Subclass ability interactions',
              style: TextStyle(
                fontSize: 10,
                color: ArmoryPalette.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            // Synergy exotics: those that broadly buff several abilities at once
            // (e.g. Crown of Tempests → Arc grenade/melee/super), listed once
            // with the kinds they affect rather than repeated under each.
            if (synergy.isNotEmpty) ...[
              const Text(
                'ABILITY SYNERGY',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: ArmoryPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final exotic in synergy)
                _GeneralExoticRow(
                    exotic: exotic, affects: _affectsLabel(exotic)),
              const SizedBox(height: 14),
            ],
            for (final (label, entries) in sections) ...[
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: ArmoryPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in entries)
                _GeneralExoticRow(
                    exotic: entry.exotic, affects: entry.affects),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// The affected-abilities subtitle for a synergy row, e.g. "Arc: Grenade,
  /// Melee, Super" (element prefix only when every general interaction is gated
  /// to one element) or "Grenade, Melee, Class Ability" for a type-level one.
  String _affectsLabel(ExoticAbilityInteraction exotic) {
    final kinds = exotic.generalKinds(detail.element);
    final names =
        kinds.map((k) => _shortKindLabel[k] ?? k.token).join(', ');
    // Prefix the element when the general interactions are all gated to this
    // subclass's element (an "any Arc ability" style exotic).
    final gated = exotic.interactions
        .where((i) => !i.isNameScoped)
        .every((i) => i.element == detail.element);
    final elementName = _elementName(detail.element);
    return gated && elementName != null ? '$elementName: $names' : names;
  }

  static String? _elementName(int element) => switch (element) {
        2 => 'Arc',
        3 => 'Solar',
        4 => 'Void',
        6 => 'Stasis',
        7 => 'Strand',
        _ => null,
      };
}

/// One exotic in the general-exotics column: its icon and name, hoverable for a
/// tooltip showing the exotic's effect (its intrinsic perk description) and, for
/// covered perks, the Clarity community insight — mirroring the ability-socket
/// tooltip.
class _GeneralExoticRow extends ConsumerWidget {
  const _GeneralExoticRow({required this.exotic, this.affects});

  final ExoticAbilityInteraction exotic;

  /// For a synergy row, the abilities it broadly affects (e.g. "Arc: Grenade,
  /// Melee, Super"), shown as a subtitle under the name. Null for a per-kind row
  /// (which already sits under its ability's header).
  final String? affects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = exotic.perkHash == null
        ? null
        : ref.watch(clarityInsightProvider(exotic.perkHash!));

    final row = Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: exotic.iconUrl == null
                ? const ColoredBox(color: ArmoryPalette.scrim26)
                : CachedNetworkImage(
                    imageUrl: exotic.iconUrl!,
                    cacheManager: ItemIconCache.instance,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: ArmoryPalette.scrim26),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exotic.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: ArmoryPalette.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
                if (affects != null)
                  Text(
                    affects!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ArmoryPalette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // No effect text and no insight → a plain row (the name alone is the info).
    if (exotic.description.isEmpty && insight == null) return row;

    return Tooltip(
      // Read-only, like the ability-socket tooltip: taps pass through and any
      // insight links stay non-interactive.
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
              Text(
                exotic.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ArmoryPalette.textPrimary,
                ),
              ),
              if (exotic.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  exotic.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ArmoryPalette.textPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
              if (insight != null) ...[
                const SizedBox(height: 8),
                Container(height: 1, color: ArmoryPalette.borderStrong),
                const SizedBox(height: 6),
                const Text(
                  'COMMUNITY INSIGHT · CLARITY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: ArmoryPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ClarityInsightText(lines: insight.lines, fontSize: 11),
              ],
            ],
          ),
        ),
      ),
      preferBelow: false,
      margin: const EdgeInsets.all(8),
      child: MouseRegion(cursor: SystemMouseCursors.help, child: row),
    );
  }
}


/// The header Equip button for an owned, not-currently-equipped subclass.
/// Equips it in-game via [MoveController.equipSubclass] and closes the modal so
/// the grid's equip-highlight is visible.
class _EquipButton extends ConsumerWidget {
  const _EquipButton({required this.item});

  final DestinyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () {
        ref.read(moveControllerProvider.notifier).equipSubclass(item);
        Navigator.of(context).maybePop();
      },
      icon: const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('Equip'),
    );
  }
}

/// A summary of the net stat change from the equipped fragments — one chip per
/// changed stat (its icon + a signed number), coloured gold for a gain and red
/// for a loss. Shown only when at least one equipped fragment alters a stat.
class _FragmentStatSummary extends StatelessWidget {
  const _FragmentStatSummary({required this.effects});

  final List<SubclassStatEffect> effects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FRAGMENT STATS',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [for (final e in effects) _FragmentStatChip(effect: e)],
        ),
      ],
    );
  }
}

/// One stat in the fragment summary: the stat icon and its signed net value.
class _FragmentStatChip extends StatelessWidget {
  const _FragmentStatChip({required this.effect});

  final SubclassStatEffect effect;

  @override
  Widget build(BuildContext context) {
    final color = effect.beneficial
        ? ArmoryPalette.masterworkGold
        : ArmoryPalette.statPenaltyRed;
    return Tooltip(
      message: effect.name,
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (effect.iconUrl != null)
            SizedBox(
              width: 18,
              height: 18,
              child: CachedNetworkImage(
                imageUrl: effect.iconUrl!,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            '${effect.value > 0 ? '+' : ''}${effect.value}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// A small "🔒 NOT UNLOCKED" pill shown in the header of a not-owned subclass
/// modal, so it reads as browse-only (its options are all view-only).
class _NotUnlockedPill extends StatelessWidget {
  const _NotUnlockedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ArmoryPalette.scrim87,
        borderRadius: ArmoryRadius.sm,
        border: Border.all(color: ArmoryPalette.borderStrong),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 12, color: ArmoryPalette.textSecondary),
          SizedBox(width: 5),
          Text(
            'NOT UNLOCKED',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: ArmoryPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One socket-category section: the group label and a row of its sockets, each
/// a chip that opens the socket's option grid.
class _SocketGroupSection extends StatelessWidget {
  const _SocketGroupSection({
    required this.item,
    required this.group,
    required this.element,
  });

  final DestinyItem item;
  final SubclassSocketGroup group;

  /// The subclass's element (damage type), for scoping the exotic-interaction
  /// badge to element-gated exotics.
  final int element;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label.isEmpty ? '—' : group.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final socket in group.sockets)
              _SubclassSocketChip(
                item: item,
                socket: socket,
                diamond: group.isSuper,
                element: element,
              ),
          ],
        ),
      ],
    );
  }
}

/// One editable subclass socket: the equipped plug as a chip that opens a grid
/// of the socket's options. Picking a non-equipped option inserts it in-game;
/// the highlight moves optimistically via [gearModalPlugOverrideProvider]. The
/// equipped plug's Clarity insight (fragments and class abilities light up)
/// renders in an expander beneath the chip.
class _SubclassSocketChip extends ConsumerStatefulWidget {
  const _SubclassSocketChip({
    required this.item,
    required this.socket,
    required this.element,
    this.diamond = false,
  });

  final DestinyItem item;
  final SubclassSocket socket;

  /// The subclass's element, for scoping element-gated exotic interactions.
  final int element;

  /// Whether the equipped/option icons render as a diamond (the Super socket)
  /// rather than a square.
  final bool diamond;

  @override
  ConsumerState<_SubclassSocketChip> createState() =>
      _SubclassSocketChipState();
}

class _SubclassSocketChipState extends ConsumerState<_SubclassSocketChip> {
  final _controller = MenuController();

  static const _gridColumns = 6;
  static const _cellSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final socket = widget.socket;
    final overrides = ref.watch(gearModalPlugOverrideProvider);
    final overrideHash = overrides[socket.socketIndex];
    // The chip shows the optimistic pick if one is pending, else the equipped
    // plug, else the socket's first option — so a not-owned (definition-only)
    // subclass, which has nothing equipped, still renders a chip whose picker
    // opens to browse every option (none of them selectable).
    final override = overrideHash == null
        ? null
        : socket.options
            .where((p) => p.plugHash == overrideHash)
            .firstOrNull;
    final shown =
        override ?? socket.equipped ?? socket.options.firstOrNull;
    if (shown == null) return const SizedBox.shrink();

    // A fragment socket beyond the aspects' granted capacity is locked: greyed
    // out with no picker, so the user can't try to socket a fragment the game
    // would reject.
    final locked = !socket.available;

    // Exotic armor that interacts with this ability (for the equipped chip's
    // corner badge + tooltip). Matched by ability kind, the subclass's class and
    // element, and — for name-scoped exotics — the plug currently shown in this
    // chip ([shown]: the equipped plug, or the browsed one for an unowned
    // subclass). Matching the shown plug (not every option) means a name-scoped
    // exotic badges only the ability it actually buffs — e.g. Stormdancer's Brace
    // badges Stormtrance, not Chaos Reach, even though both are Arc supers the one
    // super socket can hold. Empty for a non-badged socket or while loading.
    final abilityKind = socket.abilityKind;
    final exoticRepo = ref.watch(loadedExoticAbilityRepositoryProvider);
    final interactions = (abilityKind == null || exoticRepo == null)
        ? const <ExoticAbilityInteraction>[]
        : exoticRepo.exoticsFor(
            abilityKind,
            widget.item.classType ?? 3,
            widget.element,
            [shown.name],
          );

    return SizedBox(
      width: _cellSize + 8,
      child: Opacity(
        opacity: locked ? 0.35 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MenuAnchor(
              controller: _controller,
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surface,
                ),
                padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
              ),
              builder: (context, controller, _) => _SubclassPlugIcon(
                key: ValueKey('subclass-socket-${socket.socketIndex}'),
                plug: shown,
                size: _cellSize,
                selected: false,
                diamond: widget.diamond,
                interactions: interactions,
                onTap: (locked || socket.options.length < 2)
                    ? null
                    : () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
              ),
              menuChildren: [
                SizedBox(
                  width: _gridColumns * _cellSize,
                  child: Wrap(
                    children: [
                      for (final option in socket.options)
                        Builder(builder: (context) {
                          // Every option shows. Its state drives whether it can
                          // be picked and what its tooltip says: equippable
                          // (unlocked here), equipped in another slot (owned but
                          // can't duplicate), or not unlocked (view-only). Only
                          // equippable, non-current options fire an insert.
                          final state = socket.optionState(option);
                          final isCurrent = option.plugHash == shown.plugHash;
                          final selectable = !isCurrent &&
                              state == SubclassOptionState.equippable;
                          return _SubclassPlugIcon(
                            key: ValueKey('subclass-option-${option.plugHash}'),
                            plug: option,
                            size: _cellSize,
                            selected: isCurrent,
                            state: state,
                            diamond: widget.diamond,
                            onTap: !selectable
                                ? null
                                : () {
                                    _controller.close();
                                    ref
                                        .read(moveControllerProvider.notifier)
                                        .insertPlug(
                                          widget.item,
                                          socketIndex: socket.socketIndex,
                                          plugHash: option.plugHash,
                                          plugName: option.name,
                                        );
                                  },
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              shown.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

/// A subclass plug's square icon, hoverable for a rich tooltip (name,
/// description, stat effects, and — for covered plugs — the Clarity community
/// insight) and clickable to open the picker or select an option. A [selected]
/// option is ringed; a null [onTap] is a no-op. A non-equippable [state]
/// (equipped in another slot, or not unlocked) is greyed and carries a matching
/// notice in its tooltip, but still shows its details on hover.
class _SubclassPlugIcon extends ConsumerWidget {
  const _SubclassPlugIcon({
    super.key,
    required this.plug,
    required this.size,
    required this.selected,
    this.state = SubclassOptionState.equippable,
    this.diamond = false,
    this.onTap,
    this.interactions = const [],
  });

  final ItemPlug plug;
  final double size;
  final bool selected;
  final SubclassOptionState state;

  /// Whether the icon renders as a diamond (clipped + diamond border) rather
  /// than a rounded square — the Super socket, matching the in-game shape.
  final bool diamond;
  final VoidCallback? onTap;

  /// Exotic armor pieces that interact with this ability, driving the corner
  /// badge and a tooltip section. Empty (the default) for picker options and
  /// any socket with no known interaction, which renders no badge.
  final List<ExoticAbilityInteraction> interactions;

  bool get _dimmed => state != SubclassOptionState.equippable;

  /// How much a plate composite is scaled up so a rounded/circular plate covers
  /// the diamond's corners (the clip trims the overflow). 1 for a square icon.
  static const double _diamondPlateScale = 1.1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The plug's community insight (fragments and class abilities light up;
    // aspects/supers have none, so the block is skipped). Hover-only, per the
    // chosen layout — the narrow icon grid has no room for an expander.
    final insight = ref.watch(clarityInsightProvider(plug.plugHash));
    // Class-ability / movement plugs ship the wrong (Stasis-blue) baked plate,
    // so when a corrected plate + transparent glyph are provided, composite
    // those (glyph over the element plate) instead of the flat icon.
    final plateUrl = plug.plateUrl;
    final foregroundUrl = plug.foregroundUrl;
    // On a diamond (super) socket a circular/rounded plate is scaled up so it
    // covers the diamond's corners (the clip trims the overflow).
    final plateScale = diamond ? _diamondPlateScale : 1.0;
    final Widget image;
    if (plateUrl != null && foregroundUrl != null) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: plateScale,
            child: CachedNetworkImage(
              imageUrl: plateUrl,
              cacheManager: ItemIconCache.instance,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: ArmoryPalette.scrim26),
            ),
          ),
          Transform.scale(
            scale: plateScale,
            child: CachedNetworkImage(
              imageUrl: foregroundUrl,
              cacheManager: ItemIconCache.instance,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      );
    } else if (plug.iconUrl == null) {
      image = const ColoredBox(color: ArmoryPalette.scrim26);
    } else {
      image = CachedNetworkImage(
        imageUrl: plug.iconUrl!,
        cacheManager: ItemIconCache.instance,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        errorWidget: (_, _, _) => const ColoredBox(color: ArmoryPalette.scrim26),
      );
    }
    return Tooltip(
      // Pointer events pass through to the modal beneath, so the tooltip's
      // insight links are read-only (matching the gear modal's perk tooltip).
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
              Text(
                plug.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ArmoryPalette.textPrimary,
                ),
              ),
              // A non-equippable option says why, so its greyed state reads as
              // intentional (locked, or already socketed elsewhere), not broken.
              if (state == SubclassOptionState.equippedElsewhere ||
                  state == SubclassOptionState.locked) ...[
                const SizedBox(height: 4),
                Text(
                  state == SubclassOptionState.equippedElsewhere
                      ? 'Equipped in another slot'
                      : 'Not unlocked',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: ArmoryPalette.textSecondary,
                  ),
                ),
              ],
              if (plug.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plug.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ArmoryPalette.textPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
              // Stat changes (e.g. a fragment's -10 Discipline), coloured by
              // benefit, not raw sign.
              if (plug.statEffects.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final e in plug.statEffects)
                  Text(
                    '${e.value > 0 ? '+' : ''}${e.value} ${e.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: e.beneficial
                          ? ArmoryPalette.masterworkGold
                          : ArmoryPalette.statPenaltyRed,
                    ),
                  ),
              ],
              if (insight != null) ...[
                const SizedBox(height: 8),
                Container(height: 1, color: ArmoryPalette.borderStrong),
                const SizedBox(height: 6),
                const Text(
                  'COMMUNITY INSIGHT · CLARITY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: ArmoryPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ClarityInsightText(lines: insight.lines, fontSize: 11),
              ],
              if (interactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(height: 1, color: ArmoryPalette.borderStrong),
                const SizedBox(height: 6),
                const Text(
                  'EXOTIC ARMOR INTERACTIONS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: ArmoryPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                for (final exotic in interactions)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (exotic.iconUrl != null) ...[
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CachedNetworkImage(
                              imageUrl: exotic.iconUrl!,
                              cacheManager: ItemIconCache.instance,
                              fit: BoxFit.contain,
                              fadeInDuration: Duration.zero,
                              errorWidget: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            exotic.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: ArmoryPalette.textPrimary
                                  .withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      preferBelow: false,
      margin: const EdgeInsets.all(8),
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: interactions.isEmpty
                ? _framedIcon(context, theme, image)
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _framedIcon(context, theme, image),
                      // A small exotic-marker badge in the top-right corner,
                      // signalling that some exotic armor interacts with this
                      // ability (details in the hover tooltip).
                      const Positioned(
                        top: -3,
                        right: -3,
                        child: _ExoticInteractionBadge(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Frame [image] in the plug's shape: a diamond (clip + diamond border) for a
  /// Super socket, else a rounded square. The selected plug and one equipped in
  /// another slot share the accent border at full brightness; only the artwork
  /// dims for a non-equippable option (so its ring still reads).
  Widget _framedIcon(BuildContext context, ThemeData theme, Widget image) {
    final accent = selected || state == SubclassOptionState.equippedElsewhere;
    final borderColor =
        accent ? theme.colorScheme.primary : ArmoryPalette.borderStronger;
    final borderWidth = accent ? 1.5 : 1.0;
    final dimmed = Opacity(opacity: _dimmed ? 0.35 : 1, child: image);

    if (diamond) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          foregroundPainter:
              DiamondBorderPainter(color: borderColor, width: borderWidth),
          child: ClipPath(
            clipper: const DiamondClipper(),
            child: ColoredBox(color: ArmoryPalette.scrim26, child: dimmed),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: ArmoryRadius.sm,
        color: ArmoryPalette.scrim26,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: dimmed,
    );
  }
}

/// The small gold corner marker on an ability socket signalling that some
/// exotic armor interacts with it — a filled gold circle with a dark star, the
/// exotic-rarity cue. The interacting exotics are listed in the socket's
/// tooltip; this is only the at-a-glance flag.
class _ExoticInteractionBadge extends StatelessWidget {
  const _ExoticInteractionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: ArmoryPalette.tierDiamondGold,
        shape: BoxShape.circle,
        border: Border.all(color: ArmoryPalette.scrim87, width: 1),
      ),
      child: const Icon(
        Icons.star,
        size: 9,
        color: ArmoryPalette.onAccent,
      ),
    );
  }
}
