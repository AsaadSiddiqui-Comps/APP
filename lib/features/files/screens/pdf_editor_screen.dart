import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/native_drawing_service.dart';
import '../../documents/data/document_storage_service.dart';
import '../models/pdf_edit_models.dart';
import '../widgets/editor_tool_panel.dart';
import '../widgets/native_accelerated_drawing_canvas.dart';

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

  int _pageCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _chromeVisible = true;
  bool _toolMenuOpen = false;
  String? _loadError;

  EditorTool _activeTool = EditorTool.none;
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

  final List<StrokePath> _strokes = <StrokePath>[];
  final List<TextOverlay> _textOverlays = <TextOverlay>[];
  final List<EditorAction> _undoStack = <EditorAction>[];
  final List<EditorAction> _redoStack = <EditorAction>[];
  List<Offset> _activeStrokePoints = <Offset>[];
  List<StrokePath>? _eraseBeforeSnapshot;
  bool _annotationDirty = false;
  bool _overlayDirty = false;
  Size _overlaySize = const Size(1, 1);

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverlayData();
      _prepareNativeRenderer();
    });
  }

  @override
  void dispose() {
    _overlayTick.dispose();
    super.dispose();
  }

  bool get _hasUnsavedEdits => _annotationDirty || _overlayDirty;

  String _sidecarPathFor(String pdfPath) => '$pdfPath.docly_overlay.json';

  Future<void> _prepareNativeRenderer() async {
    if (!mounted) {
      return;
    }
    final Size size = _overlaySize;
    if (size.width <= 1 || size.height <= 1) {
      return;
    }
    await NativeDrawingService.initializeDrawingContext(
      width: size.width.toInt(),
      height: size.height.toInt(),
    );
  }

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
      final double targetWidth = _overlaySize.width > 1 ? _overlaySize.width : baseWidth;
      final double targetHeight = _overlaySize.height > 1 ? _overlaySize.height : baseHeight;

      final List<dynamic> strokesRaw = map['strokes'] as List<dynamic>? ?? <dynamic>[];
      final List<dynamic> textsRaw = map['texts'] as List<dynamic>? ?? <dynamic>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _strokes
          ..clear()
          ..addAll(
            strokesRaw.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> e) {
              final List<dynamic> pointsRaw = e['points'] as List<dynamic>? ?? <dynamic>[];
              return StrokePath(
                points: pointsRaw
                    .whereType<Map<dynamic, dynamic>>()
                    .map((Map<dynamic, dynamic> p) {
                      final double nx = (p['x'] as num?)?.toDouble() ?? 0;
                      final double ny = (p['y'] as num?)?.toDouble() ?? 0;
                      return Offset(nx * targetWidth, ny * targetHeight);
                    })
                    .toList(growable: false),
                color: Color((e['color'] as num?)?.toInt() ?? Colors.red.toARGB32()),
                width: (e['width'] as num?)?.toDouble() ?? 4,
                opacity: (e['opacity'] as num?)?.toDouble() ?? 1,
              );
            }).toList(growable: false),
          );

        _textOverlays
          ..clear()
          ..addAll(
            textsRaw.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> e) {
              final double nx = (e['x'] as num?)?.toDouble() ?? 0;
              final double ny = (e['y'] as num?)?.toDouble() ?? 0;
              final String alignName = (e['align'] as String?) ?? 'left';
              final TextAlign align = TextAlign.values.firstWhere(
                (TextAlign t) => t.name == alignName,
                orElse: () => TextAlign.left,
              );
              return TextOverlay(
                text: (e['text'] as String?) ?? '',
                position: Offset(nx * targetWidth, ny * targetHeight),
                textColor: Color((e['textColor'] as num?)?.toInt() ?? Colors.white.toARGB32()),
                backgroundColor: Color((e['bgColor'] as num?)?.toInt() ?? Colors.transparent.toARGB32()),
                fontSize: (e['fontSize'] as num?)?.toDouble() ?? 22,
                fontFamily: (e['font'] as String?) ?? 'Roboto',
                textAlign: align,
              );
            }).toList(growable: false),
          );
        _overlayDirty = false;
      });
      _overlayTick.value += 1;
    } catch (_) {
      // ignore overlay parse issues
    }
  }

  Future<void> _persistOverlayData(String targetPdfPath) async {
    final double width = _overlaySize.width <= 0 ? 1 : _overlaySize.width;
    final double height = _overlaySize.height <= 0 ? 1 : _overlaySize.height;

    final Map<String, dynamic> payload = <String, dynamic>{
      'canvasWidth': width,
      'canvasHeight': height,
      'strokes': _strokes
          .map(
            (StrokePath s) => <String, dynamic>{
              'color': s.color.toARGB32(),
              'width': s.width,
              'opacity': s.opacity,
              'points': s.points
                  .map((Offset p) => <String, dynamic>{
                        'x': p.dx / width,
                        'y': p.dy / height,
                      })
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'texts': _textOverlays
          .map(
            (TextOverlay t) => <String, dynamic>{
              'text': t.text,
              'x': t.position.dx / width,
              'y': t.position.dy / height,
              'textColor': t.textColor.toARGB32(),
              'bgColor': t.backgroundColor.toARGB32(),
              'fontSize': t.fontSize,
              'font': t.fontFamily,
              'align': t.textAlign.name,
            },
          )
          .toList(growable: false),
    };

    final File sidecar = File(_sidecarPathFor(targetPdfPath));
    if (_strokes.isEmpty && _textOverlays.isEmpty) {
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
      return;
    }

    await sidecar.writeAsString(jsonEncode(payload));
  }

  Future<void> _showSaveDialog() async {
    if (!_hasUnsavedEdits) {
      Navigator.of(context).pop();
      return;
    }

    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Save as Copy'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
              ListTile(
                leading: const Icon(Icons.save_rounded),
                title: const Text('Save as Original'),
                onTap: () => Navigator.of(context).pop('original'),
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

    if (action == 'copy') {
      await _saveEdits(saveAsCopy: true);
    } else if (action == 'original') {
      await _saveEdits(saveAsCopy: false);
    }
  }

  Future<void> _saveEdits({required bool saveAsCopy}) async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<int> savedBytes = await _controller.saveDocument();
      if (saveAsCopy) {
        final Directory exportDir = await DocumentStorageService.instance.getExportedDir();
        final String now = DateTime.now().millisecondsSinceEpoch.toString();
        final String fileName = _buildCopyFileName(now);
        final String tempPath = '${exportDir.path}${Platform.pathSeparator}$fileName';

        await File(tempPath).writeAsBytes(savedBytes, flush: true);
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
        await _persistOverlayData(finalPath);
      } else {
        final File target = File(widget.pdfPath);
        await target.writeAsBytes(savedBytes, flush: true);
        await DocumentStorageService.instance.scanFile(widget.pdfPath);
        await _persistOverlayData(widget.pdfPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully.')),
        );
      }
      setState(() {
        _annotationDirty = false;
        _overlayDirty = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save PDF edits.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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

  void _setActiveTool(EditorTool tool) {
    setState(() {
      _activeTool = tool;
      _toolMenuOpen = false;
      if (_activeTool == EditorTool.highlighter) {
        _applyHighlighterSettings();
      } else {
        _controller.annotationMode = PdfAnnotationMode.none;
      }
    });
  }

  void _applyHighlighterSettings() {
    final PdfAnnotationSettings settings = _controller.annotationSettings;
    final double opacity = _highlightOpacity.clamp(0.1, 1.0);
    settings.highlight..color = _highlightColor..opacity = opacity;
    settings.underline..color = _highlightColor..opacity = opacity;
    settings.strikethrough..color = _highlightColor..opacity = opacity;
    settings.squiggly..color = _highlightColor..opacity = opacity;

    switch (_highlightMode) {
      case HighlightMode.highlight:
        _controller.annotationMode = PdfAnnotationMode.highlight;
      case HighlightMode.underline:
        _controller.annotationMode = PdfAnnotationMode.underline;
      case HighlightMode.strike:
        _controller.annotationMode = PdfAnnotationMode.strikethrough;
      case HighlightMode.squiggly:
        _controller.annotationMode = PdfAnnotationMode.squiggly;
    }
  }

  void _toggleChrome() {
    if (!mounted || _activeTool != EditorTool.none) {
      return;
    }
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _setChromeVisible(bool visible) {
    if (!mounted || _chromeVisible == visible) {
      return;
    }
    setState(() => _chromeVisible = visible);
  }

  void _pushAction(EditorAction action) {
    _undoStack.add(action);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final EditorAction action = _undoStack.removeLast();
    action.undo();
    _redoStack.add(action);
    _overlayTick.value += 1;
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final EditorAction action = _redoStack.removeLast();
    action.redo();
    _undoStack.add(action);
    _overlayTick.value += 1;
    setState(() {});
  }

  void _onDrawStart(DragStartDetails details) {
    if (_activeTool != EditorTool.draw) return;
    if (_drawMode == DrawMode.eraser) {
      _eraseBeforeSnapshot = _cloneStrokes(_strokes);
      _eraseAt(details.localPosition);
    } else {
      _activeStrokePoints = <Offset>[details.localPosition];
    }
    _overlayTick.value += 1;
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    if (_activeTool != EditorTool.draw) return;
    if (_drawMode == DrawMode.eraser) {
      _eraseAt(details.localPosition);
    } else {
      _activeStrokePoints.add(details.localPosition);
    }
    _overlayTick.value += 1;
  }

  void _onDrawEnd(DragEndDetails details) {
    if (_activeTool != EditorTool.draw) return;

    if (_drawMode == DrawMode.eraser) {
      final List<StrokePath> before = _eraseBeforeSnapshot ?? <StrokePath>[];
      _eraseBeforeSnapshot = null;
      final List<StrokePath> after = _cloneStrokes(_strokes);
      if (!_strokesEquals(before, after)) {
        _pushAction(EditorAction(
          undo: () {
            _strokes
              ..clear()
              ..addAll(_cloneStrokes(before));
          },
          redo: () {
            _strokes
              ..clear()
              ..addAll(_cloneStrokes(after));
          },
        ));
        _overlayDirty = true;
      }
      _overlayTick.value += 1;
      setState(() {});
      return;
    }

    if (_activeStrokePoints.length < 2) {
      _activeStrokePoints = <Offset>[];
      _overlayTick.value += 1;
      return;
    }

    final StrokePath stroke = StrokePath(
      points: List<Offset>.from(_activeStrokePoints),
      color: _drawColor,
      width: _drawWidth,
      opacity: _drawOpacity,
    );
    _strokes.add(stroke);
    _pushAction(EditorAction(
      undo: () => _strokes.remove(stroke),
      redo: () => _strokes.add(stroke),
    ));
    _overlayDirty = true;
    _activeStrokePoints = <Offset>[];
    _overlayTick.value += 1;
    setState(() {});
  }

  void _eraseAt(Offset point) {
    final double threshold = _eraserSize.clamp(6, 80);
    final List<StrokePath> rebuilt = <StrokePath>[];

    for (final StrokePath stroke in _strokes) {
      final List<List<Offset>> segments = <List<Offset>>[];
      List<Offset> current = <Offset>[];
      for (final Offset p in stroke.points) {
        final bool keep = (p - point).distance > threshold;
        if (keep) {
          current.add(p);
        } else {
          if (current.length > 1) {
            segments.add(current);
          }
          current = <Offset>[];
        }
      }
      if (current.length > 1) {
        segments.add(current);
      }
      for (final List<Offset> segment in segments) {
        rebuilt.add(StrokePath(points: segment, color: stroke.color, width: stroke.width, opacity: stroke.opacity));
      }
    }

    _strokes
      ..clear()
      ..addAll(rebuilt);
  }

  List<StrokePath> _cloneStrokes(List<StrokePath> source) => source
      .map((StrokePath s) => StrokePath(
            points: List<Offset>.from(s.points),
            color: s.color,
            width: s.width,
            opacity: s.opacity,
          ))
      .toList(growable: false);

  bool _strokesEquals(List<StrokePath> a, List<StrokePath> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i += 1) {
      final StrokePath sa = a[i];
      final StrokePath sb = b[i];
      if (sa.color != sb.color || sa.width != sb.width || sa.opacity != sb.opacity || sa.points.length != sb.points.length) {
        return false;
      }
    }
    return true;
  }

  Future<void> _onTextTap(TapDownDetails details) async {
    if (_activeTool != EditorTool.text || !mounted) return;
    final TextEditingController inputController = TextEditingController();
    final String? text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: inputController,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Enter text', hintText: 'Type text to place on PDF'),
                onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(inputController.text.trim()),
                  child: const Text('Add Text'),
                ),
              ),
            ],
          ),
        );
      },
    );
    inputController.dispose();
    if (text == null || text.isEmpty) return;

    final TextOverlay item = TextOverlay(
      text: text,
      position: details.localPosition,
      textColor: _textColor,
      backgroundColor: _textBackground,
      fontSize: _textSize,
      fontFamily: _textFont,
      textAlign: _textAlign,
    );
    _textOverlays.add(item);
    _pushAction(EditorAction(
      undo: () => _textOverlays.remove(item),
      redo: () => _textOverlays.add(item),
    ));
    _overlayDirty = true;
    _overlayTick.value += 1;
    setState(() {});
  }

  PreferredSizeWidget _buildAppBar() {
    if (!_chromeVisible) {
      return AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Show controls',
            onPressed: () => setState(() => _chromeVisible = true),
            icon: const Icon(Icons.visibility_rounded),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Undo',
          onPressed: _undoStack.isEmpty ? null : _undo,
          icon: const Icon(Icons.undo_rounded),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: _redoStack.isEmpty ? null : _redo,
          icon: const Icon(Icons.redo_rounded),
        ),
        IconButton(
          tooltip: 'Zoom out',
          onPressed: () => _controller.zoomLevel = (_controller.zoomLevel - 0.25).clamp(1.0, 5.0),
          icon: const Icon(Icons.zoom_out_rounded),
        ),
        IconButton(
          tooltip: 'Zoom in',
          onPressed: () => _controller.zoomLevel = (_controller.zoomLevel + 0.25).clamp(1.0, 5.0),
          icon: const Icon(Icons.zoom_in_rounded),
        ),
        IconButton(
          tooltip: 'Save',
          onPressed: _hasUnsavedEdits ? _showSaveDialog : null,
          icon: const Icon(Icons.save_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'tool_highlighter') {
              _setActiveTool(EditorTool.highlighter);
            } else if (value == 'tool_draw') {
              _drawMode = DrawMode.pen;
              _setActiveTool(EditorTool.draw);
            } else if (value == 'tool_eraser') {
              _drawMode = DrawMode.eraser;
              _setActiveTool(EditorTool.draw);
            } else if (value == 'tool_text') {
              _setActiveTool(EditorTool.text);
            } else if (value == 'tool_none') {
              _setActiveTool(EditorTool.none);
            } else if (value == 'close') {
              if (_hasUnsavedEdits) {
                _showSaveDialog();
              } else {
                Navigator.of(context).pop();
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'tool_highlighter', child: Text('Highlighter')),
            const PopupMenuItem<String>(value: 'tool_draw', child: Text('Draw')),
            const PopupMenuItem<String>(value: 'tool_eraser', child: Text('Eraser')),
            const PopupMenuItem<String>(value: 'tool_text', child: Text('Add Text')),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'tool_none', child: Text('Exit Editor')),
            const PopupMenuItem<String>(value: 'close', child: Text('Close')),
          ],
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _activeTool == EditorTool.none || _activeTool == EditorTool.highlighter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _activeTool == EditorTool.draw ? _onDrawStart : null,
          onPanUpdate: _activeTool == EditorTool.draw ? _onDrawUpdate : null,
          onPanEnd: _activeTool == EditorTool.draw ? _onDrawEnd : null,
          onTapDown: _activeTool == EditorTool.text ? _onTextTap : null,
          child: NativeAcceleratedDrawingCanvas(
            strokes: _strokes,
            textItems: _textOverlays,
            activeStroke: _activeStrokePoints,
            activeStrokeColor: _drawColor,
            activeStrokeWidth: _drawWidth,
            activeStrokeOpacity: _drawOpacity,
            onDrawComplete: () => _overlayTick.value += 1,
            repaint: _overlayTick,
          ),
        ),
      ),
    );
  }

  Widget? _buildActiveToolPanel() {
    if (_activeTool == EditorTool.none || !_chromeVisible) {
      return null;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panel = isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurfaceContainer;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: panel.withValues(alpha: 0.97),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: _activeTool == EditorTool.highlighter
            ? EditorToolPanel.buildHighlighterPanel(
                highlightMode: _highlightMode,
                highlightColor: _highlightColor,
                highlightOpacity: _highlightOpacity,
                onColorChanged: (Color c) => setState(() { _highlightColor = c; _applyHighlighterSettings(); }),
                onOpacityChanged: (double v) => setState(() { _highlightOpacity = v; _applyHighlighterSettings(); }),
                onModeChanged: (HighlightMode v) => setState(() { _highlightMode = v; _applyHighlighterSettings(); }),
              )
            : _activeTool == EditorTool.draw
                ? EditorToolPanel.buildDrawPanel(
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
                  )
                : EditorToolPanel.buildTextPanel(
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
                  ),
      ),
    );
  }

  Future<void> _openEditorOnScreen() async {
    // not used in editor screen
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: File(widget.pdfPath).existsSync()
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                _overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    SfPdfViewer.file(
                      File(widget.pdfPath),
                      controller: _controller,
                      canShowPaginationDialog: false,
                      canShowScrollHead: false,
                      canShowPageLoadingIndicator: true,
                      canShowScrollStatus: false,
                      interactionMode: PdfInteractionMode.pan,
                      enableTextSelection: _activeTool == EditorTool.highlighter,
                      enableDoubleTapZooming: true,
                      maxZoomLevel: 5,
                      pageSpacing: 2,
                      onTap: (_) => _toggleChrome(),
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = false;
                          _loadError = null;
                          _pageCount = details.document.pages.count;
                        });
                        _prepareNativeRenderer();
                      },
                      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                        if (!mounted) return;
                        setState(() {
                          _isLoading = false;
                          _loadError = details.description;
                        });
                      },
                      onPageChanged: (PdfPageChangedDetails details) {
                        if (!mounted) return;
                        if (details.newPageNumber > details.oldPageNumber) {
                          _setChromeVisible(false);
                        } else {
                          _setChromeVisible(true);
                        }
                      },
                    ),
                    _buildOverlay(),
                    if (_isLoading)
                      const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2.5)),
                    if (_loadError != null)
                      Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_loadError!, textAlign: TextAlign.center))),
                    if (_isSaving)
                      const Positioned.fill(child: ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator()))),
                    if (_chromeVisible)
                      Positioned(
                        right: 14,
                        bottom: _activeTool == EditorTool.none ? 18 : 210,
                        child: FloatingActionButton.small(
                          heroTag: 'pdf_editor_fab',
                          onPressed: () => setState(() => _toolMenuOpen = !_toolMenuOpen),
                          child: Icon(_toolMenuOpen ? Icons.close_rounded : Icons.edit_note_rounded),
                        ),
                      ),
                    if (_chromeVisible && _toolMenuOpen)
                      Positioned(
                        right: 14,
                        bottom: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildToolChip('Highlighter', Icons.highlight_alt_rounded, () => _setActiveTool(EditorTool.highlighter)),
                            const SizedBox(height: 8),
                            _buildToolChip('Draw', Icons.draw_rounded, () { _drawMode = DrawMode.pen; _setActiveTool(EditorTool.draw); }),
                            const SizedBox(height: 8),
                            _buildToolChip('Eraser', Icons.auto_fix_off_rounded, () { _drawMode = DrawMode.eraser; _setActiveTool(EditorTool.draw); }),
                            const SizedBox(height: 8),
                            _buildToolChip('Text', Icons.text_fields_rounded, () => _setActiveTool(EditorTool.text)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            )
          : const Center(child: Text('PDF file not found.')),
      bottomNavigationBar: _buildActiveToolPanel(),
    );
  }

  Widget _buildToolChip(String label, IconData icon, VoidCallback onTap) {
    return FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
  }
}
