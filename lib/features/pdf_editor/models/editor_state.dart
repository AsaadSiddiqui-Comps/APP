import 'dart:ui';

import 'tool_type.dart';

class EditorState {
  const EditorState({
    this.activeTool = ToolType.none,
    this.currentPage = 1,
    this.pageCount = 1,
    this.selectedOperationId,
    this.revision = 0,
    this.strokeWidth = 3.5,
    this.strokeColor = const Color(0xFFEF5350),
    this.highlightColor = const Color(0xFFFFEB3B),
    this.highlightOpacity = 0.35,
    this.textSize = 20,
    this.textColor = const Color(0xFF212121),
    this.isSaving = false,
    this.isBusy = false,
    this.isViewMode = false,
  });

  final ToolType activeTool;
  final int currentPage;
  final int pageCount;
  final String? selectedOperationId;
  final int revision;
  final double strokeWidth;
  final Color strokeColor;
  final Color highlightColor;
  final double highlightOpacity;
  final double textSize;
  final Color textColor;
  final bool isSaving;
  final bool isBusy;
  final bool isViewMode;

  EditorState copyWith({
    ToolType? activeTool,
    int? currentPage,
    int? pageCount,
    String? selectedOperationId,
    bool clearSelectedOperationId = false,
    int? revision,
    double? strokeWidth,
    Color? strokeColor,
    Color? highlightColor,
    double? highlightOpacity,
    double? textSize,
    Color? textColor,
    bool? isSaving,
    bool? isBusy,
    bool? isViewMode,
  }) {
    return EditorState(
      activeTool: activeTool ?? this.activeTool,
      currentPage: currentPage ?? this.currentPage,
      pageCount: pageCount ?? this.pageCount,
      selectedOperationId: clearSelectedOperationId ? null : selectedOperationId ?? this.selectedOperationId,
      revision: revision ?? this.revision,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      highlightColor: highlightColor ?? this.highlightColor,
      highlightOpacity: highlightOpacity ?? this.highlightOpacity,
      textSize: textSize ?? this.textSize,
      textColor: textColor ?? this.textColor,
      isSaving: isSaving ?? this.isSaving,
      isBusy: isBusy ?? this.isBusy,
      isViewMode: isViewMode ?? this.isViewMode,
    );
  }
}
