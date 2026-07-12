import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../core/network/item_icon_cache.dart';
import '../../domain/models/destiny_item.dart';
import '../providers/database_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/armory_palette.dart';

/// A single inventory item: the icon square with a footer row beneath it
/// showing the element glyph and power level (so neither covers the art).
/// Equipped items get a gold outline; masterworked items get a subtle gold
/// border and a translucent gold gradient rising from the bottom. Dimmed when
/// an active search filter excludes it.
///
/// When [ownerId] is given and the item is a movable (instanced, unequipped)
/// copy, the tile is a drag source: dragging it carries an [ItemDrag] to a
/// [DragTarget] so it can be transferred. Equipped copies are not draggable —
/// Bungie rejects transferring an equipped item.
class ItemTile extends ConsumerWidget {
  const ItemTile({
    super.key,
    required this.item,
    this.size = 52,
    this.ownerId,
  });

  final DestinyItem item;

  /// Size of the icon square. The footer row adds a little height below it.
  final double size;

  /// The id of the owner (character or vault) this tile sits in. Null in
  /// contexts without a move affordance (e.g. the Database tab), which leaves
  /// the tile tap-only.
  final String? ownerId;

  static const double _footerHeight = 16;

  bool get _draggable =>
      ownerId != null && item.itemInstanceId != null && !item.isEquipped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(compiledQueryProvider);
    final dimmed = !query.isEmpty && !query.matches(item);
    // Hash-keyed like the Database rows: highlighted while this item's
    // definition is open in the shared gear-detail modal.
    final selected = ref.watch(selectedDatabaseItemProvider) == item.itemHash;
    final showCosmetics = ref.watch(showCosmeticsProvider);
    // An applied ornament's flat icon carries the ornament's own (legendary)
    // background. When the item ships a rarity plate + transparent ornament
    // foreground (exotics), composite those so the exotic background is kept;
    // otherwise fall back to the flat ornament icon.
    final plateUrl = showCosmetics ? item.rarityPlateUrl : null;
    final foregroundUrl = showCosmetics ? item.ornamentForegroundUrl : null;
    final useComposite = plateUrl != null && foregroundUrl != null;
    final iconUrl = useComposite
        ? null
        : (showCosmetics ? item.ornamentIconUrl : null) ?? item.iconUrl;

    final elementColor =
        item.damageType == null ? null : DamageType.color(item.damageType!);

