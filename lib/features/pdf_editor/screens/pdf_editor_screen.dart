import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';
import '../models/editor_state.dart';
import '../models/tool_type.dart';
import '../services/native_pdf_bridge.dart';
import '../widgets/canvas_gesture_layer.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/native_pdf_surface.dart';
import '../widgets/tool_config_panel.dart';

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
  late final EditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(NativePdfBridge());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize(widget.pdfPath);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final String path = await _controller.save();
    if (!mounted) {
      return;
    }
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed on native layer.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${File(path).uri.pathSegments.last}')),
    );
  }

  Future<void> _onCanvasTap(Offset p, ToolType tool) async {
    if (tool == ToolType.text) {
      final TextEditingController textController = TextEditingController();
      final String? text = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Text'),
                  onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(textController.text.trim()),
                    child: const Text('Insert text'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      textController.dispose();
      if (text != null && text.trim().isNotEmpty) {
        await _controller.addText(text.trim(), p);
      }
      return;
    }

    if (tool == ToolType.image) {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }
      await _controller.addImage(result.files.first.path!, p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorState>(
      valueListenable: _controller.state,
      builder: (BuildContext context, EditorState state, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              IconButton(
                tooltip: 'Save',
                onPressed: state.isSaving ? null : _onSave,
                icon: const Icon(Icons.save_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'copy') {
                    _onSave();
                  }
                  if (value == 'reset') {
                    _controller.setTool(ToolType.none);
                  }
                },
                itemBuilder: (BuildContext context) => const [
                  PopupMenuItem<String>(value: 'copy', child: Text('Save as copy')),
                  PopupMenuItem<String>(value: 'reset', child: Text('Reset draft state')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: NativePdfSurface()),
                    Positioned.fill(
                      child: CanvasGestureLayer(
                        activeTool: state.activeTool,
                        onStrokeStart: _controller.onStrokeStart,
                        onStrokeUpdate: _controller.onStrokeUpdate,
                        onStrokeEnd: _controller.onStrokeEnd,
                        onHighlightRect: _controller.addHighlightRect,
                        onTap: (Offset p) => _onCanvasTap(p, state.activeTool),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            'Page ${state.currentPage} / ${state.pageCount}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4))),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _controller.goToPreviousPage,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Previous'),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('Page ${state.currentPage} of ${state.pageCount}'),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _controller.goToNextPage,
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'),
                    ),
                  ],
                ),
              ),
              ToolConfigPanel(
                state: state,
                onStrokeWidthChanged: _controller.setStrokeWidth,
                onStrokeColorChanged: _controller.setStrokeColor,
                onHighlightColorChanged: _controller.setHighlightColor,
                onHighlightOpacityChanged: _controller.setHighlightOpacity,
                onTextColorChanged: _controller.setTextColor,
                onTextSizeChanged: _controller.setTextSize,
              ),
              EditorToolbar(
                activeTool: state.activeTool,
                onToolSelected: _controller.setTool,
                onSave: _onSave,
                onAddPage: _controller.addPage,
              ),
            ],
          ),
        );
      },
    );
  }
}
