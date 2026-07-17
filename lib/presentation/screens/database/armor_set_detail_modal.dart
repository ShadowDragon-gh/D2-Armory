import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/armor_set.dart';
import '../../../domain/models/item_detail.dart';
import '../../providers/database_provider.dart';
import '../../theme/armory_palette.dart';

/// The armor-set detail modal: the set name, its set-bonus perks, and a gallery
/// of each member piece's screenshot. Backed by [selectedArmorSetDetailProvider]
/// (set when a collapsed set row is tapped) and closes when it clears.
class ArmorSetDetailModal extends ConsumerWidget {
  const ArmorSetDetailModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(selectedArmorSetDetailProvider);
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
        constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 820),
        child: _SetBody(detail: detail),
      ),
    );
  }
}

/// Show the armor-set detail modal. Closing it clears the selected set. No-ops
/// when it is already up. Guarded with its own flag so it does not fight the
/// item modal's [showGearDetailModal].
Future<void> showArmorSetDetailModal(BuildContext context, WidgetRef ref) {
  if (ref.read(armorSetModalOpenProvider)) return Future<void>.value();
  ref.read(armorSetModalOpenProvider.notifier).set(true);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const ArmorSetDetailModal(),
  ).whenComplete(() {
    ref.read(armorSetModalOpenProvider.notifier).set(false);
    ref.read(selectedArmorSetProvider.notifier).clear();
  });
}

class _SetBody extends ConsumerWidget {
  const _SetBody({required this.detail});

  final ArmorSetDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final set = detail.set;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: set name + close.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          color: ArmoryPalette.scrim26,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  set.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${set.memberHashes.length} pieces',
                style: TextStyle(
                    fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
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
                if (set.perks.isNotEmpty) ...[
                  SetBonusSection(perks: set.perks),
                  const SizedBox(height: 20),
                ] else ...[
                  Text(
                    'This is a legacy set with no set bonus.',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                ],
                _PieceGallery(members: detail.members),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The member-piece screenshots laid out as one row per character class
/// (Titan, Hunter, Warlock), each row ordered left-to-right by armor slot:
/// helmet, arms, chest, legs, then the class item. Tapping a piece opens its
/// detail modal.
class _PieceGallery extends ConsumerWidget {
  const _PieceGallery({required this.members});

  final List<GearDetail> members;

  // DestinyClass rows in display order, and armor-slot subtypes in left-to-right
  // order (helmet, arms, chest, legs, class item).
  static const _classOrder = [0, 1, 2]; // Titan, Hunter, Warlock
  static const _classLabel = {0: 'Titan', 1: 'Hunter', 2: 'Warlock'};
  static const _slotOrder = [26, 27, 28, 29, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Pieces bucketed by class; any class-agnostic piece (classType 3/any) goes
    // in its own trailing row so it is never dropped.
    final byClass = <int, List<GearDetail>>{};
    for (final m in members) {
      byClass.putIfAbsent(m.item.classType ?? 3, () => []).add(m);
    }
    int slotRank(GearDetail d) {
      final i = _slotOrder.indexOf(d.item.itemSubType);
      return i == -1 ? _slotOrder.length : i;
    }
    for (final list in byClass.values) {
      list.sort((a, b) => slotRank(a).compareTo(slotRank(b)));
    }
    final rows = [
      ..._classOrder.where(byClass.containsKey),
      ...byClass.keys.where((c) => !_classOrder.contains(c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cls in rows) ...[
          Text(
            _classLabel[cls] ?? 'Any',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          // A full class row (up to 5 pieces) can exceed the modal width, so it
          // scrolls horizontally rather than overflowing.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in byClass[cls]!) ...[
                  SizedBox(width: 240, child: _PieceCard(detail: m)),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PieceCard extends ConsumerWidget {
  const _PieceCard({required this.detail});

  final GearDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = detail.screenshotUrl;
    return InkWell(
      borderRadius: ArmoryRadius.md,
      onTap: () {
        // Deep-link to the piece's own detail modal. Close this set modal first
        // (so its open-guard clears), then select the item — the Database
        // screen's listener opens the item modal.
        Navigator.of(context).maybePop();
        ref.read(selectedDatabaseItemProvider.notifier)
            .select(detail.item.itemHash);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
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
          ),
          const SizedBox(height: 6),
          Text(
            detail.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            detail.item.itemTypeDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The set-bonus section: each [SetPerk] (2-piece / 4-piece) as an icon, its
/// required piece count, name, and description. Reused by the set-detail modal
/// and the single-piece armor detail modal.
class SetBonusSection extends StatelessWidget {
  const SetBonusSection({super.key, required this.perks});

  final List<SetPerk> perks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SET BONUS',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final perk in perks) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: perk.iconUrl == null
                    ? const Icon(Icons.workspace_premium, size: 20)
                    : CachedNetworkImage(
                        imageUrl: perk.iconUrl!,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.workspace_premium, size: 20),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${perk.requiredSetCount} Piece: ${perk.name}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (perk.description.isNotEmpty)
                      Text(
                        perk.description,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
