import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/destiny/destiny_buckets.dart';
import '../../domain/models/destiny_item.dart';
import '../providers/inventory_provider.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/armory_palette.dart';

/// A single inventory item: the icon square with a footer row beneath it
/// showing the element glyph and power level (so neither covers the art).
/// Equipped items get a gold outline; masterworked items get a subtle gold
/// border and a translucent gold gradient rising from the bottom. Dimmed when
/// an active search filter excludes it.
class ItemTile extends ConsumerWidget {
  const ItemTile({super.key, required this.item, this.size = 52});

  final DestinyItem item;

  /// Size of the icon square. The footer row adds a little height below it.
  final double size;

  static const double _footerHeight = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(compiledQueryProvider);
    final dimmed = !query.isEmpty && !query.matches(item);
    final selected = identical(ref.watch(selectedItemProvider), item);
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

    return AnimatedOpacity(
      opacity: dimmed ? 0.2 : 1,
      duration: const Duration(milliseconds: 120),
      child: Tooltip(
        message:
            item.power != null ? '${item.name} · ${item.power}' : item.name,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => ref.read(selectedItemProvider.notifier).toggle(item),
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
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => const ColoredBox(color: ArmoryPalette.scrim26),
            ),
            CachedNetworkImage(
              imageUrl: foregroundUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ] else if (iconUrl == null)
            const ColoredBox(color: ArmoryPalette.scrim26)
          else
            CachedNetworkImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
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
