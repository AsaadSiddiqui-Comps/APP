import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/services/native_drawing_service.dart';
import '../models/pdf_edit_models.dart';
import 'pdf_editor_overlay_painter.dart';

/// High-performance native-accelerated drawing widget for PDF annotations.
/// Falls back to Dart rendering if native layer unavailable.
class NativeAcceleratedDrawingCanvas extends StatefulWidget {
  const NativeAcceleratedDrawingCanvas({
    super.key,
    required this.strokes,
    required this.textItems,
    required this.activeStroke,
    required this.activeStrokeColor,
    required this.activeStrokeWidth,
    required this.activeStrokeOpacity,
    required this.onDrawComplete,
    required this.repaint,
  });

  final List<StrokePath> strokes;
  final List<TextOverlay> textItems;
  final List<Offset> activeStroke;
  final Color activeStrokeColor;
  final double activeStrokeWidth;
  final double activeStrokeOpacity;
  final VoidCallback onDrawComplete;
  final Listenable repaint;

  @override
  State<NativeAcceleratedDrawingCanvas> createState() =>
      _NativeAcceleratedDrawingCanvasState();
}

class _NativeAcceleratedDrawingCanvasState
    extends State<NativeAcceleratedDrawingCanvas> {
  bool _useNativeRenderer = false;
  Uint8List? _nativeRenderedImage;
  bool _isNativeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeNativeRenderer();
  }

  Future<void> _initializeNativeRenderer() async {
    try {
      // Native availability check. Actual context init happens after layout.
      _useNativeRenderer = true;
      _isNativeInitialized = false;
    } catch (e) {
      // Fall back to Dart rendering.
      _useNativeRenderer = false;
      _isNativeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(NativeAcceleratedDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync native renderer with Dart state changes if applicable
    if (_useNativeRenderer && widget.strokes != oldWidget.strokes) {
      _syncNativeRenderer();
    }
  }

  Future<void> _syncNativeRenderer() async {
    // Compare strokes and sync only what changed
    // This is an optimization to avoid re-rendering entire canvas
    try {
      final count = await NativeDrawingService.getStrokeCount();
      if (count != widget.strokes.length) {
        // Full resync needed
        await NativeDrawingService.clearBuffer();
        for (final stroke in widget.strokes) {
          final flatPoints = <double>[];
          for (final point in stroke.points) {
            flatPoints.addAll([point.dx, point.dy]);
          }
          await NativeDrawingService.drawStroke(
            flatPoints: flatPoints,
            colorARGB: stroke.color.toARGB32(),
            strokeWidth: stroke.width,
            opacity: stroke.opacity,
          );
        }
      }

      final Uint8List? png = await NativeDrawingService.renderToPNG();
      if (mounted) {
        setState(() {
          _nativeRenderedImage = png;
        });
      } else {
        _nativeRenderedImage = png;
      }
    } catch (e) {
      debugPrint('Error syncing native renderer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Initialize native context on first layout with known size
        if (_useNativeRenderer &&
            !_isNativeInitialized &&
            constraints.maxWidth.isFinite &&
            constraints.maxHeight.isFinite) {
          _initNativeContextWithSize(
            constraints.maxWidth.toInt(),
            constraints.maxHeight.toInt(),
          );
        }

        return CustomPaint(
          painter: _useNativeRenderer
              ? NativeDrawingCanvasPainter(
                  textItems: widget.textItems,
                  activeStroke: widget.activeStroke,
                  activeStrokeColor: widget.activeStrokeColor,
                  activeStrokeWidth: widget.activeStrokeWidth,
                  activeStrokeOpacity: widget.activeStrokeOpacity,
                  repaint: widget.repaint,
                )
              : PdfEditorOverlayPainter(
                  strokes: widget.strokes,
                  activeStroke: widget.activeStroke,
                  activeStrokeColor: widget.activeStrokeColor,
                  activeStrokeWidth: widget.activeStrokeWidth,
                  activeStrokeOpacity: widget.activeStrokeOpacity,
                  textItems: widget.textItems,
                  repaint: widget.repaint,
                ),
          child: _useNativeRenderer
              ? Stack(
                  children: [
                    if (_nativeRenderedImage != null)
                      Positioned.fill(
                        child: Image.memory(
                          _nativeRenderedImage!,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    const SizedBox.expand(),
                  ],
                )
              : const SizedBox.expand(),
        );
      },
    );
  }

  void _initNativeContextWithSize(int width, int height) async {
    final initialized = await NativeDrawingService.initializeDrawingContext(
      width: width,
      height: height,
    );

    if (initialized) {
      _useNativeRenderer = true;
      _isNativeInitialized = true;
      // Pre-render all current strokes
      await _syncNativeRenderer();
    } else {
      _useNativeRenderer = false;
      _isNativeInitialized = true;
    }

    if (mounted) {
      setState(() {});
    }
  }
}

/// Painter that renders using native-accelerated image and text overlays
class NativeDrawingCanvasPainter extends CustomPainter {
  NativeDrawingCanvasPainter({
    required this.textItems,
    required this.activeStroke,
    required this.activeStrokeColor,
    required this.activeStrokeWidth,
    required this.activeStrokeOpacity,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<TextOverlay> textItems;
  final List<Offset> activeStroke;
  final Color activeStrokeColor;
  final double activeStrokeWidth;
  final double activeStrokeOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw active (in-progress) stroke
    if (activeStroke.length > 1) {
      _drawStroke(
        canvas,
        activeStroke,
        activeStrokeColor,
        activeStrokeWidth,
        activeStrokeOpacity,
      );
    }

    // Draw text overlays
    for (final item in textItems) {
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

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
    double opacity,
  ) {
    if (points.length < 2) return;

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
  bool shouldRepaint(covariant NativeDrawingCanvasPainter oldDelegate) {
    return textItems != oldDelegate.textItems ||
        activeStroke != oldDelegate.activeStroke;
  }

  @override
  bool shouldRebuildSemantics(covariant NativeDrawingCanvasPainter oldDelegate) {
    return false;
  }
}
