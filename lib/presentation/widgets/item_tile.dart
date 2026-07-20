import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../core/destiny/destiny_enums.dart';
import '../../core/network/item_icon_cache.dart';
import '../../domain/models/destiny_item.dart';
import 'diamond_shape.dart';
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

  /// How much a Prismatic subclass's circular plate composite is scaled up on
  /// the diamond tile so the circle covers the diamond's corners (the diamond
  /// clip trims the overflow). Just past 1 — enough to fill the corners without
  /// noticeably shrinking the super glyph.
  static const double _subclassPlateScale = 1.1;

  // Subclasses are equipped by right-click / the modal button, not by dragging,
  // so they are never a drag source (unlike weapons/armor).
  bool get _draggable =>
      ownerId != null &&
      item.itemInstanceId != null &&
      !item.isEquipped &&
      item.itemType != DestinyEnums.typeSubclass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(compiledQueryProvider);
    final dimmed = !query.isEmpty && !query.matches(item);
    // Hash-keyed like the Database rows: highlighted while this item's
    // definition is open in the shared gear-detail modal.
    final selected = ref.watch(selectedDatabaseItemProvider) == item.itemHash;
    // Flashes a green border for a few seconds after this exact copy was moved
    // or equipped, so the user sees where it landed.
    final justMoved = item.itemInstanceId != null &&
        ref.watch(recentlyMovedProvider) == item.itemInstanceId;
    final showCosmetics = ref.watch(showCosmeticsProvider);
    final showTier = ref.watch(showTierProvider);
    // An applied ornament's flat icon carries the ornament's own (legendary)
    // background. When the item ships a rarity plate + transparent ornament
    // foreground (exotics), composite those so the exotic background is kept;
    // otherwise fall back to the flat ornament icon.
    //
    // A subclass reuses the same plate + foreground fields to draw a Prismatic
    // super glyph over the pink Prismatic plate (its flat super icon carries the
    // wrong element colour). That composite is the item's correct icon, not a
    // cosmetic preference, so it is not gated on the cosmetics toggle.
    final compositeAllowed =
        showCosmetics || item.itemType == DestinyEnums.typeSubclass;
    final plateUrl = compositeAllowed ? item.rarityPlateUrl : null;
    final foregroundUrl = compositeAllowed ? item.ornamentForegroundUrl : null;
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
            // A subclass opens the socket-group subclass modal, not the
            // weapon/armor-shaped gear modal. It is also selected into
            // gearModalInstanceProvider so MoveController.insertPlug's
            // override-reset and post-insert reconcile plumbing works unchanged
            // (that path re-selects the instance there after its refetch). Other
            // items open the shared gear-detail modal (the Inventory screen
            // listens to the definition selection and shows it); the instance is
            // recorded first so the modal can offer this item's rolled stats.
            onTap: () {
              if (item.itemType == DestinyEnums.typeSubclass) {
                ref.read(gearModalInstanceProvider.notifier).select(item);
                ref.read(selectedSubclassProvider.notifier).select(item);
                return;
              }
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
                  justMoved: justMoved,
                  plateUrl: plateUrl,
                  foregroundUrl: foregroundUrl,
                  showTier: showTier,
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

    // An owned, not-currently-equipped subclass can be equipped by right-click
    // (a context menu) or the modal button — subclasses don't drag-to-equip.
    final canEquipSubclass = item.itemType == DestinyEnums.typeSubclass &&
        item.itemInstanceId != null &&
        !item.isEquipped;
    if (canEquipSubclass) {
      return _SubclassEquipMenu(item: item, child: tile);
    }

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
    bool justMoved = false,
    String? plateUrl,
    String? foregroundUrl,
    bool showTier = false,
  }) {
    // The just-moved green flash takes precedence over the selection and
    // masterwork borders while it is active.
    final borderColor = justMoved
        ? ArmoryPalette.success
        : selected
            ? ArmoryPalette.accent200 // selection highlight
            : item.isMasterwork
                ? ArmoryPalette.masterworkGold.withValues(alpha: 0.5)
                : ArmoryPalette.borderStronger;
    final borderWidth = (selected || justMoved) ? 2.0 : 1.0;

    // Subclass tiles are diamonds (a rotated square) to match the in-game
    // subclass slot and the diamond-shaped super art — so the icon is clipped to
    // a diamond and the border traces that diamond, rather than the rounded
    // square weapons/armor use. This also masks a Prismatic super's rounded
    // plate composite into the same diamond silhouette as the element supers.
    final isSubclass = item.itemType == DestinyEnums.typeSubclass;
    // A subclass the character does not own is injected as a definition-only
    // item (no instance). It gets a dimming scrim + centre lock, so a locked
    // subclass reads distinctly from an owned one.
    final isLockedSubclass = isSubclass && item.itemInstanceId == null;

    final content = Stack(
        fit: StackFit.expand,
        children: [
          // Composite the rarity plate + transparent ornament foreground when
          // both are provided (ornamented exotics); otherwise the flat icon.
          // A Prismatic subclass's plate is a circle, so on the diamond tile it
          // is scaled up to overflow the diamond's corners (the clip trims the
          // excess); exotic ornament composites keep their 1:1 scale.
          if (plateUrl != null && foregroundUrl != null) ...[
            Transform.scale(
              scale: isSubclass ? _subclassPlateScale : 1,
              child: CachedNetworkImage(
                imageUrl: plateUrl,
                cacheManager: ItemIconCache.instance,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (_, _) => const _IconPlaceholder(),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: ArmoryPalette.scrim26),
              ),
            ),
            Transform.scale(
              scale: isSubclass ? _subclassPlateScale : 1,
              child: CachedNetworkImage(
                imageUrl: foregroundUrl,
                cacheManager: ItemIconCache.instance,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
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
          // Gear-tier diamonds down the top-left (count = tier, tier-coloured),
          // matching the in-game / DIM display. Exotic armor has no tier badge.
          if (showTier && item.showsGearTier)
            Positioned(
              top: 2,
              left: 2,
              child: _TierDiamonds(tier: item.gearTier),
            ),
          // Locked (not-owned) subclass: a dimming scrim with a centre lock, so
          // it reads as unavailable while its art stays recognisable.
          if (isLockedSubclass) ...[
            const DecoratedBox(
              decoration: BoxDecoration(color: ArmoryPalette.scrim35),
            ),
            Center(
              child: Icon(
                Icons.lock,
                size: size * 0.4,
                color: ArmoryPalette.textPrimary.withValues(alpha: 0.7),
                shadows: const [
                  Shadow(color: ArmoryPalette.scrim87, blurRadius: 4),
                ],
              ),
            ),
          ],
        ],
      );

    if (isSubclass) {
      // Clip the icon to a diamond and paint the border along that diamond, so
      // every subclass tile reads as the same rotated-square shape.
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          foregroundPainter:
              DiamondBorderPainter(color: borderColor, width: borderWidth),
          child: ClipPath(
            clipper: const DiamondClipper(),
            child: content,
          ),
        ),
      );
    }

    return AnimatedContainer(
      // Border color/width animate on change, so the green flash fades in when
      // an item is moved and fades out when the highlight clears.
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: ArmoryRadius.sm,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
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

/// Wraps an owned, not-equipped subclass tile in a right-click context menu
/// whose one action equips it (subclasses are equipped by menu/button, not by
/// dragging). Left-click still opens the detail modal via the tile's own tap.
class _SubclassEquipMenu extends ConsumerStatefulWidget {
  const _SubclassEquipMenu({required this.item, required this.child});

  final DestinyItem item;
  final Widget child;

  @override
  ConsumerState<_SubclassEquipMenu> createState() => _SubclassEquipMenuState();
}

class _SubclassEquipMenuState extends ConsumerState<_SubclassEquipMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.check_circle_outline, size: 18),
          onPressed: () =>
              ref.read(moveControllerProvider.notifier).equipSubclass(widget.item),
          child: const Text('Equip'),
        ),
      ],
      child: GestureDetector(
        // Right-click opens the menu at the cursor; left-click passes through to
        // the tile's own onTap (open the modal).
        onSecondaryTapDown: (details) =>
            _controller.open(position: details.localPosition),
        child: widget.child,
      ),
    );
  }
}

/// The gear-tier indicator on an item tile: a vertical column of [tier] small
/// diamonds at the icon's top-left, coloured by tier (grey ≤3, purple 4, gold
/// 5) — matching the in-game / DIM display. A dark outline keeps the diamonds
/// legible over any icon art.
class _TierDiamonds extends StatelessWidget {
  const _TierDiamonds({required this.tier});

  final int tier;

  static const double _size = 5;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final color = ArmoryPalette.tierDiamond(tier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tier; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == tier - 1 ? 0 : _gap),
            child: Transform.rotate(
              angle: 0.785398, // 45° — a square rendered as a diamond
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: ArmoryPalette.scrim87, width: 0.5),
                ),
              ),
            ),
          ),
      ],
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
