import 'dart:io';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import '../models/pdf_edit_operation.dart';

class PdfMutationService {
  Future<String> saveDocument({
    required String sourcePath,
    required List<PdfEditOperation> operations,
  }) async {
    final File sourceFile = File(sourcePath);
    final List<int> input = await sourceFile.readAsBytes();
    final sfpdf.PdfDocument document = sfpdf.PdfDocument(inputBytes: input);

    try {
      final List<PdfInsertPageOperation> pageInsertions = operations.whereType<PdfInsertPageOperation>().toList();
      _applyPageInsertions(document, pageInsertions);
      _applyDrawOperations(document, operations, pageInsertions);
      _applyHighlightOperations(document, operations, pageInsertions);
      _applyTextOperations(document, operations, pageInsertions);
      _applyImageOperations(document, operations, pageInsertions);

      final List<int> outputBytes = await document.save();
      final String outputPath = _buildOutputPath(sourceFile);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      return outputPath;
    } finally {
      document.dispose();
    }
  }

  String _buildOutputPath(File sourceFile) {
    final String fileName = sourceFile.uri.pathSegments.last;
    final String stem = fileName.toLowerCase().endsWith('.pdf')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return '${sourceFile.parent.path}${Platform.pathSeparator}${stem}_edited_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  void _applyPageInsertions(sfpdf.PdfDocument document, List<PdfInsertPageOperation> pageOps) {
    for (final PdfInsertPageOperation op in pageOps) {
      final int insertIndex = op.afterPage.clamp(0, document.pages.count);
      document.pages.insert(insertIndex);
    }
  }

  void _applyDrawOperations(
    sfpdf.PdfDocument document,
    List<PdfEditOperation> operations,
    List<PdfInsertPageOperation> pageInsertions,
  ) {
    for (final PdfStrokeOperation op in operations.whereType<PdfStrokeOperation>()) {
      final int? pageIndex = _pageIndexFor(document, op.page, pageInsertions);
      if (pageIndex == null) {
        continue;
      }
      final sfpdf.PdfPage page = document.pages[pageIndex];
      final sfpdf.PdfGraphics graphics = page.graphics;
      final sfpdf.PdfPen pen = sfpdf.PdfPen(
        sfpdf.PdfColor(op.color.r.toInt(), op.color.g.toInt(), op.color.b.toInt()),
        width: op.strokeWidth,
      );
      for (int i = 1; i < op.points.length; i += 1) {
        final Offset a = op.points[i - 1];
        final Offset b = op.points[i];
        graphics.drawLine(pen, a, b);
      }
    }
  }

  void _applyHighlightOperations(
    sfpdf.PdfDocument document,
    List<PdfEditOperation> operations,
    List<PdfInsertPageOperation> pageInsertions,
  ) {
    for (final PdfHighlightOperation op in operations.whereType<PdfHighlightOperation>()) {
      final int? pageIndex = _pageIndexFor(document, op.page, pageInsertions);
      if (pageIndex == null) {
        continue;
      }
      final sfpdf.PdfPage page = document.pages[pageIndex];
      final sfpdf.PdfGraphics graphics = page.graphics;
      final sfpdf.PdfColor color = sfpdf.PdfColor(
        (op.color.r * 255).round().clamp(0, 255),
        (op.color.g * 255).round().clamp(0, 255),
        (op.color.b * 255).round().clamp(0, 255),
      );
      graphics.drawRectangle(
        brush: sfpdf.PdfSolidBrush(color),
        bounds: Rect.fromLTWH(op.rect.left, op.rect.top, op.rect.width, op.rect.height),
      );
    }
  }

  void _applyTextOperations(
    sfpdf.PdfDocument document,
    List<PdfEditOperation> operations,
    List<PdfInsertPageOperation> pageInsertions,
  ) {
    for (final PdfTextOperation op in operations.whereType<PdfTextOperation>()) {
      final int? pageIndex = _pageIndexFor(document, op.page, pageInsertions);
      if (pageIndex == null) {
        continue;
      }
      final sfpdf.PdfPage page = document.pages[pageIndex];
      final sfpdf.PdfGraphics graphics = page.graphics;
      final sfpdf.PdfFont font = sfpdf.PdfStandardFont(sfpdf.PdfFontFamily.helvetica, op.fontSize);
      graphics.drawString(
        op.text,
        font,
        brush: sfpdf.PdfSolidBrush(
          sfpdf.PdfColor(
            (op.color.r * 255).round().clamp(0, 255),
            (op.color.g * 255).round().clamp(0, 255),
            (op.color.b * 255).round().clamp(0, 255),
          ),
        ),
        bounds: Rect.fromLTWH(op.position.dx, op.position.dy, page.size.width - op.position.dx, op.fontSize * 2),
      );
    }
  }

  void _applyImageOperations(
    sfpdf.PdfDocument document,
    List<PdfEditOperation> operations,
    List<PdfInsertPageOperation> pageInsertions,
  ) {
    for (final PdfImageOperation op in operations.whereType<PdfImageOperation>()) {
      final File imageFile = File(op.path);
      if (!imageFile.existsSync()) {
        continue;
      }
      final int? pageIndex = _pageIndexFor(document, op.page, pageInsertions);
      if (pageIndex == null) {
        continue;
      }
      final sfpdf.PdfPage page = document.pages[pageIndex];
      final sfpdf.PdfGraphics graphics = page.graphics;
      final sfpdf.PdfBitmap bitmap = sfpdf.PdfBitmap(awaitBytes(imageFile));
      graphics.drawImage(
        bitmap,
        Rect.fromLTWH(op.position.dx, op.position.dy, op.size.width, op.size.height),
      );
    }
  }

  int? _pageIndexFor(
    sfpdf.PdfDocument document,
    int originalPage,
    List<PdfInsertPageOperation> pageInsertions,
  ) {
    if (originalPage <= 0) {
      return null;
    }
    final int insertedBefore = pageInsertions.where((PdfInsertPageOperation op) => op.afterPage < originalPage).length;
    final int index = originalPage - 1 + insertedBefore;
    if (index >= document.pages.count) {
      return null;
    }
    return index;
  }

  List<int> awaitBytes(File imageFile) => imageFile.readAsBytesSync();
}
