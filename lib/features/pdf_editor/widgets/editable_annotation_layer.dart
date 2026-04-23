import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../models/pdf_edit_operation.dart';

class EditableAnnotationLayer extends StatelessWidget {
  const EditableAnnotationLayer({
    super.key,
    required this.controller,
    required this.page,
    required this.selectedOperationId,
    required this.revision,
  });

  final EditorController controller;
  final int page;
  final String? selectedOperationId;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final List<PdfEditOperation> pageOperations = controller.operationsForPage(page)
        .whereType<PdfEditOperation>()
        .where((PdfEditOperation op) => op is PdfTextOperation || op is PdfImageOperation)
        .toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final PdfEditOperation operation in pageOperations)
          if (operation is PdfTextOperation)
            _EditableTextItem(
              key: ValueKey<String>(operation.id),
              operation: operation,
              selected: selectedOperationId == operation.id,
              onSelect: () => controller.selectOperation(operation.id),
              onMove: (Offset delta) => unawaited(controller.moveSelectedOperation(delta)),
              onResize: (Offset delta) => unawaited(controller.resizeSelectedOperation(delta, fromImage: false)),
              onDelete: () => unawaited(controller.deleteSelectedOperation()),
              revision: revision,
            )
          else if (operation is PdfImageOperation)
            _EditableImageItem(
              key: ValueKey<String>(operation.id),
              operation: operation,
              selected: selectedOperationId == operation.id,
              onSelect: () => controller.selectOperation(operation.id),
              onMove: (Offset delta) => unawaited(controller.moveSelectedOperation(delta)),
              onResize: (Offset delta) => unawaited(controller.resizeSelectedOperation(delta, fromImage: true)),
              onDelete: () => unawaited(controller.deleteSelectedOperation()),
              revision: revision,
            ),
      ],
    );
  }
}

class _EditableTextItem extends StatelessWidget {
  const _EditableTextItem({
    super.key,
    required this.operation,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
    required this.onDelete,
    required this.revision,
  });

  final PdfTextOperation operation;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;
  final VoidCallback onDelete;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final Size size = _measureText(operation.text, operation.fontSize);
    final Color borderColor = selected ? Theme.of(context).colorScheme.primary : Colors.transparent;

    return Positioned(
      left: operation.position.dx,
      top: operation.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onSelect,
        onPanStart: (_) => onSelect(),
        onPanUpdate: (DragUpdateDetails details) => onMove(details.delta),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size.width,
              height: size.height,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                border: Border.all(color: borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                operation.text,
                style: TextStyle(
                  color: operation.color,
                  fontSize: operation.fontSize,
                  height: 1.15,
                ),
              ),
            ),
            if (selected) ..._handles(
              context: context,
              size: size,
              onResize: onResize,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableImageItem extends StatelessWidget {
  const _EditableImageItem({
    super.key,
    required this.operation,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
    required this.onDelete,
    required this.revision,
  });

  final PdfImageOperation operation;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;
  final VoidCallback onDelete;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected ? Theme.of(context).colorScheme.primary : Colors.transparent;

    return Positioned(
      left: operation.position.dx,
      top: operation.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onSelect,
        onPanStart: (_) => onSelect(),
        onPanUpdate: (DragUpdateDetails details) => onMove(details.delta),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: operation.size.width,
              height: operation.size.height,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.02),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(operation.path),
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
            if (selected) ..._handles(
              context: context,
              size: operation.size,
              onResize: onResize,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _handles({
  required BuildContext context,
  required Size size,
  required ValueChanged<Offset> onResize,
  required VoidCallback onDelete,
}) {
  final Color handleColor = Theme.of(context).colorScheme.primary;
  return <Widget>[
    _CornerHandle(
      left: -8,
      top: -8,
      color: handleColor,
      icon: Icons.close_rounded,
      onTap: onDelete,
    ),
    _CornerDragHandle(left: -8, top: -8, onDrag: (Offset delta) => onResize(Offset(-delta.dx, -delta.dy))),
    _CornerDragHandle(left: size.width - 6, top: -8, onDrag: (Offset delta) => onResize(Offset(delta.dx, -delta.dy))),
    _CornerDragHandle(left: -8, top: size.height - 6, onDrag: (Offset delta) => onResize(Offset(-delta.dx, delta.dy))),
    _CornerDragHandle(left: size.width - 6, top: size.height - 6, onDrag: onResize),
  ];
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle({required this.left, required this.top, required this.color, required this.icon, required this.onTap});

  final double left;
  final double top;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _CornerDragHandle extends StatefulWidget {
  const _CornerDragHandle({required this.left, required this.top, required this.onDrag});

  final double left;
  final double top;
  final ValueChanged<Offset> onDrag;

  @override
  State<_CornerDragHandle> createState() => _CornerDragHandleState();
}

class _CornerDragHandleState extends State<_CornerDragHandle> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left,
      top: widget.top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (DragUpdateDetails details) => widget.onDrag(details.delta),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: const Icon(Icons.open_in_full_rounded, size: 11, color: Colors.white),
        ),
      ),
    );
  }
}

Size _measureText(String text, double fontSize) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, height: 1.15),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 6,
  )..layout(maxWidth: 280);
  return Size(math.max(painter.width + 12, 40), math.max(painter.height + 12, fontSize + 16));
}