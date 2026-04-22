import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/editor_state.dart';
import '../models/pdf_edit_operation.dart';
import '../models/tool_type.dart';
import '../services/native_pdf_bridge.dart';
import '../services/pdf_mutation_service.dart';

class EditorController {
  EditorController(this._bridge, {PdfMutationService? mutationService})
      : _mutationService = mutationService ?? PdfMutationService();

  final NativePdfBridge _bridge;
  final PdfMutationService _mutationService;
  final ValueNotifier<EditorState> state = ValueNotifier<EditorState>(const EditorState());

  final List<Map<String, double>> _strokeBuffer = <Map<String, double>>[];
  final List<PdfEditOperation> _operations = <PdfEditOperation>[];
  Timer? _strokeFlushTimer;
  String? _pdfPath;

  Future<void> initialize(String pdfPath) async {
    _pdfPath = pdfPath;
    await _bridge.loadPdf(pdfPath);
    final int count = await _bridge.getPageCount();
    state.value = state.value.copyWith(pageCount: count, currentPage: 1);
  }

  void dispose() {
    _strokeFlushTimer?.cancel();
    state.dispose();
  }

  void setTool(ToolType tool) {
    state.value = state.value.copyWith(activeTool: tool);
  }

  void toggleMode() {
    state.value = state.value.copyWith(isViewMode: !state.value.isViewMode);
  }

  Future<void> goToNextPage() async {
    final int next = (state.value.currentPage + 1).clamp(1, state.value.pageCount);
    await _setPage(next);
  }

  Future<void> goToPreviousPage() async {
    final int prev = (state.value.currentPage - 1).clamp(1, state.value.pageCount);
    await _setPage(prev);
  }

  Future<void> _setPage(int page) async {
    if (page == state.value.currentPage) {
      return;
    }
    await _bridge.setCurrentPage(page);
    state.value = state.value.copyWith(currentPage: page);
  }

  void setStrokeWidth(double width) {
    state.value = state.value.copyWith(strokeWidth: width);
  }

  void setStrokeColor(Color color) {
    state.value = state.value.copyWith(strokeColor: color);
  }

  void setHighlightColor(Color color) {
    state.value = state.value.copyWith(highlightColor: color);
  }

  void setHighlightOpacity(double opacity) {
    state.value = state.value.copyWith(highlightOpacity: opacity);
  }

  void setTextColor(Color color) {
    state.value = state.value.copyWith(textColor: color);
  }

  void setTextSize(double size) {
    state.value = state.value.copyWith(textSize: size);
  }

  void onStrokeStart(Offset p) {
    _strokeBuffer.clear();
    _strokeBuffer.add(<String, double>{'x': p.dx, 'y': p.dy});
    _ensureFlushTimer();
  }

  Future<void> onStrokeUpdate(Offset p) async {
    _strokeBuffer.add(<String, double>{'x': p.dx, 'y': p.dy});
    if (_strokeBuffer.length >= 8) {
      await _flushStrokeBatch();
    }
  }

  Future<void> onStrokeEnd() async {
    await _flushStrokeBatch();
    _strokeFlushTimer?.cancel();
    _strokeFlushTimer = null;
  }

  void _ensureFlushTimer() {
    _strokeFlushTimer ??= Timer.periodic(const Duration(milliseconds: 14), (_) {
      _flushStrokeBatch();
    });
  }

  Future<void> _flushStrokeBatch() async {
    if (_strokeBuffer.length < 2) {
      return;
    }

    final List<Map<String, double>> payload = List<Map<String, double>>.from(_strokeBuffer);
    _strokeBuffer.clear();

    final EditorState s = state.value;
    final bool isHighlight = s.activeTool == ToolType.highlight;
    await _bridge.drawStroke(
      payload,
      (isHighlight ? s.highlightColor : s.strokeColor).toARGB32(),
      isHighlight ? (s.strokeWidth + 4) : s.strokeWidth,
    );

    _operations.add(
      PdfStrokeOperation(
        page: s.currentPage,
        points: payload
            .map((Map<String, double> point) => Offset(point['x'] ?? 0, point['y'] ?? 0))
            .toList(growable: false),
        color: isHighlight ? s.highlightColor : s.strokeColor,
        strokeWidth: isHighlight ? (s.strokeWidth + 4) : s.strokeWidth,
      ),
    );
  }

  Future<void> addHighlightRect(Rect rect) async {
    await _bridge.addHighlight(<String, dynamic>{
      'x': rect.left,
      'y': rect.top,
      'w': rect.width,
      'h': rect.height,
      'color': state.value.highlightColor.toARGB32(),
      'opacity': state.value.highlightOpacity,
    });
    _operations.add(
      PdfHighlightOperation(
        page: state.value.currentPage,
        rect: rect,
        color: state.value.highlightColor,
        opacity: state.value.highlightOpacity,
      ),
    );
  }

  Future<void> addText(String text, Offset p) async {
    final color = state.value.textColor.value;
    final fontSize = state.value.textSize;
    await _bridge.addText(text, p.dx, p.dy, color: color, fontSize: fontSize);
    _operations.add(
      PdfTextOperation(
        page: state.value.currentPage,
        text: text,
        position: p,
        color: state.value.textColor,
        fontSize: state.value.textSize,
      ),
    );
  }

  Future<void> addImage(String path, Offset p) async {
    const imageSize = Size(180, 180);
    await _bridge.addImage(path, p.dx, p.dy, width: imageSize.width, height: imageSize.height);
    _operations.add(
      PdfImageOperation(
        page: state.value.currentPage,
        path: path,
        position: p,
        size: imageSize,
      ),
    );
  }

  Future<void> addPage() async {
    await _bridge.addPage(afterPage: state.value.currentPage);
    _operations.add(PdfInsertPageOperation(page: state.value.currentPage, afterPage: state.value.currentPage));
    final int count = await _bridge.getPageCount();
    state.value = state.value.copyWith(pageCount: count);
  }

  Future<String> save() async {
    state.value = state.value.copyWith(isSaving: true);
    try {
      final String sourcePath = _pdfPath ?? '';
      if (sourcePath.isEmpty) {
        return '';
      }

      final String outputPath = await _mutationService.saveDocument(
        sourcePath: sourcePath,
        operations: List<PdfEditOperation>.from(_operations),
      );
      _pdfPath = outputPath;
      await _bridge.loadPdf(outputPath);
      final int count = await _bridge.getPageCount();
      state.value = state.value.copyWith(pageCount: count, currentPage: 1);
      _operations.clear();
      return outputPath;
    } finally {
      state.value = state.value.copyWith(isSaving: false);
    }
  }
}
