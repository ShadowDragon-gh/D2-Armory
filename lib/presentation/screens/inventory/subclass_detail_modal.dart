import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/network/item_icon_cache.dart';
import '../../../domain/models/destiny_item.dart';
import '../../../domain/models/item_detail.dart';
import '../../../domain/models/subclass_detail.dart';
import '../../providers/clarity_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/armory_palette.dart';
import '../../widgets/clarity_insight_view.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in detail.groups) ...[
                  _SocketGroupSection(item: detail.item, group: group),
                  const SizedBox(height: 20),
                  // The net fragment stat totals sit directly under the
                  // Fragments section they summarise.
                  if (group.isFragments &&
                      detail.fragmentStatSummary.isNotEmpty) ...[
                    _FragmentStatSummary(effects: detail.fragmentStatSummary),
                    const SizedBox(height: 20),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
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
  const _SocketGroupSection({required this.item, required this.group});

  final DestinyItem item;
  final SubclassSocketGroup group;

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
              _SubclassSocketChip(item: item, socket: socket),
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
  const _SubclassSocketChip({required this.item, required this.socket});

  final DestinyItem item;
  final SubclassSocket socket;

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
    this.onTap,
  });

  final ItemPlug plug;
  final double size;
  final bool selected;
  final SubclassOptionState state;
  final VoidCallback? onTap;

  bool get _dimmed => state != SubclassOptionState.equippable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The plug's community insight (fragments and class abilities light up;
    // aspects/supers have none, so the block is skipped). Hover-only, per the
    // chosen layout — the narrow icon grid has no room for an expander.
    final insight = ref.watch(clarityInsightProvider(plug.plugHash));
    final image = plug.iconUrl == null
        ? const ColoredBox(color: ArmoryPalette.scrim26)
        : CachedNetworkImage(
            imageUrl: plug.iconUrl!,
            cacheManager: ItemIconCache.instance,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            errorWidget: (_, _, _) =>
                const ColoredBox(color: ArmoryPalette.scrim26),
          );
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
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: ArmoryRadius.sm,
                color: ArmoryPalette.scrim26,
                // The selected (equipped-here) plug and an option equipped in
                // another slot share the same accent border at full brightness,
                // so a same-family pick reads as "in use". Only the artwork is
                // dimmed (see the Opacity below) to show the option is not here.
                border: Border.all(
                  color:
                      (selected ||
                          state == SubclassOptionState.equippedElsewhere)
                      ? theme.colorScheme.primary
                      : ArmoryPalette.borderStronger,
                  width:
                      (selected ||
                          state == SubclassOptionState.equippedElsewhere)
                      ? 1.5
                      : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              // A non-equippable option (locked, or equipped elsewhere) dims
              // only its artwork — not its border — so an equipped-elsewhere
              // plug keeps the same bright accent ring as the equipped one. Its
              // tooltip still shows on hover so details stay viewable.
              child: Opacity(opacity: _dimmed ? 0.35 : 1, child: image),
            ),
          ),
        ),
      ),
    );
  }
}
