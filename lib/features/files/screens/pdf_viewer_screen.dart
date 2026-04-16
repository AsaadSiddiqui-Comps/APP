import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
  late final PdfViewerController _controller;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  Future<void> _share() async {
    final File file = File(widget.pdfPath);
    if (!await file.exists()) {
      return;
    }

    final String fileName = file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  void _zoomIn() {
    final double next = (_zoom + 0.25).clamp(1.0, 5.0);
    _controller.zoomLevel = next;
  }

  void _zoomOut() {
    final double next = (_zoom - 0.25).clamp(1.0, 5.0);
    _controller.zoomLevel = next;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Zoom out',
            onPressed: _zoomOut,
            icon: const Icon(Icons.zoom_out_rounded),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: _zoomIn,
            icon: const Icon(Icons.zoom_in_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'share') {
                _share();
              } else if (value == 'open_external') {
                _share();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'share', child: Text('Share')),
              const PopupMenuItem<String>(
                value: 'open_external',
                child: Text('Open in default browser/apps'),
              ),
            ],
          ),
        ],
      ),
      body: File(widget.pdfPath).existsSync()
          ? SfPdfViewer.file(
              File(widget.pdfPath),
              controller: _controller,
              canShowPaginationDialog: true,
              canShowScrollHead: true,
              pageSpacing: 6,
              onZoomLevelChanged: (PdfZoomDetails details) {
                setState(() {
                  _zoom = details.newZoomLevel;
                });
              },
            )
          : const Center(child: Text('PDF file not found.')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'Zoom ${(100 * _zoom).round()}%',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
