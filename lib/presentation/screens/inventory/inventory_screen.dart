import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/destiny/drop_validation.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/models/inventory_grid.dart';
import '../../providers/database_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../theme/armory_palette.dart';
import '../../widgets/class_emblem.dart';
import '../../widgets/inventory_poller.dart';
import '../../widgets/item_tile.dart';
import '../../widgets/move_toast.dart';
import '../database/database_detail_modal.dart';
import 'item_detail_panel.dart';

/// DIM-style inventory grid: one column per character (by last-played) plus a
/// wide vault column, rows per equipment bucket. Read-only. Rendered inside
/// [AppShell], which supplies the app bar and search.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  static const double tile = 52;
  static const double equippedTile = 72;
  static const double gap = 6;

  /// Horizontal separation between adjacent columns (characters and vault).
  static const double columnGap = 20;

  /// Width of the 3-wide inventory grid beside the equipped slot.
  static const double _invGridWidth = tile * 3 + gap * 2;

  /// Content of a character cell: equipped slot + one gap + the 3-wide grid.
  static const double _characterCellContent =
      equippedTile + gap + _invGridWidth;

  /// Full character column, including the [_Cell] padding (both sides) and its
  /// 1px left border, so the fixed width fully contains the content.
  static const double characterColumnWidth =
      _characterCellContent + gap * 2 + 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tapping a tile selects the item's definition, which opens the same
    // gear-detail modal the Database tab uses. showGearDetailModal ignores
    // the call when the modal is already up (the Database screen also listens
    // to this selection from the shell's IndexedStack).
    ref.listen(selectedDatabaseItemProvider, (_, next) {
      if (next != null) showGearDetailModal(context, ref);
    });

    // A completed (or failed) drag-to-move surfaces one top-right toast. A
    // failure — including a two-hop move stranded in the vault — reads as a
    // failure by colour and icon; never a silent success.
    ref.listen(moveControllerProvider, (_, outcome) {
      if (outcome == null) return;
      showMoveToast(context, outcome);
      ref.read(moveControllerProvider.notifier).clear();
    });

    final grid = ref.watch(inventoryGridProvider);

    final body = grid.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message:
            error is Failure ? error.message : 'Could not load inventory.',
        onRetry: () => ref.invalidate(inventoryGridProvider),
      ),
      data: (grid) => _Grid(grid: grid),
    );

    // The detail panel overlays the grid on the right edge, so opening or
    // closing it never resizes the grid (no reflow jank). Wrapped in the poller
    // so the grid stays near-live while the inventory is on screen.
    return InventoryPoller(
      child: Stack(
        children: [
          Positioned.fill(child: body),
          const Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: AnimatedItemDetailPanel(),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.grid});

  final InventoryGrid grid;

  @override
  Widget build(BuildContext context) {
    final characters = grid.owners.where((o) => !o.isVault).toList();
    final vault = grid.owners.where((o) => o.isVault).firstOrNull;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(characters: characters, vault: vault),
          for (final bucket in EquipmentBucket.values) ...[
            _BucketRow(bucket: bucket, characters: characters, vault: vault),
            // Full-width rule spanning columns and the gaps between them.
            const Divider(height: 1, thickness: 1),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.characters, required this.vault});

  final List<InventoryOwner> characters;
  final InventoryOwner? vault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plain spacers here (no vertical rule between the header banners).
          for (var i = 0; i < characters.length; i++) ...[
            if (i > 0) const SizedBox(width: InventoryScreen.columnGap),
            SizedBox(
              width: InventoryScreen.characterColumnWidth,
              child: _OwnerHeader(owner: characters[i]),
            ),
          ],
          if (vault != null) ...[
            if (characters.isNotEmpty)
              const SizedBox(width: InventoryScreen.columnGap),
            Expanded(child: _OwnerHeader(owner: vault!)),
          ],
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.bucket,
    required this.characters,
    required this.vault,
  });

  final EquipmentBucket bucket;
  final List<InventoryOwner> characters;
  final InventoryOwner? vault;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < characters.length; i++) ...[
              if (i > 0) const _ColumnGap(),
              _Cell(
                width: InventoryScreen.characterColumnWidth,
                child: _CharacterCell(owner: characters[i], bucket: bucket),
              ),
            ],
            if (vault != null) ...[
              if (characters.isNotEmpty) const _ColumnGap(),
              Expanded(
                child: _Cell(
                  child: _VaultCell(owner: vault!, bucket: bucket),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The space between two columns, with a full-height divider line running down
/// its centre (half the gap width from each column's content edge). Relies on
/// the parent Row using [CrossAxisAlignment.stretch] so it fills the row.
class _ColumnGap extends StatelessWidget {
  const _ColumnGap();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: InventoryScreen.columnGap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A 1px line that stretches to the row's full height. Nudged right so
          // it centres on the visual gap between cell *contents* (each cell has
          // `gap` padding on the side facing this divider).
          Padding(
            padding: const EdgeInsets.only(left: InventoryScreen.gap),
            child: Container(width: 1, color: ArmoryPalette.border),
          ),
        ],
      ),
    );
  }
}

