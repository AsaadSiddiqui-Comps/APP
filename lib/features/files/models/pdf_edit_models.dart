import 'package:flutter/material.dart';

/// Editor tool selection
enum EditorTool { none, highlighter, draw, text }

/// Draw mode selection (pen or eraser)
enum DrawMode { pen, eraser }

/// Highlight annotation mode
enum HighlightMode {
  highlight('Highlight'),
  underline('Underline'),
  strike('Strike'),
  squiggly('Squiggly');

  const HighlightMode(this.label);
  final String label;
}

/// Undo/redo action wrapper
class EditorAction {
  const EditorAction({required this.undo, required this.redo});

  final VoidCallback undo;
  final VoidCallback redo;
}

/// Represents a single stroke path on the PDF
class StrokePath {
  const StrokePath({
    required this.points,
    required this.color,
    required this.width,
    required this.opacity,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;
}

/// Represents a text overlay on the PDF
class TextOverlay {
  const TextOverlay({
    required this.text,
    required this.position,
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.fontFamily,
    required this.textAlign,
  });

  final String text;
  final Offset position;
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final String fontFamily;
  final TextAlign textAlign;
}

/// Color palette for editor tools
const List<Color> editorPalette = <Color>[
  Color(0xFFFF7043),
  Color(0xFFFFEB3B),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
  Color(0xFF212121),
];

/// Font options for text tool
const List<String> textFontOptions = <String>[
  'Roboto',
  'Lato',
  'Montserrat',
  'Merriweather',
];

/// Text background colors
const List<Color> textBackgroundColors = <Color>[
  Colors.transparent,
  Colors.black54,
  Colors.white70,
  Color(0x99FFFF00),
];
