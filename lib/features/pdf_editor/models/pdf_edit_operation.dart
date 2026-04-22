import 'dart:ui';

sealed class PdfEditOperation {
  const PdfEditOperation({required this.page});

  final int page;
}

class PdfStrokeOperation extends PdfEditOperation {
  const PdfStrokeOperation({
    required super.page,
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
}

class PdfHighlightOperation extends PdfEditOperation {
  const PdfHighlightOperation({
    required super.page,
    required this.rect,
    required this.color,
    required this.opacity,
  });

  final Rect rect;
  final Color color;
  final double opacity;
}

class PdfTextOperation extends PdfEditOperation {
  const PdfTextOperation({
    required super.page,
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
}

class PdfImageOperation extends PdfEditOperation {
  const PdfImageOperation({
    required super.page,
    required this.path,
    required this.position,
    required this.size,
  });

  final String path;
  final Offset position;
  final Size size;
}

class PdfInsertPageOperation extends PdfEditOperation {
  const PdfInsertPageOperation({
    required super.page,
    required this.afterPage,
  });

  final int afterPage;
}