/// A grid cell with consistent padding. Row dividers span the full width in
/// [_Grid]; vertical dividers live in the [_ColumnGap] between columns.
class _Cell extends StatelessWidget {
  const _Cell({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(InventoryScreen.gap),
      child: child,
    );
  }
}

/// Equipped item on the left, then up to a 3-wide grid of the rest. The whole
/// cell is a drop target for transferring an item into this character's slot.
class _CharacterCell extends StatelessWidget {
  const _CharacterCell({required this.owner, required this.bucket});

  final InventoryOwner owner;
  final EquipmentBucket bucket;

  @override
  Widget build(BuildContext context) {
    final equipped = owner.equippedIn(bucket.hash);
    final rest = owner.unequippedIn(bucket.hash);

    return _DropCell(
      owner: owner,
      bucket: bucket,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The equipped slot is its own drop target: dropping a copy already
          // on this character here equips it (canEquip). Dropping a copy from
          // elsewhere is rejected by canEquip and handled by the surrounding
          // transfer cell instead, so the two targets never both accept.
          _EquipTarget(
            owner: owner,
            // The tile sizes its own height (icon + footer); the empty slot is
            // a plain square, so give only it a fixed height.
            child: equipped == null
                ? const SizedBox(
                    width: InventoryScreen.equippedTile,
                    height: InventoryScreen.equippedTile,
                    child: _EmptySlot(),
                  )
                : ItemTile(
                    item: equipped,
                    size: InventoryScreen.equippedTile,
                    ownerId: owner.id,
                  ),
          ),
          const SizedBox(width: InventoryScreen.gap),
          SizedBox(
            width: InventoryScreen._invGridWidth,
            child: Wrap(
              spacing: InventoryScreen.gap,
              runSpacing: InventoryScreen.gap,
              children: [
                for (final item in rest)
                  ItemTile(item: item, ownerId: owner.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vault items wrap to fill the available width. The whole cell is a drop
/// target for transferring an item into the vault.
class _VaultCell extends StatelessWidget {
  const _VaultCell({required this.owner, required this.bucket});

  final InventoryOwner owner;
  final EquipmentBucket bucket;

  @override
  Widget build(BuildContext context) {
    final items = owner.itemsFor(bucket.hash);
    return _DropCell(
      owner: owner,
      bucket: bucket,
      child: items.isEmpty
          ? const SizedBox(
              width: double.infinity, height: InventoryScreen.tile)
          : Wrap(
              spacing: InventoryScreen.gap,
              runSpacing: InventoryScreen.gap,
              children: [
                for (final item in items)
                  ItemTile(item: item, ownerId: owner.id),
              ],
            ),
    );
  }
}

/// Wraps a cell's content in a [DragTarget] that accepts an [ItemDrag] into
/// [owner]'s [bucket]. Validity is decided locally by [canDrop] so an invalid
/// target rejects the drop up front (and tints red) rather than firing a POST
/// that Bungie would bounce. A valid hovered target tints green.
class _DropCell extends ConsumerWidget {
  const _DropCell({
    required this.owner,
    required this.bucket,
    required this.child,
  });

  final InventoryOwner owner;
  final EquipmentBucket bucket;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ItemDrag>(
      onWillAcceptWithDetails: (details) =>
          canDrop(details.data.item, owner, bucket,
                  currentOwnerId: details.data.fromOwnerId)
              .allowed,
      onAcceptWithDetails: (details) =>
          ref.read(moveControllerProvider.notifier).move(details.data, owner),
      builder: (context, candidate, rejected) {
        final Color? highlight = candidate.isNotEmpty
            ? ArmoryPalette.accent200 // valid target (green-ish accent)
            : rejected.isNotEmpty
                ? Theme.of(context).colorScheme.error
                : null;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: highlight == null
                ? null
                : Border.all(color: highlight, width: 2),
            color: highlight?.withValues(alpha: 0.08),
            borderRadius: ArmoryRadius.sm,
          ),
          child: child,
        );
      },
    );
  }
}

/// The equipped-slot drop target: dropping an item already on [owner] here
/// equips it. [canEquip] gates the drop (an off-character copy is rejected, so
/// the surrounding transfer cell handles it instead) and drives the same
/// green/red hover tint as [_DropCell].
class _EquipTarget extends ConsumerWidget {
  const _EquipTarget({required this.owner, required this.child});

  final InventoryOwner owner;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<ItemDrag>(
      onWillAcceptWithDetails: (details) =>
          canEquip(details.data.item, owner,
                  currentOwnerId: details.data.fromOwnerId)
              .allowed,
      onAcceptWithDetails: (details) =>
          ref.read(moveControllerProvider.notifier).equip(details.data, owner),
      builder: (context, candidate, rejected) {
        final Color? highlight = candidate.isNotEmpty
            ? ArmoryPalette.accent200
            : rejected.isNotEmpty
                ? Theme.of(context).colorScheme.error
                : null;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: highlight == null
                ? null
                : Border.all(color: highlight, width: 2),
            color: highlight?.withValues(alpha: 0.08),
            borderRadius: ArmoryRadius.sm,
          ),
          child: child,
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: ArmoryPalette.border),
          color: ArmoryPalette.textPrimary.withValues(alpha: 0.02),
        ),
      );
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.owner});