    final tile = AnimatedOpacity(
      opacity: dimmed ? 0.2 : 1,
      duration: const Duration(milliseconds: 120),
      child: Tooltip(
        message:
            item.power != null ? '${item.name} · ${item.power}' : item.name,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            // Opens the shared gear-detail modal (the Inventory screen listens
            // to the definition selection and shows it). The instance is
            // recorded first so the modal can offer this item's rolled stats.
            onTap: () {
              ref.read(gearModalInstanceProvider.notifier).select(item);
              ref
                  .read(selectedDatabaseItemProvider.notifier)
                  .select(item.itemHash);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _iconSquare(
                  iconUrl: iconUrl,
                  selected: selected,
                  plateUrl: plateUrl,
                  foregroundUrl: foregroundUrl,
                ),
                if (item.power != null ||
                    elementColor != null ||
                    item.isLocked)
                  _footer(elementColor),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_draggable) return tile;

    // A drag carries this item + its origin owner to a DragTarget. A plain
    // click (no movement past the touch slop) still fires onTap above, so
    // tap-to-open and drag-to-move coexist. The feedback is the icon square
    // lifted with a shadow; the source dims to a placeholder while dragging.
    return Draggable<ItemDrag>(
      data: ItemDrag(item: item, fromOwnerId: ownerId!),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Pause the background poll while a drag is active so a refetch never
      // resets the grid mid-drag.
      onDragStarted: () => ref.read(isDraggingProvider.notifier).start(),
      onDragEnd: (_) => ref.read(isDraggingProvider.notifier).end(),
      onDraggableCanceled: (_, _) =>
          ref.read(isDraggingProvider.notifier).end(),
      feedback: _DragFeedback(
        size: size,
        child: _iconSquare(
          iconUrl: iconUrl,
          plateUrl: plateUrl,
          foregroundUrl: foregroundUrl,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }

  Widget _iconSquare({
    required String? iconUrl,
    bool selected = false,
    String? plateUrl,
    String? foregroundUrl,
  }) {
    final borderColor = selected
        ? ArmoryPalette.accent200 // selection highlight
        : item.isMasterwork
            ? ArmoryPalette.masterworkGold.withValues(alpha: 0.5)
            : ArmoryPalette.borderStronger;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: ArmoryRadius.sm,
        border: Border.all(
          color: borderColor,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Composite the rarity plate + transparent ornament foreground when
          // both are provided (ornamented exotics); otherwise the flat icon.
          if (plateUrl != null && foregroundUrl != null) ...[
            CachedNetworkImage(
              imageUrl: plateUrl,
              cacheManager: ItemIconCache.instance,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => const _IconPlaceholder(),
              errorWidget: (_, _, _) => const ColoredBox(color: ArmoryPalette.scrim26),
            ),
            CachedNetworkImage(
              imageUrl: foregroundUrl,
              cacheManager: ItemIconCache.instance,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ] else if (iconUrl == null)
            const ColoredBox(color: ArmoryPalette.scrim26)
          else
            CachedNetworkImage(
              imageUrl: iconUrl,
              cacheManager: ItemIconCache.instance,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => const _IconPlaceholder(),
              errorWidget: (_, _, _) => const ColoredBox(color: ArmoryPalette.scrim26),
            ),
          // Subtle translucent gold gradient rising from the bottom.
          if (item.isMasterwork)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    ArmoryPalette.masterworkGlow,
                    ArmoryPalette.masterworkGlowEnd,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(Color? elementColor) {
    return Container(
      width: size,
      height: _footerHeight,
      decoration: const BoxDecoration(
        color: ArmoryPalette.scrim35,
        border: Border.fromBorderSide(
            BorderSide(color: ArmoryPalette.borderStronger, width: 0.5)),
        borderRadius:
            BorderRadius.vertical(bottom: ArmoryRadius.smRadius),
      ),
      child: Stack(
        children: [
          // Damage type — always on the left.
          if (elementColor != null && item.elementIconUrl != null)
            Positioned(
              left: 1,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: _footerHeight - 2,
                child: CachedNetworkImage(
                  imageUrl: item.elementIconUrl!,
                  fit: BoxFit.contain,
                  color: elementColor,
                  colorBlendMode: BlendMode.srcIn,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Lock — always on the right.
          if (item.isLocked)
            const Positioned(
              right: 1,
              top: 0,
              bottom: 0,
              child: Icon(Icons.lock,
                  size: 10, color: ArmoryPalette.textSecondary),
            ),
          // Power — always centered.
          if (item.power != null)
            Center(
              child: Text(
                '${item.power}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The floating icon shown under the cursor while dragging a tile: the item's
/// icon square lifted with a drop shadow. Sized explicitly because drag
/// feedback renders in an overlay, outside the grid's layout constraints.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: ArmoryRadius.sm,
          boxShadow: const [
            BoxShadow(
              color: ArmoryPalette.scrim87,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A gently pulsing scrim shown in an icon square while its art downloads, so a
/// not-yet-loaded tile reads as "loading" rather than blank. Fills its parent.
class _IconPlaceholder extends StatefulWidget {
  const _IconPlaceholder();

  @override
  State<_IconPlaceholder> createState() => _IconPlaceholderState();
}

class _IconPlaceholderState extends State<_IconPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.7).animate(_controller),
      child: const ColoredBox(color: ArmoryPalette.scrim35),
    );
  }
}
