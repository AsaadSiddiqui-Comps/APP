import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../documents/data/document_storage_service.dart';

enum ExportFormat { pdf, images }

class ExportException implements Exception {
  ExportException(this.message, {this.details});

  final String message;
  final Object? details;

  @override
  String toString() {
    if (details == null) {
      return message;
    }
    return '$message ($details)';
  }
}

class DocumentExportService {
  static Future<double> estimateOutputSizeMb({
    required List<XFile> pages,
    required ExportFormat format,
  }) async {
    int totalBytes = 0;
    for (final XFile page in pages) {
      final File file = File(page.path);
      if (await file.exists()) {
        totalBytes += await file.length();
      }
    }

    if (format == ExportFormat.pdf) {
      totalBytes = (totalBytes * 0.7).round();
    }

    return totalBytes / (1024 * 1024);
  }

  static Future<String> exportPdf({
    required String destinationDirectory,
    required String fileName,
    required List<XFile> pages,
    void Function(double progress)? onProgress,
  }) async {
    await _validatePages(pages);

    try {
      onProgress?.call(0.05);

      final List<Uint8List> pageBytes = <Uint8List>[];
      for (int i = 0; i < pages.length; i += 1) {
        pageBytes.add(await File(pages[i].path).readAsBytes());
        onProgress?.call(0.05 + (0.3 * ((i + 1) / pages.length)));
      }

      final Uint8List pdfBytes = await Isolate.run<Uint8List>(
        () => _buildPdfBytes(_PdfBuildRequest(pageBytes: pageBytes)),
      );
      onProgress?.call(0.85);

      final Directory targetDir = Directory(destinationDirectory);
      await targetDir.create(recursive: true);
      final File output = File(
        '${targetDir.path}${Platform.pathSeparator}${_sanitizeFileName(fileName)}.pdf',
      );
      await output.writeAsBytes(pdfBytes);
      onProgress?.call(1.0);
      return output.path;
    } catch (error) {
      throw ExportException('PDF export failed', details: error);
    }
  }

  static Future<List<String>> exportImages({
    required String destinationDirectory,
    required String fileName,
    required List<XFile> pages,
  }) async {
    await _validatePages(pages);

    final Directory targetDir = Directory(destinationDirectory);
    try {
      await targetDir.create(recursive: true);

      final List<String> outputs = <String>[];
      for (int i = 0; i < pages.length; i += 1) {
        final String extension = _extension(pages[i].path);
        final File output = File(
          '${targetDir.path}${Platform.pathSeparator}${_sanitizeFileName(fileName)}_${(i + 1).toString().padLeft(3, '0')}.$extension',
        );
        await File(pages[i].path).copy(output.path);
        outputs.add(output.path);
      }
      return outputs;
    } catch (error) {
      throw ExportException('Image export failed', details: error);
    }
  }

  static Future<Directory> defaultExportDirectory() async {
    return DocumentStorageService.instance.getExportedDir();
  }

  static Future<void> _validatePages(List<XFile> pages) async {
    if (pages.isEmpty) {
      throw ExportException('No pages to export');
    }
    for (final XFile page in pages) {
      if (!await File(page.path).exists()) {
        throw ExportException('Some pages are missing', details: page.path);
      }
    }
  }

  static String _sanitizeFileName(String value) {
    final String cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return cleaned.isEmpty ? 'exported_document' : cleaned;
  }

  static String _extension(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return 'jpg';
    }
    return path.substring(dot + 1);
  }
}

class _PdfBuildRequest {
  const _PdfBuildRequest({required this.pageBytes});

  final List<Uint8List> pageBytes;
}

Future<Uint8List> _buildPdfBytes(_PdfBuildRequest request) async {
  final pw.Document doc = pw.Document();

  for (final Uint8List original in request.pageBytes) {
    final img.Image? decoded = img.decodeImage(original);
    Uint8List prepared = original;

    if (decoded != null) {
      const int maxWidth = 1700;
      img.Image processed = decoded;
      if (decoded.width > maxWidth) {
        processed = img.copyResize(
          decoded,
          width: maxWidth,
          interpolation: img.Interpolation.average,
        );
      }
      prepared = Uint8List.fromList(img.encodeJpg(processed, quality: 88));
    }

    final pw.MemoryImage image = pw.MemoryImage(prepared);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
        },
      ),
    );
  }

  return Uint8List.fromList(await doc.save());
}
