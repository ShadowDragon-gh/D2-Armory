import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/armory_palette.dart';

/// The Destiny class mark (Titan / Hunter / Warlock), drawn as a vector so no
/// assets or network are needed. [classType] follows DestinyClass:
/// 0 = Titan, 1 = Hunter, 2 = Warlock.
class ClassEmblem extends StatelessWidget {
  const ClassEmblem({
    super.key,
    required this.classType,
    this.size = 20,
    this.color = ArmoryPalette.textPrimary,
  });

  final int classType;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final painter = switch (classType) {
      0 => _TitanMark(color),
      1 => _HunterMark(color),
      2 => _WarlockMark(color),
      _ => null,
    };
    if (painter == null) {
      return Icon(Icons.shield, size: size, color: color);
    }
    return CustomPaint(size: Size.square(size), painter: painter);
  }
}

/// Titan: a hexagon divided into four wedges by an X, with thin gaps between
/// the wedges. Drawn as four filled triangles around the centre.
class _TitanMark extends CustomPainter {
  _TitanMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // Cutouts must be transparent (the mark sits over emblem art): draw the
    // hexagon into a layer, then erase the diagonal lines out of it.
    canvas.saveLayer(Offset.zero & size, Paint());

    // Rotate 90° about the centre so the hexagon has flat top/bottom edges
    // (points at top and bottom) rather than pointing left/right.
    canvas.translate(w / 2, h / 2);
    canvas.rotate(1.5707963267948966); // 90 degrees
    canvas.translate(-w / 2, -h / 2);

    // Hexagon pointed left/right, with flat-ish top and bottom edges.
    final topLeft = p(0.28, 0.10);
    final topRight = p(0.72, 0.10);
    final right = p(0.97, 0.50);
    final botRight = p(0.72, 0.90);
    final botLeft = p(0.28, 0.90);
    final left = p(0.03, 0.50);

    final hex = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(hex, Paint()..color = color);

    // Diagonal cutouts forming the X: the two top corners run to the opposite
    // bottom corners, crossing at the centre.
    final slit = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.05).clamp(1.0, double.infinity);
    canvas.drawLine(topLeft, botRight, slit);
    canvas.drawLine(topRight, botLeft, slit);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TitanMark old) => old.color != color;
}

/// Hunter: three stacked up-pointing chevrons. Each is a triangle with a
/// notch cut up from its base, and each lower chevron's peak nests into the
/// white notch of the one above. The middle band is the widest; the bottom
/// legs are steeper and narrower, with the white V widening downward.
class _HunterMark extends CustomPainter {
  _HunterMark(this.color);
  final Color color;

  // Leg angle from vertical, shared by every chevron so all legs are at the
  // same angle. Band thickness and the flat-top half-width are also shared.
  static const double _legAngle = 0.65; // radians (~28.6°)
  static const double _thick = 0.18;
  static const double _flatHalf = 0.175;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = color;
    final slope = math.tan(_legAngle); // dx per unit dy
    final norm = math.sqrt(slope * slope + 1);
    // Inward normal of the right leg (points toward the axis).
    final nx = -1 / norm, ny = slope / norm;

