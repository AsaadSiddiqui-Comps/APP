import 'dart:collection';
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

  UnmodifiableListView<PdfEditOperation> get operations => UnmodifiableListView<PdfEditOperation>(_operations);

  List<PdfEditOperation> operationsForPage(int page) =>
      _operations.where((PdfEditOperation op) => op.page == page).toList(growable: false);

  PdfEditOperation? operationById(String id) {
    for (final PdfEditOperation operation in _operations) {
      if (operation.id == id) {
        return operation;
      }
    }
    return null;
  }

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
    if (tool == ToolType.draw || tool == ToolType.highlight) {
      selectOperation(null);
    }
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
    _appendInterpolatedStrokePoint(p);
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

  void _appendInterpolatedStrokePoint(Offset nextPoint) {
    if (_strokeBuffer.isEmpty) {
      _strokeBuffer.add(<String, double>{'x': nextPoint.dx, 'y': nextPoint.dy});
      return;
    }

    final Map<String, double> previousMap = _strokeBuffer.last;
    final Offset previous = Offset(previousMap['x'] ?? nextPoint.dx, previousMap['y'] ?? nextPoint.dy);
    final double distance = (nextPoint - previous).distance;
    final int steps = distance <= 0 ? 1 : (distance / 2.25).ceil().clamp(1, 24);
    for (int index = 1; index <= steps; index += 1) {
      final double t = index / steps;
      final double x = previous.dx + ((nextPoint.dx - previous.dx) * t);
      final double y = previous.dy + ((nextPoint.dy - previous.dy) * t);
      _strokeBuffer.add(<String, double>{'x': x, 'y': y});
    }
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
        id: _nextId(),
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
        id: _nextId(),
        page: state.value.currentPage,
        rect: rect,
        color: state.value.highlightColor,
        opacity: state.value.highlightOpacity,
      ),
    );
  }

  Future<void> addText(String text, Offset p) async {
    final color = state.value.textColor.toARGB32();
    final fontSize = state.value.textSize;
    await _bridge.addText(text, p.dx, p.dy, color: color, fontSize: fontSize);
    _operations.add(
      PdfTextOperation(
        id: _nextId(),
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
        id: _nextId(),
        page: state.value.currentPage,
        path: path,
        position: p,
        size: imageSize,
      ),
    );
  }

  Future<void> addPage() async {
    await _bridge.addPage(afterPage: state.value.currentPage);
    _operations.add(PdfInsertPageOperation(id: _nextId(), page: state.value.currentPage, afterPage: state.value.currentPage));
    final int count = await _bridge.getPageCount();
    state.value = state.value.copyWith(pageCount: count);
  }

  void selectOperation(String? operationId) {
    state.value = state.value.copyWith(selectedOperationId: operationId, clearSelectedOperationId: operationId == null);
  }

  Future<void> deleteSelectedOperation() async {
    final String? selectedId = state.value.selectedOperationId;
    if (selectedId == null) {
      return;
    }

    final PdfEditOperation? operation = operationById(selectedId);
    if (operation == null) {
      selectOperation(null);
      return;
    }

    _operations.removeWhere((PdfEditOperation op) => op.id == selectedId);
    if (operation is PdfTextOperation) {
      await _bridge.deleteText(operation.id);
    } else if (operation is PdfImageOperation) {
      await _bridge.deleteImage(operation.id);
    }
    selectOperation(null);
    _refreshPreviewForCurrentPage();
  }

  Future<void> moveSelectedOperation(Offset delta) async {
    final String? selectedId = state.value.selectedOperationId;
    if (selectedId == null || delta == Offset.zero) {
      return;
    }

    final PdfEditOperation? operation = operationById(selectedId);
    if (operation is PdfTextOperation) {
      final PdfTextOperation updated = PdfTextOperation(
        id: operation.id,
        page: operation.page,
        text: operation.text,
        position: operation.position + delta,
        color: operation.color,
        fontSize: operation.fontSize,
      );
      _replaceOperation(updated);
      await _bridge.updateText(
        updated.id,
        updated.position.dx,
        updated.position.dy,
        color: updated.color.toARGB32(),
        fontSize: updated.fontSize,
        text: updated.text,
      );
      _refreshPreviewForCurrentPage();
      return;
    }

    if (operation is PdfImageOperation) {
      final PdfImageOperation updated = PdfImageOperation(
        id: operation.id,
        page: operation.page,
        path: operation.path,
        position: operation.position + delta,
        size: operation.size,
      );
      _replaceOperation(updated);
      await _bridge.updateImage(
        updated.id,
        updated.position.dx,
        updated.position.dy,
        width: updated.size.width,
        height: updated.size.height,
        path: updated.path,
      );
      _refreshPreviewForCurrentPage();
    }
  }

  Future<void> resizeSelectedOperation(Offset delta, {required bool fromImage}) async {
    final String? selectedId = state.value.selectedOperationId;
    if (selectedId == null) {
      return;
    }

    final PdfEditOperation? operation = operationById(selectedId);
    if (fromImage && operation is PdfImageOperation) {
      final Size nextSize = Size(
        (operation.size.width + delta.dx).clamp(40.0, 1200.0),
        (operation.size.height + delta.dy).clamp(40.0, 1200.0),
      );
      final PdfImageOperation updated = PdfImageOperation(
        id: operation.id,
        page: operation.page,
        path: operation.path,
        position: operation.position,
        size: nextSize,
      );
      _replaceOperation(updated);
      await _bridge.updateImage(
        updated.id,
        updated.position.dx,
        updated.position.dy,
        width: updated.size.width,
        height: updated.size.height,
        path: updated.path,
      );
      _refreshPreviewForCurrentPage();
      return;
    }

    if (!fromImage && operation is PdfTextOperation) {
      final double nextFontSize = (operation.fontSize + delta.dy / 4).clamp(12.0, 72.0);
      final PdfTextOperation updated = PdfTextOperation(
        id: operation.id,
        page: operation.page,
        text: operation.text,
        position: operation.position,
        color: operation.color,
        fontSize: nextFontSize,
      );
      _replaceOperation(updated);
      await _bridge.updateText(
        updated.id,
        updated.position.dx,
        updated.position.dy,
        color: updated.color.toARGB32(),
        fontSize: updated.fontSize,
        text: updated.text,
      );
      _refreshPreviewForCurrentPage();
    }
  }

  void _replaceOperation(PdfEditOperation updatedOperation) {
    final int index = _operations.indexWhere((PdfEditOperation op) => op.id == updatedOperation.id);
    if (index >= 0) {
      _operations[index] = updatedOperation;
      state.value = state.value.copyWith(selectedOperationId: updatedOperation.id);
    }
  }

  void _refreshPreviewForCurrentPage() {
    state.value = state.value.copyWith(revision: state.value.revision + 1);
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

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
