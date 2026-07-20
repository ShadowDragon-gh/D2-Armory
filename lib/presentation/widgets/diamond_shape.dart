import 'package:flutter/material.dart';

/// Clips a square icon to a diamond (a square rotated 45°: the four edge
/// midpoints), so subclass icons read as the in-game diamond slot and a
/// rounded plate composite is masked to that shape. Shared by the inventory
/// tile and the subclass modal.
class DiamondClipper extends CustomClipper<Path> {
  const DiamondClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height / 2)
    ..close();

  @override
  bool shouldReclip(covariant DiamondClipper oldClipper) => false;
}

/// Strokes the diamond outline that fits the [DiamondClipper] shape. Inset by
/// half the stroke width so the line sits fully inside the bounds rather than
/// being clipped at the points.
class DiamondBorderPainter extends CustomPainter {
  const DiamondBorderPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final path = Path()
      ..moveTo(size.width / 2, inset)
      ..lineTo(size.width - inset, size.height / 2)
      ..lineTo(size.width / 2, size.height - inset)
      ..lineTo(inset, size.height / 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant DiamondBorderPainter old) =>
      old.color != color || old.width != width;
}
