import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/destiny/destiny_buckets.dart';
import '../../../core/destiny/destiny_enums.dart';
import '../../../core/destiny/plug_category.dart';
import '../../../domain/models/item_detail.dart';
import '../../providers/inventory_provider.dart';

/// Wraps [ItemDetailPanel] with a slide animation. Designed to be placed on
/// the right edge of a [Stack] as an overlay over the grid, so opening/closing
/// never resizes the grid (no reflow jank). The panel slides in from / out to
/// the right edge; the last-shown detail is retained during the closing slide.
class AnimatedItemDetailPanel extends ConsumerStatefulWidget {
  const AnimatedItemDetailPanel({super.key});

  @override
  ConsumerState<AnimatedItemDetailPanel> createState() =>
      _AnimatedItemDetailPanelState();
}

class _AnimatedItemDetailPanelState
    extends ConsumerState<AnimatedItemDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  ItemDetail? _lastDetail;

  @override
  void initState() {
    super.initState();
    // Reflect any already-selected item on first mount (e.g. returning to the
    // Inventory tab); ref.listen only fires on subsequent changes.
    final detail = ref.read(selectedItemDetailProvider);
    if (detail != null) {
      _lastDetail = detail;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Drive the open/close animation from provider changes (not inside the
    // build itself, which must stay side-effect free).
    ref.listen(selectedItemDetailProvider, (_, detail) {
      if (detail != null) {
        setState(() => _lastDetail = detail); // retain for the slide-out
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final t = _curve.value;
        if (t == 0 || _lastDetail == null) return const SizedBox.shrink();
        // Fixed-width panel that slides in from / out to the right edge. As a
        // Stack overlay it never affects the grid's layout, so there is no
        // reflow while it animates.
        return FractionalTranslation(
          translation: Offset(1 - t, 0), // t=0 → fully off-screen to the right
          child: SizedBox(
            width: ItemDetailPanel.width,
            child: Row(
              children: [
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: ItemDetailPanel(detail: _lastDetail!)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fixed-width detail panel shown on the right when an item is selected. Its
/// open/close slide animation is owned by [AnimatedItemDetailPanel]; this
/// widget just renders the given [detail].
class ItemDetailPanel extends StatelessWidget {
  const ItemDetailPanel({super.key, required this.detail});

  static const double width = 340;

  final ItemDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(detail: detail),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (detail.stats.isNotEmpty) ...[
                    _StatBlock(stats: detail.stats),
                    const SizedBox(height: 16),
                  ],
                  _PlugSection(
                      title: 'Frame',
                      plugs: detail.plugsOf(PlugCategory.frame).toList()),
                  if (detail.breaker != null)
                    _BreakerSection(breaker: detail.breaker!),
                  _PlugSection(
                      title: 'Perks',
                      plugs: detail.plugsOf(PlugCategory.perk).toList()),
                  _PlugSection(
                      title: 'Mods',
                      plugs: detail.plugsOf(PlugCategory.mod).toList()),
                  _PlugSection(
                      title: 'Masterwork',
                      plugs:
                          detail.plugsOf(PlugCategory.masterwork).toList()),
                  _PlugSection(
                      title: 'Cosmetic',
                      plugs: detail.plugsOf(PlugCategory.cosmetic).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.detail});

  final ItemDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = detail.item;
    final subtitleParts = <String>[
      if (item.itemTypeDisplayName.isNotEmpty) item.itemTypeDisplayName,
      if (DestinyEnums.rarityName(item.tierType) != null)
        DestinyEnums.rarityName(item.tierType)!,
      if (DestinyEnums.ammoName(item.ammoType) != null)
        DestinyEnums.ammoName(item.ammoType)!,
    ];
    final damageName =
        item.damageType == null ? null : DamageType.name(item.damageType!);
    final damageColor =
        item.damageType == null ? null : DamageType.color(item.damageType!);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(selectedItemProvider.notifier).clear(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitleParts.join(' · '),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              if (detail.killTracker != null)
                _KillTrackerBadge(tracker: detail.killTracker!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.elementIconUrl != null && damageColor != null) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CachedNetworkImage(
                    imageUrl: item.elementIconUrl!,
                    color: damageColor,
                    colorBlendMode: BlendMode.srcIn,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(damageName ?? '',
                    style: TextStyle(color: damageColor, fontSize: 13)),
                const Spacer(),
              ] else
                const Spacer(),
              if (item.power != null)
                Text(
                  '${item.power}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The masterwork kill-tracker icon and count, shown in the panel header.
class _KillTrackerBadge extends StatelessWidget {
  const _KillTrackerBadge({required this.tracker});

  final KillTracker tracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tracker.iconUrl != null)
          SizedBox(
            width: 16,
            height: 16,
            child: CachedNetworkImage(
              imageUrl: tracker.iconUrl!,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          _formatCount(tracker.count),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  static String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.stats});

  final List<ItemStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(stat.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 30,
                  child: Text('${stat.value}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right),
                ),
                const SizedBox(width: 8),
                // Numeric stats show just the number; recoil direction shows a
                // gauge; the rest render a bar against a fixed max of 100.
                Expanded(
                  child: switch (stat.display) {
                    StatDisplay.numeric => const SizedBox.shrink(),
                    StatDisplay.recoil => Align(
                        alignment: Alignment.centerLeft,
                        child: _RecoilGauge(value: stat.value),
                      ),
                    StatDisplay.bar => ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (stat.value / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Recoil-direction gauge: a filled wedge inside a circle showing the recoil's
/// direction and spread, derived from the single 0-100 value using DIM's
/// formula. A higher value is narrower/more vertical; near 100 it renders as a
/// straight vertical line (fixed recoil).
class _RecoilGauge extends StatelessWidget {
  const _RecoilGauge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Box is the semicircle's bounds (2r x r); the painter clips to it so
      // only the top half of the circle shows. The Row centres it vertically.
      size: const Size(22, 11),
      painter: _RecoilPainter(
        value: value.clamp(0, 100).toDouble(),
        color: Colors.white,
        trackColor: const Color(0xFF333333),
      ),
    );
  }
}

class _RecoilPainter extends CustomPainter {
  _RecoilPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  // A value from 100 to -100 where positive is right, negative left, 0 = up.
  // Ported verbatim from DIM's RecoilStat.
  static double _recoilDirection(double v) =>
      math.sin((v + 5) * (math.pi / 10)) * (100 - v);

  static const double _verticalScale = 0.8;
  static const double _maxSpread = 180; // degrees

  @override
  void paint(Canvas canvas, Size size) {
    // DIM draws a full circle in a 2x1 viewBox that shows only the top half.
    // Clip to the box so the bottom half of the circle/wedge is hidden, giving
    // a true semicircle with its flat side on the bottom edge.
    canvas.clipRect(Offset.zero & size);
    final r = size.width / 2;
    final center = Offset(size.width / 2, size.height);
    Offset pt(double ux, double uy) =>
        Offset(center.dx + ux * r, center.dy - uy * r);

    canvas.drawCircle(center, r, Paint()..color = trackColor);

    final direction =
        _recoilDirection(value) * _verticalScale * (math.pi / 180);
    final fill = Paint()..color = color;

    if (value >= 95) {
      // Essentially fixed/vertical recoil: a straight line through the centre.
      final x = math.sin(direction), y = math.cos(direction);
      canvas.drawLine(
        pt(-x, -y),
        pt(x, y),
        Paint()
          ..color = color
          ..strokeWidth = r * 0.1
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    // Filled wedge from the centre spanning direction ± spread.
    final spread = ((100 - value) / 100) *
        (_maxSpread / 2) *
        (math.pi / 180) *
        (direction < 0 ? -1 : 1);
    final more = pt(math.sin(direction + spread), math.cos(direction + spread));
    final less = pt(math.sin(direction - spread), math.cos(direction - spread));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(more.dx, more.dy)
      ..arcToPoint(less, radius: Radius.circular(r), clockwise: direction < 0)
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_RecoilPainter old) =>
      old.value != value || old.color != color;
}

class _PlugSection extends StatelessWidget {
  const _PlugSection({required this.title, required this.plugs});

  final String title;
  final List<ItemPlug> plugs;

  @override
  Widget build(BuildContext context) {
    if (plugs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        for (final plug in plugs)
          _Row(
            iconUrl: plug.iconUrl,
            name: plug.name,
            description: plug.description,
            dim: !plug.isEnabled,
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _BreakerSection extends StatelessWidget {
  const _BreakerSection({required this.breaker});

  final BreakerType breaker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Breaker'),
        _Row(iconUrl: breaker.iconUrl, name: breaker.name, description: ''),
        const SizedBox(height: 12),
      ],
    );
  }
}


class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.iconUrl,
    required this.name,
    required this.description,
    this.dim = false,
  });

  final String? iconUrl;
  final String name;
  final String description;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: iconUrl == null
                  ? const SizedBox.shrink()
                  : CachedNetworkImage(
                      imageUrl: iconUrl!,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
