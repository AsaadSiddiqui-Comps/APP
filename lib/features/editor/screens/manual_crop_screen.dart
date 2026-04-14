import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../services/image_edit_service.dart';

class ManualCropScreen extends StatefulWidget {
  const ManualCropScreen({
    super.key,
    required this.imagePath,
    required this.initialRect,
    required this.title,
  });

  final String imagePath;
  final NormalizedCropRect initialRect;
  final String title;

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<ManualCropScreen> {
  late NormalizedCropRect _rect;

  @override
  void initState() {
    super.initState();
    _rect = widget.initialRect.clamped();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color accent = isDark ? const Color(0xFF6E83FF) : AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_rect),
            child: const Text('Apply'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Drag corners to adjust crop area precisely.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Size viewSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final Rect rect = _rect.toRect(viewSize);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        CustomPaint(
                          painter: _CropOverlayPainter(
                            rect: rect,
                            accent: accent,
                          ),
                        ),
                        _cornerHandle(
                          center: rect.topLeft,
                          onDrag: (Offset delta) => _onCornerDrag(
                            corner: _Corner.topLeft,
                            delta: delta,
                            size: viewSize,
                          ),
                          accent: accent,
                        ),
                        _cornerHandle(
                          center: rect.topRight,
                          onDrag: (Offset delta) => _onCornerDrag(
                            corner: _Corner.topRight,
                            delta: delta,
                            size: viewSize,
                          ),
                          accent: accent,
                        ),
                        _cornerHandle(
                          center: rect.bottomLeft,
                          onDrag: (Offset delta) => _onCornerDrag(
                            corner: _Corner.bottomLeft,
                            delta: delta,
                            size: viewSize,
                          ),
                          accent: accent,
                        ),
                        _cornerHandle(
                          center: rect.bottomRight,
                          onDrag: (Offset delta) => _onCornerDrag(
                            corner: _Corner.bottomRight,
                            delta: delta,
                            size: viewSize,
                          ),
                          accent: accent,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerHandle({
    required Offset center,
    required void Function(Offset delta) onDrag,
    required Color accent,
  }) {
    return Positioned(
      left: center.dx - 14,
      top: center.dy - 14,
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails details) => onDrag(details.delta),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: accent, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCornerDrag({
    required _Corner corner,
    required Offset delta,
    required Size size,
  }) {
    final Rect current = _rect.toRect(size);
    const double minSide = 54;

    double left = current.left;
    double top = current.top;
    double right = current.right;
    double bottom = current.bottom;

    switch (corner) {
      case _Corner.topLeft:
        left = (left + delta.dx).clamp(0.0, right - minSide);
        top = (top + delta.dy).clamp(0.0, bottom - minSide);
        break;
      case _Corner.topRight:
        right = (right + delta.dx).clamp(left + minSide, size.width);
        top = (top + delta.dy).clamp(0.0, bottom - minSide);
        break;
      case _Corner.bottomLeft:
        left = (left + delta.dx).clamp(0.0, right - minSide);
        bottom = (bottom + delta.dy).clamp(top + minSide, size.height);
        break;
      case _Corner.bottomRight:
        right = (right + delta.dx).clamp(left + minSide, size.width);
        bottom = (bottom + delta.dy).clamp(top + minSide, size.height);
        break;
    }

    final Rect next = Rect.fromLTRB(left, top, right, bottom);
    setState(() {
      _rect = NormalizedCropRect.fromRect(next, size);
    });
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.rect, required this.accent});

  final Rect rect;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint shade = Paint()..color = const Color(0x99000000);
    final Path full = Path()..addRect(Offset.zero & size);
    final Path hole = Path()..addRect(rect);
    final Path shaded = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(shaded, shade);

    final Paint border = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.accent != accent;
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }
