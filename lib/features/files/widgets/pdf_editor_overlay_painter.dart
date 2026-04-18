import 'package:flutter/material.dart';

import '../models/pdf_edit_models.dart';

/// Custom painter for rendering PDF editor overlays (strokes, text)
class PdfEditorOverlayPainter extends CustomPainter {
  PdfEditorOverlayPainter({
    required this.strokes,
    required this.activeStroke,
    required this.activeStrokeColor,
    required this.activeStrokeWidth,
    required this.activeStrokeOpacity,
    required this.textItems,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<StrokePath> strokes;
  final List<Offset> activeStroke;
  final Color activeStrokeColor;
  final double activeStrokeWidth;
  final double activeStrokeOpacity;
  final List<TextOverlay> textItems;

  @override
  void paint(Canvas canvas, Size size) {
    // Paint all completed strokes
    for (final StrokePath stroke in strokes) {
      _drawStroke(
        canvas,
        stroke.points,
        stroke.color,
        stroke.width,
        stroke.opacity,
      );
    }

    // Paint the active (in-progress) stroke
    if (activeStroke.length > 1) {
      _drawStroke(
        canvas,
        activeStroke,
        activeStrokeColor,
        activeStrokeWidth,
        activeStrokeOpacity,
      );
    }

    // Paint all text overlays
    for (final TextOverlay item in textItems) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.textColor,
            fontSize: item.fontSize,
            fontFamily: item.fontFamily,
            backgroundColor: item.backgroundColor,
            height: 1.24,
          ),
        ),
        textAlign: item.textAlign,
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: size.width * 0.76);

      painter.paint(canvas, item.position);
    }
  }

  /// Draws a single stroke path using smooth Bezier curves
  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
    double opacity,
  ) {
    if (points.length < 2) {
      return;
    }

    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i += 1) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PdfEditorOverlayPainter oldDelegate) {
    // Always repaint for smooth stroke rendering
    // Consider optimizing by comparing strokes/textItems if performance is needed
    return true;
  }

  @override
  bool shouldRebuildSemantics(covariant PdfEditorOverlayPainter oldDelegate) {
    return false;
  }
}
