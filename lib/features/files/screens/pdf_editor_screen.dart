import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/constants/app_colors.dart';
import '../../documents/data/document_storage_service.dart';
import '../models/pdf_edit_models.dart';
import '../widgets/editor_tool_panel.dart';

enum _EditorCanvasTool { none, highlighter, draw, text, image, addPage }

class _EditableTextItem {
  _EditableTextItem({
    required this.id,
    required this.text,
    required this.position,
    required this.width,
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.fontFamily,
    required this.textAlign,
    this.height = 48,
  });

  final String id;
  String text;
  Offset position;
  double width;
  Color textColor;
  Color backgroundColor;
  double fontSize;
  String fontFamily;
  TextAlign textAlign;
  double height;
}

class _EditableImageItem {
  _EditableImageItem({
    required this.id,
    required this.bytes,
    required this.position,
    required this.size,
  });

  final String id;
  Uint8List bytes;
  Offset position;
  Size size;
}

class _PageOverlayData {
  final List<StrokePath> strokes = <StrokePath>[];
  final List<_EditableTextItem> texts = <_EditableTextItem>[];
  final List<_EditableImageItem> images = <_EditableImageItem>[];

  bool get isEmpty => strokes.isEmpty && texts.isEmpty && images.isEmpty;
}

class PdfEditorScreen extends StatefulWidget {
  const PdfEditorScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  final String pdfPath;
  final String title;

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  late final PdfViewerController _controller;
  final ValueNotifier<int> _overlayTick = ValueNotifier<int>(0);

  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isViewMode = true;
  String? _loadError;

  _EditorCanvasTool _activeTool = _EditorCanvasTool.none;

  HighlightMode _highlightMode = HighlightMode.highlight;
  Color _highlightColor = const Color(0xFFFFEB3B);
  double _highlightOpacity = 0.42;

  DrawMode _drawMode = DrawMode.pen;
  Color _drawColor = const Color(0xFFEF5350);
  double _drawWidth = 4;
  double _drawOpacity = 1.0;
  double _eraserSize = 24;

  Color _textColor = Colors.white;
  Color _textBackground = Colors.black54;
  double _textSize = 22;
  TextAlign _textAlign = TextAlign.left;
  String _textFont = 'Roboto';

  final Map<int, _PageOverlayData> _overlaysByPage = <int, _PageOverlayData>{};
  final List<Offset> _activeStrokePoints = <Offset>[];

  String? _selectedTextId;
  String? _selectedImageId;

  bool _overlayDirty = false;
  Size _canvasSize = const Size(1, 1);
  bool _allowProgrammaticPageJump = false;

