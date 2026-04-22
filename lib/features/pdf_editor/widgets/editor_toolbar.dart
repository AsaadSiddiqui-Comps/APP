import 'package:flutter/material.dart';

import '../models/tool_type.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.activeTool,
    required this.onToolSelected,
    required this.onSave,
    required this.onAddPage,
  });

  final ToolType activeTool;
  final ValueChanged<ToolType> onToolSelected;
  final VoidCallback onSave;
  final VoidCallback onAddPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(context, ToolType.draw, Icons.draw_rounded, 'Draw'),
            _chip(context, ToolType.highlight, Icons.highlight_alt_rounded, 'Highlight'),
            _chip(context, ToolType.text, Icons.text_fields_rounded, 'Text'),
            _chip(context, ToolType.image, Icons.image_outlined, 'Image'),
            _chip(context, ToolType.addPage, Icons.note_add_outlined, 'Add Page', onTap: onAddPage),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ToolType tool,
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: activeTool == tool,
        showCheckmark: false,
        avatar: Icon(icon, size: 18),
        label: Text(text),
        onSelected: (_) {
          onToolSelected(tool);
          onTap?.call();
        },
      ),
    );
  }
}