  final InventoryOwner owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emblem = owner.character?.emblemBackgroundUrl;

    return Container(
      height: 56,
      margin: const EdgeInsets.only(left: InventoryScreen.gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: ArmoryRadius.md,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (emblem != null)
            CachedNetworkImage(
              imageUrl: emblem,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [ArmoryPalette.scrim87, ArmoryPalette.scrim26],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (owner.isVault)
                  const Icon(Icons.inventory_2,
                      size: 20, color: ArmoryPalette.textPrimary)
                else
                  ClassEmblem(
                    classType: owner.character?.classType ?? 3,
                    size: 22,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner.title,
                        style: const TextStyle(
                          fontFamily: ArmoryFonts.display,
                          color: ArmoryPalette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!owner.isVault && owner.character != null)
                        Row(
                          children: [
                            const _PowerDiamond(),
                            const SizedBox(width: 5),
                            Text(
                              '${owner.character!.light}',
                              style: const TextStyle(
                                  color: ArmoryPalette.masterworkGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                    ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// The Destiny power-level glyph: a hollow amber diamond (a rotated square
/// outline), matching the in-game power indicator.
class _PowerDiamond extends StatelessWidget {
  const _PowerDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853981633974483, // 45 degrees
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          border:
              Border.all(color: ArmoryPalette.masterworkGold, width: 1.6),
        ),
      ),
    );
  }
}