    // A chevron band with a flat top AND flat bottom: outer outline is a short
    // horizontal segment at [topY] with legs splaying down to [bottomY]; the
    // inner edge runs parallel, offset inward by [_thick], and both the top and
    // bottom of the band are cut horizontally. All legs share [slope], so every
    // chevron sits at the same angle.
    void chevron(double topY, double bottomY) {
      final dy = bottomY - topY;
      final outHalf = _flatHalf + slope * dy;
      // Inner outline: each leg offset inward by _thick (perpendicular). The
      // inner leg is the line through (outer-corner + _thick*normal) parallel
      // to the outer leg. Find where it meets y=topY (inner top) and y=bottomY
      // (inner base), giving flat top and flat bottom edges on the notch.
      final orbx = 0.5 + outHalf; // outer base-right x (at bottomY)
      // A point on the inner right leg:
      final ipx = orbx + _thick * nx, ipy = bottomY + _thick * ny;
      // Inner right leg direction is (slope, 1); solve x at given y.
      double innerRightX(double y) => ipx + (y - ipy) * slope;
      final innerTopRightX = innerRightX(topY);
      final innerBottomRightX = innerRightX(bottomY);

      // Solid Λ band: outer outline down the right leg and up the left leg,
      // with the notch (inner outline) carved out — flat at top and bottom.
      final path = Path()
        ..moveTo(w * (0.5 - _flatHalf), h * topY) // outer flat top-left
        ..lineTo(w * (0.5 + _flatHalf), h * topY) // outer flat top-right
        ..lineTo(w * orbx, h * bottomY) // outer base-right
        ..lineTo(w * innerBottomRightX, h * bottomY) // inner base-right
        ..lineTo(w * innerTopRightX, h * topY) // inner top-right
        ..lineTo(w * (1 - innerTopRightX), h * topY) // inner top-left
        ..lineTo(w * (1 - innerBottomRightX), h * bottomY) // inner base-left
        ..lineTo(w * (0.5 - outHalf), h * bottomY) // outer base-left
        ..close();
      canvas.drawPath(path, paint);
    }

    // Three identical chevrons, each shifted down by a uniform step.
    const chevronHeight = 0.30;
    const step = 0.28;
    const firstTop = 0.06;
    for (var i = 0; i < 3; i++) {
      final top = firstTop + i * step;
      chevron(top, top + chevronHeight);
    }
  }

  @override
  bool shouldRepaint(_HunterMark old) => old.color != color;
}

/// Warlock: a single three-peaked silhouette with thin cutout lines extending
/// from the outer peak tips through the body. The two lines cross at the lower
/// middle, dividing the mark into two legs, a central kite (the middle peak,
/// pinched to a point at the crossing) and a small bottom-centre triangle.
class _WarlockMark extends CustomPainter {
  _WarlockMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // The mark is drawn slightly shorter than the box: peaks at 0.16, base at
    // 0.84, leaving vertical breathing room.
    const t = 0.16, b = 0.84;

    // Cutouts must be transparent (the mark sits over emblem art), so the
    // silhouette is drawn into a layer and the lines erased out of it.
    canvas.saveLayer(Offset.zero & size, Paint());

    // Three-peaked silhouette: baseline, left peak, V-notch, centre peak,
    // V-notch, right peak.
    final silhouette = Path()
      ..moveTo(p(0.02, b).dx, p(0.02, b).dy)
      ..lineTo(p(0.28, t).dx, p(0.28, t).dy) // left apex
      ..lineTo(p(0.41, 0.40).dx, p(0.41, 0.40).dy) // notch bottom
      ..lineTo(p(0.50, t).dx, p(0.50, t).dy) // centre apex
      ..lineTo(p(0.59, 0.40).dx, p(0.59, 0.40).dy) // notch bottom
      ..lineTo(p(0.72, t).dx, p(0.72, t).dy) // right apex
      ..lineTo(p(0.98, b).dx, p(0.98, b).dy)
      ..close();
    canvas.drawPath(silhouette, Paint()..color = color);

    final slit = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.05).clamp(1.0, double.infinity);
    // Cutout lines from the two outer apexes, crossing near the lower middle.
    canvas.drawLine(p(0.28, t), p(0.62, b), slit); // left apex → down-right
    canvas.drawLine(p(0.72, t), p(0.38, b), slit); // right apex → down-left
    // Cutout lines from the centre apex fanning down-left and down-right,
    // carving the bottom-centre triangle away from the legs.
    canvas.drawLine(p(0.50, t), p(0.22, b), slit); // centre apex → down-left
    canvas.drawLine(p(0.50, t), p(0.78, b), slit); // centre apex → down-right

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WarlockMark old) => old.color != color;
}
