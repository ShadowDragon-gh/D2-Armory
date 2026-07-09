import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/models/inventory_grid.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/class_emblem.dart';
import '../../widgets/item_tile.dart';

/// DIM-style inventory grid: one column per character (by last-played) plus a
/// wide vault column, rows per equipment bucket. Read-only. Rendered inside
/// [AppShell], which supplies the app bar and search.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  static const double tile = 52;
  static const double equippedTile = 72;
  static const double gap = 6;
  static const double labelWidth = 88;

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
    final grid = ref.watch(inventoryGridProvider);

    return grid.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message:
            error is Failure ? error.message : 'Could not load inventory.',
        onRetry: () => ref.invalidate(inventoryGridProvider),
      ),
      data: (grid) => _Grid(grid: grid),
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
          for (final bucket in EquipmentBucket.values)
            _BucketRow(bucket: bucket, characters: characters, vault: vault),
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
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: InventoryScreen.labelWidth),
          for (final owner in characters) ...[
            const SizedBox(width: InventoryScreen.columnGap),
            SizedBox(
              width: InventoryScreen.characterColumnWidth,
              child: _OwnerHeader(owner: owner),
            ),
          ],
          if (vault != null) ...[
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: InventoryScreen.labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 14),
              child: Text(
                bucket.label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          for (final owner in characters) ...[
            const SizedBox(width: InventoryScreen.columnGap),
            _Cell(
              width: InventoryScreen.characterColumnWidth,
              child: _CharacterCell(owner: owner, bucket: bucket),
            ),
          ],
          if (vault != null) ...[
            const SizedBox(width: InventoryScreen.columnGap),
            Expanded(
              child: _Cell(
                child: _VaultCell(owner: vault!, bucket: bucket),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A bordered grid cell with consistent padding.
class _Cell extends StatelessWidget {
  const _Cell({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white10),
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      padding: const EdgeInsets.all(InventoryScreen.gap),
      child: child,
    );
    return cell;
  }
}

/// Equipped item on the left, then up to a 3-wide grid of the rest.
class _CharacterCell extends StatelessWidget {
  const _CharacterCell({required this.owner, required this.bucket});

  final InventoryOwner owner;
  final EquipmentBucket bucket;

  @override
  Widget build(BuildContext context) {
    final equipped = owner.equippedIn(bucket.hash);
    final rest = owner.unequippedIn(bucket.hash);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The tile sizes its own height (icon + footer); the empty slot is a
        // plain square, so give only it a fixed height.
        equipped == null
            ? const SizedBox(
                width: InventoryScreen.equippedTile,
                height: InventoryScreen.equippedTile,
                child: _EmptySlot(),
              )
            : ItemTile(item: equipped, size: InventoryScreen.equippedTile),
        const SizedBox(width: InventoryScreen.gap),
        SizedBox(
          width: InventoryScreen._invGridWidth,
          child: Wrap(
            spacing: InventoryScreen.gap,
            runSpacing: InventoryScreen.gap,
            children: [
              for (final item in rest) ItemTile(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vault items wrap to fill the available width.
class _VaultCell extends StatelessWidget {
  const _VaultCell({required this.owner, required this.bucket});

  final InventoryOwner owner;
  final EquipmentBucket bucket;

  @override
  Widget build(BuildContext context) {
    final items = owner.itemsFor(bucket.hash);
    if (items.isEmpty) return const SizedBox(height: InventoryScreen.tile);
    return Wrap(
      spacing: InventoryScreen.gap,
      runSpacing: InventoryScreen.gap,
      children: [for (final item in items) ItemTile(item: item)],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          color: Colors.white.withValues(alpha: 0.02),
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
        borderRadius: BorderRadius.circular(6),
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
                colors: [Colors.black87, Colors.black26],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (owner.isVault)
                  const Icon(Icons.inventory_2, size: 20, color: Colors.white)
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
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                                  color: Colors.amber,
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
          border: Border.all(color: Colors.amber, width: 1.6),
        ),
      ),
    );
  }
}
