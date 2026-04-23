import 'package:flutter/material.dart';

import '../models/tool_type.dart';

class CanvasGestureLayer extends StatefulWidget {
  const CanvasGestureLayer({
    super.key,
    required this.activeTool,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onTap,
    required this.onBackgroundTap,
    required this.onHighlightRect,
  });

  final ToolType activeTool;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;
  final VoidCallback onStrokeEnd;
  final ValueChanged<Offset> onTap;
  final VoidCallback onBackgroundTap;
  final ValueChanged<Rect> onHighlightRect;

  @override
  State<CanvasGestureLayer> createState() => _CanvasGestureLayerState();
}

class _CanvasGestureLayerState extends State<CanvasGestureLayer> {
  Offset? _highlightStart;
  Offset? _highlightCurrent;

  Offset _toLocal(Offset position) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(position);
    }
    return position;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (TapDownDetails d) {
        if (widget.activeTool == ToolType.text || widget.activeTool == ToolType.image) {
          widget.onTap(_toLocal(d.globalPosition));
        } else if (widget.activeTool == ToolType.none) {
          widget.onBackgroundTap();
        }
      },
      onPanStart: (DragStartDetails d) {
        if (widget.activeTool == ToolType.draw || widget.activeTool == ToolType.highlight) {
          if (widget.activeTool == ToolType.highlight) {
            _highlightStart = _toLocal(d.globalPosition);
            _highlightCurrent = _highlightStart;
          } else {
            widget.onStrokeStart(_toLocal(d.globalPosition));
          }
        }
      },
      onPanUpdate: (DragUpdateDetails d) {
        if (widget.activeTool == ToolType.draw) {
          widget.onStrokeUpdate(_toLocal(d.globalPosition));
        } else if (widget.activeTool == ToolType.highlight) {
          _highlightCurrent = _toLocal(d.globalPosition);
        }
      },
      onPanEnd: (_) {
        if (widget.activeTool == ToolType.draw) {
          widget.onStrokeEnd();
          return;
        }
        if (widget.activeTool == ToolType.highlight && _highlightStart != null && _highlightCurrent != null) {
          final Offset start = _highlightStart!;
          final Offset end = _highlightCurrent!;
          final Rect rect = Rect.fromLTRB(
            start.dx < end.dx ? start.dx : end.dx,
            start.dy < end.dy ? start.dy : end.dy,
            start.dx < end.dx ? end.dx : start.dx,
            start.dy < end.dy ? end.dy : start.dy,
          );
          _highlightStart = null;
          _highlightCurrent = null;
          if (rect.width > 4 && rect.height > 4) {
            widget.onHighlightRect(rect);
          }
        }
      },
    );
  }
}