  bool get _hasUnsavedEdits => _overlayDirty;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverlayData();
    });
  }

  @override
  void dispose() {
    _overlayTick.dispose();
    super.dispose();
  }

  _PageOverlayData get _currentLayer {
    return _overlaysByPage.putIfAbsent(_currentPage, _PageOverlayData.new);
  }

  bool get _overlayToolActive {
    return _activeTool == _EditorCanvasTool.highlighter ||
      _activeTool == _EditorCanvasTool.draw ||
        _activeTool == _EditorCanvasTool.text ||
        _activeTool == _EditorCanvasTool.image;
  }

  void _notifyOverlay() {
    _overlayTick.value += 1;
  }

  void _markOverlayDirty() {
    if (_overlayDirty) {
      _notifyOverlay();
      return;
    }
    setState(() {
      _overlayDirty = true;
    });
    _notifyOverlay();
  }

  void _appendStrokePoint(Offset point) {
    if (_activeStrokePoints.isEmpty) {
      _activeStrokePoints.add(point);
      return;
    }
    final Offset last = _activeStrokePoints.last;
    if ((point - last).distance > 1.4) {
      _activeStrokePoints.add(point);
    }
  }

  int _channel255(double value) => (value * 255).round().clamp(0, 255);

  bool get _absorbPdfGestures {
    if (_isViewMode) {
      return false;
    }
    return _overlayToolActive;
  }

  String _sidecarPathFor(String pdfPath) => '$pdfPath.docly_overlay.json';

  Future<void> _loadOverlayData() async {
    try {
      final File sidecar = File(_sidecarPathFor(widget.pdfPath));
      if (!await sidecar.exists()) {
        return;
      }

      final String raw = await sidecar.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }

      final Map<String, dynamic> map =
          (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, dynamic>();

      final double baseWidth = (map['canvasWidth'] as num?)?.toDouble() ?? 1;
      final double baseHeight = (map['canvasHeight'] as num?)?.toDouble() ?? 1;
      final double targetWidth = _canvasSize.width > 1 ? _canvasSize.width : baseWidth;
      final double targetHeight = _canvasSize.height > 1 ? _canvasSize.height : baseHeight;

      final Map<int, _PageOverlayData> loaded = <int, _PageOverlayData>{};
      final Map<dynamic, dynamic> pages =
          map['pages'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};

      for (final MapEntry<dynamic, dynamic> pageEntry in pages.entries) {
        final int page = int.tryParse(pageEntry.key.toString()) ?? 0;
        if (page <= 0) {
          continue;
        }

        final Map<String, dynamic> pageMap =
            (pageEntry.value as Map<dynamic, dynamic>).cast<String, dynamic>();
        final _PageOverlayData data = _PageOverlayData();

        final List<dynamic> strokesRaw =
            pageMap['strokes'] as List<dynamic>? ?? <dynamic>[];
        for (final dynamic s in strokesRaw) {
          final Map<String, dynamic> sm =
              (s as Map<dynamic, dynamic>).cast<String, dynamic>();
          final List<dynamic> pointsRaw = sm['points'] as List<dynamic>? ?? <dynamic>[];
          data.strokes.add(
            StrokePath(
              points: pointsRaw
                  .whereType<Map<dynamic, dynamic>>()
                  .map((Map<dynamic, dynamic> p) {
                    final double nx = (p['x'] as num?)?.toDouble() ?? 0;
                    final double ny = (p['y'] as num?)?.toDouble() ?? 0;
                    return Offset(nx * targetWidth, ny * targetHeight);
                  })
                  .toList(growable: false),
              color: Color((sm['color'] as num?)?.toInt() ?? Colors.red.toARGB32()),
              width: (sm['width'] as num?)?.toDouble() ?? 4,
              opacity: (sm['opacity'] as num?)?.toDouble() ?? 1,
            ),
          );
        }

        final List<dynamic> textsRaw =
            pageMap['texts'] as List<dynamic>? ?? <dynamic>[];
        for (final dynamic t in textsRaw) {
          final Map<String, dynamic> tm =
              (t as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String alignName = (tm['align'] as String?) ?? 'left';
          final TextAlign align = TextAlign.values.firstWhere(
            (TextAlign ta) => ta.name == alignName,
            orElse: () => TextAlign.left,
          );
          data.texts.add(
            _EditableTextItem(
              id: (tm['id'] as String?) ?? _newId(),
              text: (tm['text'] as String?) ?? '',
              position: Offset(
                ((tm['x'] as num?)?.toDouble() ?? 0) * targetWidth,
                ((tm['y'] as num?)?.toDouble() ?? 0) * targetHeight,
              ),
              width: ((tm['width'] as num?)?.toDouble() ?? 120) * targetWidth,
              textColor: Color((tm['textColor'] as num?)?.toInt() ?? Colors.white.toARGB32()),
              backgroundColor: Color(
                (tm['bgColor'] as num?)?.toInt() ?? Colors.transparent.toARGB32(),
              ),
              fontSize: (tm['fontSize'] as num?)?.toDouble() ?? 22,
              fontFamily: (tm['font'] as String?) ?? 'Roboto',
              textAlign: align,
            ),
          );
        }

        final List<dynamic> imagesRaw =
            pageMap['images'] as List<dynamic>? ?? <dynamic>[];
        for (final dynamic i in imagesRaw) {
          final Map<String, dynamic> im =
              (i as Map<dynamic, dynamic>).cast<String, dynamic>();
          final String b64 = (im['bytes'] as String?) ?? '';
          if (b64.isEmpty) {
            continue;
          }
          data.images.add(
            _EditableImageItem(
              id: (im['id'] as String?) ?? _newId(),
              bytes: base64Decode(b64),
              position: Offset(
                ((im['x'] as num?)?.toDouble() ?? 0) * targetWidth,
                ((im['y'] as num?)?.toDouble() ?? 0) * targetHeight,
              ),
              size: Size(
                ((im['w'] as num?)?.toDouble() ?? 120) * targetWidth,
                ((im['h'] as num?)?.toDouble() ?? 120) * targetHeight,
              ),
            ),
          );
        }

        loaded[page] = data;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _overlaysByPage
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Ignore sidecar load errors.
    }
  }

  Future<void> _persistOverlayData(String targetPdfPath) async {
    final double width = _canvasSize.width <= 0 ? 1 : _canvasSize.width;
    final double height = _canvasSize.height <= 0 ? 1 : _canvasSize.height;

    final Map<String, dynamic> pages = <String, dynamic>{};
    _overlaysByPage.forEach((int page, _PageOverlayData layer) {
      if (layer.isEmpty) {
        return;
      }

      pages['$page'] = <String, dynamic>{
        'strokes': layer.strokes
            .map(
              (StrokePath s) => <String, dynamic>{
                'color': s.color.toARGB32(),
                'width': s.width,
                'opacity': s.opacity,
                'points': s.points
                    .map(
                      (Offset p) => <String, dynamic>{
                        'x': p.dx / width,
                        'y': p.dy / height,
                      },
                    )
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
        'texts': layer.texts
            .map(
              (_EditableTextItem t) => <String, dynamic>{
                'id': t.id,
                'text': t.text,
                'x': t.position.dx / width,
                'y': t.position.dy / height,
                'width': t.width / width,
                'textColor': t.textColor.toARGB32(),
                'bgColor': t.backgroundColor.toARGB32(),
                'fontSize': t.fontSize,
                'font': t.fontFamily,
                'align': t.textAlign.name,
              },
            )
            .toList(growable: false),
        'images': layer.images
            .map(
              (_EditableImageItem i) => <String, dynamic>{
                'id': i.id,
                'bytes': base64Encode(i.bytes),
                'x': i.position.dx / width,
                'y': i.position.dy / height,
                'w': i.size.width / width,
                'h': i.size.height / height,
              },
            )
            .toList(growable: false),
      };
    });

    final File sidecar = File(_sidecarPathFor(targetPdfPath));
    if (pages.isEmpty) {
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'canvasWidth': width,
      'canvasHeight': height,
      'pages': pages,
    };

    await sidecar.writeAsString(jsonEncode(payload));
  }

  Future<void> _deleteOverlayData(String targetPdfPath) async {
    final File sidecar = File(_sidecarPathFor(targetPdfPath));
    if (await sidecar.exists()) {
      await sidecar.delete();
    }
  }

  Future<List<int>> _renderOverlayIntoPdf(List<int> sourceBytes) async {
    if (_overlaysByPage.isEmpty || _canvasSize.width <= 0 || _canvasSize.height <= 0) {
      return sourceBytes;
    }

    final sfpdf.PdfDocument document = sfpdf.PdfDocument(inputBytes: sourceBytes);

    try {
      for (final MapEntry<int, _PageOverlayData> entry in _overlaysByPage.entries) {
        final int pageNo = entry.key;
        if (pageNo <= 0 || pageNo > document.pages.count) {
          continue;
        }

        final _PageOverlayData layer = entry.value;
        if (layer.isEmpty) {
          continue;
        }

        final sfpdf.PdfPage page = document.pages[pageNo - 1];
        final sfpdf.PdfGraphics g = page.graphics;
        final double sx = page.size.width / _canvasSize.width;
        final double sy = page.size.height / _canvasSize.height;

        for (final StrokePath stroke in layer.strokes) {
          if (stroke.points.length < 2) {
            continue;
          }
          final sfpdf.PdfPen pen = sfpdf.PdfPen(
            sfpdf.PdfColor(
              _channel255(stroke.color.r),
              _channel255(stroke.color.g),
              _channel255(stroke.color.b),
            ),
            width: stroke.width * sx,
          );
          for (int i = 1; i < stroke.points.length; i += 1) {
            final Offset a = stroke.points[i - 1];
            final Offset b = stroke.points[i];
            g.drawLine(
              pen,
              Offset(a.dx * sx, a.dy * sy),
              Offset(b.dx * sx, b.dy * sy),
            );
          }
        }

        for (final _EditableTextItem text in layer.texts) {
          final sfpdf.PdfFont font = sfpdf.PdfStandardFont(
            sfpdf.PdfFontFamily.helvetica,
            text.fontSize * sx,
          );
          final Rect rect = Rect.fromLTWH(
            text.position.dx * sx,
            text.position.dy * sy,
            text.width * sx,
            text.height * sy,
          );

          if (text.backgroundColor.a > 0) {
            g.drawRectangle(
              brush: sfpdf.PdfSolidBrush(
                sfpdf.PdfColor(
                  _channel255(text.backgroundColor.r),
                  _channel255(text.backgroundColor.g),
                  _channel255(text.backgroundColor.b),
                ),
              ),
              bounds: rect,
            );
          }

          g.drawString(
            text.text,
            font,
            brush: sfpdf.PdfSolidBrush(
              sfpdf.PdfColor(
                _channel255(text.textColor.r),
                _channel255(text.textColor.g),
                _channel255(text.textColor.b),
              ),
            ),
            bounds: rect,
          );
        }

        for (final _EditableImageItem image in layer.images) {
          final sfpdf.PdfBitmap bitmap = sfpdf.PdfBitmap(image.bytes);
          g.drawImage(
            bitmap,
            Rect.fromLTWH(
              image.position.dx * sx,
              image.position.dy * sy,
              image.size.width * sx,
              image.size.height * sy,
            ),
          );
        }
      }

      return await document.save();
    } finally {
      document.dispose();
    }
  }

  Future<void> _saveEdits({required bool saveAsCopy}) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final List<int> savedBytes = await _controller.saveDocument();
      final List<int> mergedBytes = await _renderOverlayIntoPdf(savedBytes);
      if (saveAsCopy) {
        final Directory exportDir = await DocumentStorageService.instance.getExportedDir();
        final String now = DateTime.now().millisecondsSinceEpoch.toString();
        final String fileName = _buildCopyFileName(now);
        final String tempPath = '${exportDir.path}${Platform.pathSeparator}$fileName';

        await File(tempPath).writeAsBytes(mergedBytes, flush: true);
        final String finalPath = await DocumentStorageService.instance.saveFileToPublicDownloads(
          sourcePath: tempPath,
          displayName: fileName,
          mimeType: 'application/pdf',
        );

        final File tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        await DocumentStorageService.instance.scanFile(finalPath);
        await _deleteOverlayData(finalPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved copy: ${File(finalPath).uri.pathSegments.last}')),
          );
        }
      } else {
        await File(widget.pdfPath).writeAsBytes(mergedBytes, flush: true);
        await DocumentStorageService.instance.scanFile(widget.pdfPath);
        await _deleteOverlayData(widget.pdfPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Original PDF updated successfully.')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _overlaysByPage.clear();
          _selectedTextId = null;
          _selectedImageId = null;
          _activeStrokePoints.clear();
          _overlayDirty = false;
        });
      }
      _notifyOverlay();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save PDF edits. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildCopyFileName(String suffix) {
    final String original = File(widget.pdfPath).uri.pathSegments.last;
    final String cleanOriginal = original.toLowerCase().endsWith('.pdf')
        ? original.substring(0, original.length - 4)
        : original;
    final String safe = cleanOriginal.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '${safe}_edited_$suffix.pdf';
  }

  void _setActiveTool(_EditorCanvasTool tool) {
    setState(() {
      _activeTool = tool;
      _selectedTextId = null;
      _selectedImageId = null;
      _activeStrokePoints.clear();
    });

    if (tool == _EditorCanvasTool.image) {
      _pickImageAndInsert();
    }
    if (tool == _EditorCanvasTool.addPage) {
      _showAddPageMenu();
    }
  }

  void _toggleViewMode() {
    setState(() {
      _isViewMode = !_isViewMode;
      if (!_isViewMode) {
        _controller.zoomLevel = 1.0;
      }
    });
  }

  void _onDrawStart(DragStartDetails details) {
    if (_isViewMode) {
      return;
    }

    if (_activeTool != _EditorCanvasTool.draw && _activeTool != _EditorCanvasTool.highlighter) {
      return;
    }

    if (_activeTool == _EditorCanvasTool.draw && _drawMode == DrawMode.eraser) {
      _eraseAt(details.localPosition);
      return;
    }
    _activeStrokePoints
      ..clear()
      ..add(details.localPosition);
    _notifyOverlay();
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    if (_isViewMode) {
      return;
    }

    if (_activeTool != _EditorCanvasTool.draw && _activeTool != _EditorCanvasTool.highlighter) {
      return;
    }

    if (_activeTool == _EditorCanvasTool.draw && _drawMode == DrawMode.eraser) {
      _eraseAt(details.localPosition);
      return;
    }

    _appendStrokePoint(details.localPosition);
    _notifyOverlay();
  }

  void _onDrawEnd(DragEndDetails details) {
    if (_isViewMode) {
      return;
    }

    if (_activeTool != _EditorCanvasTool.draw && _activeTool != _EditorCanvasTool.highlighter) {
      return;
    }

    if (_activeTool == _EditorCanvasTool.draw && _drawMode == DrawMode.eraser) {
      _notifyOverlay();
      return;
    }

    if (_activeStrokePoints.length < 2) {
      _activeStrokePoints.clear();
      _notifyOverlay();
      return;
    }

    _currentLayer.strokes.add(
      StrokePath(
        points: List<Offset>.from(_activeStrokePoints),
        color: _activeTool == _EditorCanvasTool.highlighter ? _highlightColor : _drawColor,
        width: _activeTool == _EditorCanvasTool.highlighter ? 18 : _drawWidth,
        opacity: _activeTool == _EditorCanvasTool.highlighter
            ? _highlightOpacity.clamp(0.1, 1.0)
            : _drawOpacity,
      ),
    );
    _activeStrokePoints.clear();
    _markOverlayDirty();
  }

  void _eraseAt(Offset point) {
    final double threshold = _eraserSize.clamp(6, 80);
    final List<StrokePath> rebuilt = <StrokePath>[];

    for (final StrokePath stroke in _currentLayer.strokes) {
      final List<List<Offset>> segments = <List<Offset>>[];
      List<Offset> current = <Offset>[];

      for (final Offset p in stroke.points) {
        final bool keep = (p - point).distance > threshold;
        if (keep) {
          current.add(p);
        } else if (current.length > 1) {
          segments.add(current);
          current = <Offset>[];
        }
      }

      if (current.length > 1) {
        segments.add(current);
      }

      for (final List<Offset> segment in segments) {
        rebuilt.add(
          StrokePath(
            points: segment,
            color: stroke.color,
            width: stroke.width,
            opacity: stroke.opacity,
          ),
        );
      }
    }

    _currentLayer.strokes
      ..clear()
      ..addAll(rebuilt);
    _markOverlayDirty();
  }

  Future<void> _onCanvasTap(TapDownDetails details) async {
    if (_isViewMode) {
      return;
    }

    if (_activeTool == _EditorCanvasTool.text) {
      await _addTextAt(details.localPosition);
      return;
    }

    if (_activeTool == _EditorCanvasTool.image) {
      return;
    }

    setState(() {
      _selectedTextId = null;
      _selectedImageId = null;
    });
  }

  Future<void> _addTextAt(Offset position) async {
    final _EditableTextItem item = _EditableTextItem(
      id: _newId(),
      text: 'New text',
      position: position,
      width: 180,
      textColor: _textColor,
      backgroundColor: _textBackground,
      fontSize: _textSize,
      fontFamily: _textFont,
      textAlign: _textAlign,
      height: 56,
    );

    setState(() {
      _currentLayer.texts.add(item);
      _selectedTextId = item.id;
      _overlayDirty = true;
    });
    _notifyOverlay();
  }

  Future<String?> _showTextEditorSheet(
    TextEditingController controller, {
    required String title,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 6,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  hintText: 'Enter text',
                ),
                onSubmitted: (String value) {
                  Navigator.of(context).pop(value.trim());
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageAndInsert() async {
    if (_isViewMode) {
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final PlatformFile file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty || !mounted) {
      return;
    }

    bytes = await _optimizeImage(bytes);

    final Size size = _canvasSize;
    final Size box = Size((size.width * 0.34).clamp(120, 220), (size.width * 0.34).clamp(120, 220));
    final Offset pos = Offset(
      (size.width - box.width) / 2,
      (size.height - box.height) / 2,
    );

    final _EditableImageItem item = _EditableImageItem(
      id: _newId(),
      bytes: bytes,
      position: pos,
      size: box,
    );

    setState(() {
      _currentLayer.images.add(item);
      _selectedImageId = item.id;
      _activeTool = _EditorCanvasTool.image;
      _overlayDirty = true;
    });
    _notifyOverlay();
  }

  Future<Uint8List> _optimizeImage(Uint8List raw) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(raw, targetWidth: 1280);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return raw;
      }
      return data.buffer.asUint8List();
    } catch (_) {
      return raw;
    }
  }

  Future<void> _insertBlankPage({required int afterPage}) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final List<int> input = await File(widget.pdfPath).readAsBytes();
      final sfpdf.PdfDocument document = sfpdf.PdfDocument(inputBytes: input);
      final int insertIndex = afterPage.clamp(0, document.pages.count);
      document.pages.insert(insertIndex);

      final List<int> output = await document.save();
      document.dispose();

      await File(widget.pdfPath).writeAsBytes(output, flush: true);
      await DocumentStorageService.instance.scanFile(widget.pdfPath);

      if (_overlaysByPage.isNotEmpty) {
        final Map<int, _PageOverlayData> shifted = <int, _PageOverlayData>{};
        for (final MapEntry<int, _PageOverlayData> e in _overlaysByPage.entries) {
          shifted[e.key > afterPage ? e.key + 1 : e.key] = e.value;
        }
        _overlaysByPage
          ..clear()
          ..addAll(shifted);
      }

      await _persistOverlayData(widget.pdfPath);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page inserted after page $afterPage.')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PdfEditorScreen(
            pdfPath: widget.pdfPath,
            title: widget.title,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to insert page in this PDF.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _activeTool = _EditorCanvasTool.none;
        });
      }
    }
  }

  Future<void> _showAddPageMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Page', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Current pages (pick insertion point):',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(_pageCount + 1, (int index) {
                    final bool end = index == _pageCount;
                    final String label = end ? 'At end +' : 'After ${index + 1} +';
                    return ActionChip(
                      label: Text(label),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final int afterPage = end ? _pageCount : index + 1;
                        await _insertBlankPage(afterPage: afterPage);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _activeTool = _EditorCanvasTool.none;
      });
    }
  }

  Future<void> _showTopMenu() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Reset'),
                subtitle: const Text('Clear drawing, text, and image overlays'),
                onTap: () => Navigator.of(context).pop('reset'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Save as Copy'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'reset') {
      setState(() {
        _overlaysByPage.clear();
        _activeStrokePoints.clear();
        _selectedTextId = null;
        _selectedImageId = null;
        _overlayDirty = true;
      });
      return;
    }

    if (action == 'copy') {
      await _saveEdits(saveAsCopy: true);
      return;
    }

  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      title: Text(
        widget.title,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          tooltip: 'Save on original',
          onPressed: _isSaving ? null : () => _saveEdits(saveAsCopy: false),
          icon: const Icon(Icons.save_rounded),
        ),
        if (_hasUnsavedEdits)
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 2),
            child: Icon(Icons.fiber_manual_record_rounded, size: 10),
          ),
        IconButton(
          onPressed: _showTopMenu,
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }

  Widget _buildToolBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? const <Color>[Color(0xFF2C3145), Color(0xFF1B2033)]
              : const <Color>[Color(0xFFD9F2FF), Color(0xFFF5FBFF)],
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolButton(_EditorCanvasTool.highlighter, Icons.highlight_alt_rounded, 'Highlight'),
            _toolButton(_EditorCanvasTool.draw, Icons.draw_rounded, 'Draw'),
            _toolButton(_EditorCanvasTool.text, Icons.text_fields_rounded, 'Text'),
            _toolButton(_EditorCanvasTool.image, Icons.image_outlined, 'Image'),
            _toolButton(_EditorCanvasTool.addPage, Icons.note_add_outlined, 'Add Page'),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(_EditorCanvasTool tool, IconData icon, String label) {
    final bool selected = _activeTool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) {
          if (_isViewMode) {
            _toggleViewMode();
          }
          _setActiveTool(tool);
        },
      ),
    );
  }

  Widget _buildToolConfigPanel() {
    if (_isViewMode || _activeTool == _EditorCanvasTool.none || _activeTool == _EditorCanvasTool.addPage) {
      return const SizedBox.shrink();
    }

    final Color panel = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainerLow;

    Widget child;
    if (_activeTool == _EditorCanvasTool.highlighter) {
      child = EditorToolPanel.buildHighlighterPanel(
        highlightMode: _highlightMode,
        highlightColor: _highlightColor,
        highlightOpacity: _highlightOpacity,
        onColorChanged: (Color c) => setState(() {
          _highlightColor = c;
        }),
        onOpacityChanged: (double v) => setState(() {
          _highlightOpacity = v;
        }),
        onModeChanged: (HighlightMode v) => setState(() {
          _highlightMode = v;
        }),
      );
    } else if (_activeTool == _EditorCanvasTool.draw) {
      child = EditorToolPanel.buildDrawPanel(
        drawMode: _drawMode,
        drawColor: _drawColor,
        drawWidth: _drawWidth,
        drawOpacity: _drawOpacity,
        eraserSize: _eraserSize,
        onModeChanged: (DrawMode v) => setState(() => _drawMode = v),
        onColorChanged: (Color v) => setState(() => _drawColor = v),
        onWidthChanged: (double v) => setState(() => _drawWidth = v),
        onOpacityChanged: (double v) => setState(() => _drawOpacity = v),
        onEraserSizeChanged: (double v) => setState(() => _eraserSize = v),
      );
    } else if (_activeTool == _EditorCanvasTool.text) {
      child = EditorToolPanel.buildTextPanel(
        textColor: _textColor,
        textBackground: _textBackground,
        textFont: _textFont,
        textSize: _textSize,
        textAlign: _textAlign,
        onColorChanged: (Color v) => setState(() => _textColor = v),
        onBackgroundChanged: (Color v) => setState(() => _textBackground = v),
        onFontChanged: (String v) => setState(() => _textFont = v),
        onSizeChanged: (double v) => setState(() => _textSize = v),
        onAlignChanged: (TextAlign v) => setState(() => _textAlign = v),
      );
    } else {
      child = Row(
        children: [
          FilledButton.icon(
            onPressed: _pickImageAndInsert,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload image'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _selectedImageId == null
                ? null
                : () {
                    setState(() {
                      _currentLayer.images.removeWhere((i) => i.id == _selectedImageId);
                      _selectedImageId = null;
                      _overlayDirty = true;
                    });
                  },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove selected'),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: panel,
      child: child,
    );
  }

  Widget _buildPageNavigationBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? const <Color>[Color(0xFF21263A), Color(0xFF161A2B)]
              : const <Color>[Color(0xFFE7FAEE), Color(0xFFF9FFFB)],
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _currentPage > 1
                ? () {
                    _allowProgrammaticPageJump = true;
                    _controller.jumpToPage(_currentPage - 1);
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page $_currentPage of $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _currentPage < _pageCount
                ? () {
                    _allowProgrammaticPageJump = true;
                    _controller.jumpToPage(_currentPage + 1);
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTexts() {
    return Stack(
      children: _currentLayer.texts.map((_EditableTextItem item) {
        final bool selected = _selectedTextId == item.id;

        return Positioned(
          left: item.position.dx,
          top: item.position.dy,
          width: item.width,
          child: GestureDetector(
            onTap: () {
              if (_isViewMode) {
                return;
              }
              setState(() {
                _selectedTextId = item.id;
                _selectedImageId = null;
              });
            },
            onDoubleTap: () async {
              if (_isViewMode) {
                return;
              }
              final TextEditingController c = TextEditingController(text: item.text);
              final String? edited = await _showTextEditorSheet(c, title: 'Edit text');
              c.dispose();
              if (edited == null || edited.trim().isEmpty || !mounted) {
                return;
              }
              setState(() {
                item.text = edited.trim();
                _overlayDirty = true;
              });
            },
            onPanUpdate: _isViewMode
                ? null
                : (DragUpdateDetails d) {
                    if (!selected) {
                      return;
                    }
                    setState(() {
                      item.position = item.position + d.delta;
                    });
                    _markOverlayDirty();
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: item.backgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.2)
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: item.width,
                    height: item.height,
                    child: Text(
                      item.text,
                      textAlign: item.textAlign,
                      style: TextStyle(
                        color: item.textColor,
                        fontSize: item.fontSize,
                        fontFamily: item.fontFamily,
                        height: 1.24,
                      ),
                    ),
                  ),
                  if (selected && !_isViewMode)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentLayer.texts.removeWhere((t) => t.id == item.id);
                            _selectedTextId = null;
                          });
                          _markOverlayDirty();
                        },
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  if (selected && !_isViewMode)
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: GestureDetector(
                        onPanUpdate: (DragUpdateDetails d) {
                          item.width = (item.width + d.delta.dx).clamp(100, _canvasSize.width);
                          item.height = (item.height + d.delta.dy).clamp(32, _canvasSize.height * 0.5);
                          _markOverlayDirty();
                        },
                        child: const CircleAvatar(
                          radius: 10,
                          child: Icon(Icons.open_in_full_rounded, size: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildEditableImages() {
    return Stack(
      children: _currentLayer.images.map((_EditableImageItem item) {
        final bool selected = _selectedImageId == item.id;
        return Positioned(
          left: item.position.dx,
          top: item.position.dy,
          width: item.size.width,
          height: item.size.height,
          child: GestureDetector(
            onTap: () {
              if (_isViewMode) {
                return;
              }
              setState(() {
                _selectedImageId = item.id;
                _selectedTextId = null;
              });
            },
            onPanUpdate: _isViewMode
                ? null
                : (DragUpdateDetails d) {
                    if (!selected) {
                      return;
                    }
                    setState(() {
                      item.position = item.position + d.delta;
                    });
                    _markOverlayDirty();
                  },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(item.bytes, fit: BoxFit.cover),
                  ),
                ),
                if (selected && !_isViewMode)
                  Positioned(
                    right: -12,
                    top: -12,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentLayer.images.removeWhere((i) => i.id == item.id);
                          _selectedImageId = null;
                        });
                        _markOverlayDirty();
                      },
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                if (selected && !_isViewMode)
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: GestureDetector(
                      onPanUpdate: (DragUpdateDetails d) {
                        setState(() {
                          final double nextW = (item.size.width + d.delta.dx).clamp(60, _canvasSize.width);
                          final double nextH = (item.size.height + d.delta.dy).clamp(60, _canvasSize.height);
                          item.size = Size(nextW, nextH);
                          _notifyOverlay();
                        });
                        _markOverlayDirty();
                      },
                      child: const CircleAvatar(
                        radius: 10,
                        child: Icon(Icons.open_in_full_rounded, size: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildTopBar(),
      body: File(widget.pdfPath).existsSync()
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: AbsorbPointer(
                        absorbing: _absorbPdfGestures,
                        child: SfPdfViewer.file(
                          File(widget.pdfPath),
                          controller: _controller,
                          pageLayoutMode: PdfPageLayoutMode.single,
                          canShowPaginationDialog: false,
                          canShowScrollHead: false,
                          canShowPageLoadingIndicator: true,
                          canShowScrollStatus: false,
                          interactionMode: PdfInteractionMode.pan,
                          enableTextSelection: false,
                          enableDoubleTapZooming: true,
                          maxZoomLevel: 5,
                          pageSpacing: 2,
                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _isLoading = false;
                              _loadError = null;
                              _pageCount = details.document.pages.count;
                              _currentPage = _controller.pageNumber;
                            });
                          },
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _isLoading = false;
                              _loadError = details.description;
                            });
                          },
                          onPageChanged: (PdfPageChangedDetails details) {
                            if (!mounted) {
                              return;
                            }

                            if (!_allowProgrammaticPageJump && details.newPageNumber != details.oldPageNumber) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) {
                                  return;
                                }
                                _allowProgrammaticPageJump = true;
                                _controller.jumpToPage(details.oldPageNumber);
                              });
                              return;
                            }

                            _allowProgrammaticPageJump = false;
                            setState(() {
                              _currentPage = details.newPageNumber;
                              _selectedImageId = null;
                              _selectedTextId = null;
                              _activeStrokePoints.clear();
                            });
                          },
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _overlayTick,
                        builder: (BuildContext context, int tick, Widget? child) {
                          return IgnorePointer(
                            ignoring: _isViewMode,
                            child: RepaintBoundary(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _StrokeOverlayPainter(
                                        strokes: _currentLayer.strokes,
                                        activeStroke: _activeStrokePoints,
                                        activeStrokeColor:
                                            _activeTool == _EditorCanvasTool.highlighter ? _highlightColor : _drawColor,
                                        activeStrokeWidth:
                                            _activeTool == _EditorCanvasTool.highlighter ? 18 : _drawWidth,
                                        activeStrokeOpacity: _activeTool == _EditorCanvasTool.highlighter
                                            ? _highlightOpacity.clamp(0.1, 1.0)
                                            : _drawOpacity,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(child: _buildEditableImages()),
                                  Positioned.fill(child: _buildEditableTexts()),
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onPanStart: (_activeTool == _EditorCanvasTool.draw ||
                                              _activeTool == _EditorCanvasTool.highlighter)
                                          ? _onDrawStart
                                          : null,
                                      onPanUpdate: (_activeTool == _EditorCanvasTool.draw ||
                                              _activeTool == _EditorCanvasTool.highlighter)
                                          ? _onDrawUpdate
                                          : null,
                                      onPanEnd: (_activeTool == _EditorCanvasTool.draw ||
                                              _activeTool == _EditorCanvasTool.highlighter)
                                          ? _onDrawEnd
                                          : null,
                                      onTapDown: _onCanvasTap,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'view_mode_toggle',
                        onPressed: _toggleViewMode,
                        child: Icon(
                          _isViewMode ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    if (_isLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2.5),
                      ),
                    if (_loadError != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_loadError!, textAlign: TextAlign.center),
                        ),
                      ),
                    if (_isSaving)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x55000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                );
              },
            )
          : const Center(child: Text('PDF file not found.')),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPageNavigationBar(),
          _buildToolBar(),
          _buildToolConfigPanel(),
        ],
      ),
    );
  }
}

class _StrokeOverlayPainter extends CustomPainter {
  _StrokeOverlayPainter({
    required this.strokes,
    required this.activeStroke,
    required this.activeStrokeColor,
    required this.activeStrokeWidth,
    required this.activeStrokeOpacity,
  });

  final List<StrokePath> strokes;
  final List<Offset> activeStroke;
  final Color activeStrokeColor;
  final double activeStrokeWidth;
  final double activeStrokeOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (final StrokePath stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width, stroke.opacity);
    }

    if (activeStroke.length > 1) {
      _drawStroke(
        canvas,
        activeStroke,
        activeStrokeColor,
        activeStrokeWidth,
        activeStrokeOpacity,
      );
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
    double opacity,
  ) {
    if (points.length < 2) {
      return;
    }

    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i += 1) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokeOverlayPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.activeStrokeColor != activeStrokeColor ||
        oldDelegate.activeStrokeWidth != activeStrokeWidth ||
        oldDelegate.activeStrokeOpacity != activeStrokeOpacity;
  }
}
