import 'package:flutter/material.dart';

import '../models/editor_state.dart';
import '../models/tool_type.dart';

class ToolConfigPanel extends StatelessWidget {
  const ToolConfigPanel({
    super.key,
    required this.state,
    required this.onStrokeWidthChanged,
    required this.onStrokeColorChanged,
    required this.onHighlightColorChanged,
    required this.onHighlightOpacityChanged,
    required this.onTextColorChanged,
    required this.onTextSizeChanged,
  });

  final EditorState state;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<Color> onStrokeColorChanged;
  final ValueChanged<Color> onHighlightColorChanged;
  final ValueChanged<double> onHighlightOpacityChanged;
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<double> onTextSizeChanged;

  @override
  Widget build(BuildContext context) {
    if (state.activeTool == ToolType.none || state.activeTool == ToolType.addPage) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: switch (state.activeTool) {
        ToolType.draw => _drawPanel(),
        ToolType.highlight => _highlightPanel(),
        ToolType.text => _textPanel(),
        ToolType.image => const Text('Tap on page to place image', style: TextStyle(fontWeight: FontWeight.w600)),
        ToolType.none || ToolType.addPage => const SizedBox.shrink(),
      },
    );
  }

  Widget _drawPanel() {
    return Row(
      children: [
        const Text('Brush'),
        Expanded(
          child: Slider(
            value: state.strokeWidth,
            min: 1,
            max: 12,
            onChanged: onStrokeWidthChanged,
          ),
        ),
        _colorDot(state.strokeColor, onStrokeColorChanged),
      ],
    );
  }

  Widget _highlightPanel() {
    return Row(
      children: [
        const Text('Opacity'),
        Expanded(
          child: Slider(
            value: state.highlightOpacity,
            min: 0.1,
            max: 0.8,
            onChanged: onHighlightOpacityChanged,
          ),
        ),
        _colorDot(state.highlightColor, onHighlightColorChanged),
      ],
    );
  }

  Widget _textPanel() {
    return Row(
      children: [
        const Text('Size'),
        Expanded(
          child: Slider(
            value: state.textSize,
            min: 12,
            max: 40,
            onChanged: onTextSizeChanged,
          ),
        ),
        _colorDot(state.textColor, onTextColorChanged),
      ],
    );
  }

  Widget _colorDot(Color selected, ValueChanged<Color> onChanged) {
    const List<Color> palette = <Color>[
      Color(0xFF212121),
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
      Color(0xFFFFEB3B),
    ];

    return Wrap(
      spacing: 6,
      children: palette
          .map(
            (Color c) => InkWell(
              onTap: () => onChanged(c),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == c ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
