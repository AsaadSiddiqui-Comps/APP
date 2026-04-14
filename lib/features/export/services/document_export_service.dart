import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../documents/data/document_storage_service.dart';

enum ExportFormat { pdf, images }

class DocumentExportService {
  static Future<String> exportPdf({
    required String destinationDirectory,
    required String fileName,
    required List<XFile> pages,
  }) async {
    final pw.Document doc = pw.Document();

    for (final XFile page in pages) {
      final Uint8List bytes = await File(page.path).readAsBytes();
      final pw.MemoryImage image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    final Directory targetDir = Directory(destinationDirectory);
    await targetDir.create(recursive: true);
    final File output = File(
      '${targetDir.path}${Platform.pathSeparator}${_sanitizeFileName(fileName)}.pdf',
    );
    await output.writeAsBytes(await doc.save());
    return output.path;
  }

  static Future<List<String>> exportImages({
    required String destinationDirectory,
    required String fileName,
    required List<XFile> pages,
  }) async {
    final Directory targetDir = Directory(destinationDirectory);
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
  }

  static Future<Directory> defaultExportDirectory() async {
    return DocumentStorageService.instance.getExportedDir();
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
