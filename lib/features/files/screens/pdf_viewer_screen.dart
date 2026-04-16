import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  final String pdfPath;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final File file = File(widget.pdfPath);
    if (!await file.exists()) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _bytes = bytes;
    });
  }

  Future<void> _share() async {
    if (_bytes == null) {
      return;
    }
    await Printing.sharePdf(bytes: _bytes!, filename: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'share') {
                _share();
              } else if (value == 'open_external') {
                _share();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: Text('Share'),
              ),
              const PopupMenuItem<String>(
                value: 'open_external',
                child: Text('Open in default browser/apps'),
              ),
            ],
          ),
        ],
      ),
      body: _bytes == null
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              build: (PdfPageFormat format) async => _bytes!,
            ),
    );
  }
}
