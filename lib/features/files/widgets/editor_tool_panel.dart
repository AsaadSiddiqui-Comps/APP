import 'package:flutter/material.dart';

import '../models/pdf_edit_models.dart';

/// Builds the active tool configuration panel (bottom sheet)
class EditorToolPanel {
  /// Builds highlighter tool UI panel
  static Widget buildHighlighterPanel({
    required HighlightMode highlightMode,
    required Color highlightColor,
    required double highlightOpacity,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onOpacityChanged,
    required ValueChanged<HighlightMode> onModeChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Highlight', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: editorPalette
              .map(
                (Color color) => _colorDot(
                  color: color,
                  selected: highlightColor == color,
                  onTap: () => onColorChanged(color),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Opacity'),
            Expanded(
              child: Slider(
                value: highlightOpacity,
                min: 0.1,
                max: 1,
                onChanged: onOpacityChanged,
              ),
            ),
            SizedBox(
              width: 42,
              child: Text('${(highlightOpacity * 100).round()}%'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HighlightMode.values
                .map(
                  (HighlightMode mode) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mode.label),
                      selected: highlightMode == mode,
                      onSelected: (_) => onModeChanged(mode),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  /// Builds draw tool UI panel
  static Widget buildDrawPanel({
    required DrawMode drawMode,
    required Color drawColor,
    required double drawWidth,
    required double drawOpacity,
    required double eraserSize,
    required ValueChanged<DrawMode> onModeChanged,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onWidthChanged,
    required ValueChanged<double> onOpacityChanged,
    required ValueChanged<double> onEraserSizeChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Draw', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Pen'),
              selected: drawMode == DrawMode.pen,
              onSelected: (_) => onModeChanged(DrawMode.pen),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Eraser'),
              selected: drawMode == DrawMode.eraser,
              onSelected: (_) => onModeChanged(DrawMode.eraser),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (drawMode == DrawMode.pen) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: editorPalette
                .map(
                  (Color color) => _colorDot(
                    color: color,
                    selected: drawColor == color,
                    onTap: () => onColorChanged(color),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Brush Width'),
              Expanded(
                child: Slider(
                  value: drawWidth,
                  min: 1,
                  max: 14,
                  onChanged: onWidthChanged,
                ),
              ),
              SizedBox(width: 34, child: Text(drawWidth.toStringAsFixed(0))),
            ],
          ),
          Row(
            children: [
              const Text('Opacity'),
              Expanded(
                child: Slider(
                  value: drawOpacity,
                  min: 0.1,
                  max: 1,
                  onChanged: onOpacityChanged,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text('${(drawOpacity * 100).round()}%'),
              ),
            ],
          ),
        ] else ...[
          const Text('Drag over strokes to erase selected portions.'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Eraser Size'),
              Expanded(
                child: Slider(
                  value: eraserSize,
                  min: 6,
                  max: 80,
                  onChanged: onEraserSizeChanged,
                ),
              ),
              SizedBox(width: 34, child: Text(eraserSize.toStringAsFixed(0))),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds text tool UI panel
  static Widget buildTextPanel({
    required Color textColor,
    required Color textBackground,
    required String textFont,
    required double textSize,
    required TextAlign textAlign,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<Color> onBackgroundChanged,
    required ValueChanged<String> onFontChanged,
    required ValueChanged<double> onSizeChanged,
    required ValueChanged<TextAlign> onAlignChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Text', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Tap anywhere on document to place text'),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 64, child: Text('Color')),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: editorPalette
                    .map(
                      (Color color) => _colorDot(
                        color: color,
                        selected: textColor == color,
                        onTap: () => onColorChanged(color),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 64, child: Text('Background')),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: textBackgroundColors
                    .map(
                      (Color color) => _colorDot(
                        color: color,
                        selected: textBackground == color,
                        onTap: () => onBackgroundChanged(color),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 64, child: Text('Font')),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: textFont,
                items: textFontOptions
                    .map(
                      (String font) => DropdownMenuItem<String>(
                        value: font,
                        child: Text(font),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) {
                    onFontChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 64, child: Text('Size')),
            Expanded(
              child: Slider(
                value: textSize,
                min: 10,
                max: 48,
                onChanged: onSizeChanged,
              ),
            ),
            SizedBox(width: 40, child: Text('${textSize.round()} pt')),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const SizedBox(width: 64, child: Text('Align')),
            IconButton(
              onPressed: () => onAlignChanged(TextAlign.left),
              icon: Icon(
                Icons.format_align_left_rounded,
                color: textAlign == TextAlign.left
                    ? Colors.blue
                    : null,
              ),
            ),
            IconButton(
              onPressed: () => onAlignChanged(TextAlign.center),
              icon: Icon(
                Icons.format_align_center_rounded,
                color: textAlign == TextAlign.center
                    ? Colors.blue
                    : null,
              ),
            ),
            IconButton(
              onPressed: () => onAlignChanged(TextAlign.right),
              icon: Icon(
                Icons.format_align_right_rounded,
                color: textAlign == TextAlign.right
                    ? Colors.blue
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a color picker dot
  static Widget _colorDot({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: selected ? 28 : 24,
        height: selected ? 28 : 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? Colors.white : Colors.black26,
            width: selected ? 2.4 : 1,
          ),
        ),
      ),
    );
  }
}
