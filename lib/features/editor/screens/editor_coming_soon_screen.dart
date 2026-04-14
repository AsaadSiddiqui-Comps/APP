import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../camera/models/camera_capture_result.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../../documents/data/document_draft_store.dart';
import '../../documents/models/document_draft.dart';
import '../services/image_edit_service.dart';

class EditorComingSoonScreen extends StatefulWidget {
  const EditorComingSoonScreen({
    super.key,
    required this.initialImages,
    this.initialName,
    this.existingDraftId,
  });

  final List<XFile> initialImages;
  final String? initialName;
  final String? existingDraftId;

  @override
  State<EditorComingSoonScreen> createState() => _EditorComingSoonScreenState();
}

class _EditorComingSoonScreenState extends State<EditorComingSoonScreen> {
  late final PageController _pageController;
  late final TextEditingController _nameController;
  late List<XFile> _pages;
  late List<EditorResizeMode> _resizeModes;

  bool _applyToAllPages = false;
  bool _isProcessing = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = List<XFile>.from(widget.initialImages);
    _resizeModes = List<EditorResizeMode>.filled(
      _pages.length,
      EditorResizeMode.autoFit,
    );

    final String defaultName =
        widget.initialName ??
        'Scan ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    _nameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color panel = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;
    final Color panelLow = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainerLow;
    final Color onSurface = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final Color onSurfaceVariant = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;
    final Color accent = isDark ? const Color(0xFF6E83FF) : AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _editFileName,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: panel,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _nameController.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              color: onSurfaceVariant,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _circleButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: null,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    'Page ${_currentPage + 1} of ${_pages.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: onSurfaceVariant),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        _applyScopeChip(
                          label: 'This page',
                          selected: !_applyToAllPages,
                          accent: accent,
                          onTap: () {
                            setState(() {
                              _applyToAllPages = false;
                            });
                          },
                        ),
                        _applyScopeChip(
                          label: 'All pages',
                          selected: _applyToAllPages,
                          accent: accent,
                          onTap: () {
                            setState(() {
                              _applyToAllPages = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: panelLow,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (int index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return InteractiveViewer(
                          minScale: 0.9,
                          maxScale: 4,
                          child: Image.file(
                            File(_pages[index].path),
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 66,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pages.length,
                itemBuilder: (BuildContext context, int index) {
                  final bool selected = index == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 52,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_pages[index].path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _buildToolsBar(isDark: isDark, accent: accent),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _scanMore,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Scan More'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveAsDraft,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Save Draft'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsBar({required bool isDark, required Color accent}) {
    final List<_ToolAction> tools = <_ToolAction>[
      _ToolAction(
        label: 'Auto',
        icon: Icons.auto_fix_high_rounded,
        onTap: _autoCrop,
      ),
      _ToolAction(
        label: 'Retake',
        icon: Icons.camera_alt_outlined,
        onTap: _retakeCurrent,
      ),
      _ToolAction(
        label: 'Crop',
        icon: Icons.crop_outlined,
        onTap: _cropCurrent,
      ),
      _ToolAction(
        label: 'Rotate',
        icon: Icons.rotate_90_degrees_ccw_rounded,
        onTap: _rotateCurrent,
      ),
      _ToolAction(
        label: 'Filter',
        icon: Icons.auto_awesome_rounded,
        onTap: _showFilters,
      ),
      _ToolAction(
        label: 'Resize',
        icon: Icons.fit_screen_rounded,
        onTap: _showResizeModes,
      ),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final _ToolAction tool = tools[index];
          return InkWell(
            onTap: _isProcessing ? null : tool.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Opacity(
              opacity: _isProcessing ? 0.6 : 1,
              child: SizedBox(
                width: 66,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.darkSurfaceContainerLow
                            : AppColors.lightSurfaceContainerLow,
                        border: Border.all(color: accent.withOpacity(0.28)),
                      ),
                      child: Icon(tool.icon, size: 20),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tool.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: tools.length,
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.lightSurfaceContainer,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }

  Widget _applyScopeChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? accent : null,
          ),
        ),
      ),
    );
  }

  Future<void> _autoCrop() async {
    await _applyEdit(
      actionName: 'Auto crop',
      run: (String path) => ImageEditService.autoCrop(path),
    );
  }

  Future<void> _rotateCurrent() async {
    await _applyEdit(
      actionName: 'Rotate',
      run: (String path) => ImageEditService.rotate90(path),
    );
  }

  Future<void> _cropCurrent() async {
    final double? ratio = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Original (keep most area)'),
                onTap: () => Navigator.of(context).pop(0.72),
              ),
              ListTile(
                title: const Text('A4 ratio'),
                onTap: () => Navigator.of(context).pop(210 / 297),
              ),
              ListTile(
                title: const Text('Square'),
                onTap: () => Navigator.of(context).pop(1),
              ),
              ListTile(
                title: const Text('3:4'),
                onTap: () => Navigator.of(context).pop(3 / 4),
              ),
            ],
          ),
        );
      },
    );

    if (ratio == null) {
      return;
    }

    await _applyEdit(
      actionName: 'Crop',
      run: (String path) => ImageEditService.cropCenterByRatio(path, ratio),
    );
  }

  Future<void> _showFilters() async {
    final EditorFilterType? filter =
        await showModalBottomSheet<EditorFilterType>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: const Text('Enhanced'),
                    subtitle: const Text('Boost contrast and clarity'),
                    onTap: () =>
                        Navigator.of(context).pop(EditorFilterType.enhanced),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_rounded),
                    title: const Text('Pro'),
                    subtitle: const Text(
                      'Sharper details for text-heavy scans',
                    ),
                    onTap: () =>
                        Navigator.of(context).pop(EditorFilterType.pro),
                  ),
                  ListTile(
                    leading: const Icon(Icons.grain_rounded),
                    title: const Text('Greyscale'),
                    onTap: () =>
                        Navigator.of(context).pop(EditorFilterType.grayscale),
                  ),
                  ListTile(
                    leading: const Icon(Icons.document_scanner_rounded),
                    title: const Text('Black & White'),
                    subtitle: const Text('High-contrast for OCR-ready pages'),
                    onTap: () =>
                        Navigator.of(context).pop(EditorFilterType.blackWhite),
                  ),
                ],
              ),
            );
          },
        );

    if (filter == null) {
      return;
    }

    await _applyEdit(
      actionName: 'Filter',
      run: (String path) => ImageEditService.applyFilter(path, filter),
    );
  }

  Future<void> _showResizeModes() async {
    final EditorResizeMode? mode = await showModalBottomSheet<EditorResizeMode>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fit_screen_rounded),
                title: const Text('Auto Fit to Page'),
                onTap: () =>
                    Navigator.of(context).pop(EditorResizeMode.autoFit),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('A4'),
                onTap: () => Navigator.of(context).pop(EditorResizeMode.a4),
              ),
              ListTile(
                leading: const Icon(Icons.photo_size_select_large_rounded),
                title: const Text('A3'),
                onTap: () => Navigator.of(context).pop(EditorResizeMode.a3),
              ),
            ],
          ),
        );
      },
    );

    if (mode == null) {
      return;
    }

    await _applyEdit(
      actionName: 'Resize',
      run: (String path) => ImageEditService.resize(path, mode),
      onEachUpdated: (int index) {
        _resizeModes[index] = mode;
      },
    );
  }

  Future<void> _applyEdit({
    required String actionName,
    required Future<String> Function(String path) run,
    void Function(int index)? onEachUpdated,
  }) async {
    if (_pages.isEmpty || _isProcessing) {
      return;
    }

    final List<int> indexes = _applyToAllPages
        ? List<int>.generate(_pages.length, (int i) => i)
        : <int>[_currentPage];

    setState(() {
      _isProcessing = true;
    });

    try {
      for (final int index in indexes) {
        final String editedPath = await run(_pages[index].path);
        _pages[index] = XFile(editedPath);
        onEachUpdated?.call(index);
      }
      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$actionName applied.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionName failed. Try a different image.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _retakeCurrent() async {
    if (_isProcessing) {
      return;
    }

    final CameraCaptureResult? result = await Navigator.of(context)
        .push<CameraCaptureResult>(
          MaterialPageRoute<CameraCaptureResult>(
            builder: (_) => const CameraCaptureScreen(
              initialBatchMode: false,
              allowModeSwitch: false,
              allowSettings: false,
              allowGalleryImport: false,
              returnCapturesOnly: true,
              openEditorOnSingleCapture: false,
            ),
          ),
        );

    if (!mounted || result == null || result.images.isEmpty) {
      return;
    }

    setState(() {
      _pages[_currentPage] = result.images.first;
    });
  }

  Future<void> _scanMore() async {
    if (_isProcessing) {
      return;
    }

    final CameraCaptureResult? result = await Navigator.of(context)
        .push<CameraCaptureResult>(
          MaterialPageRoute<CameraCaptureResult>(
            builder: (_) => const CameraCaptureScreen(
              initialBatchMode: true,
              allowModeSwitch: false,
              allowSettings: true,
              returnCapturesOnly: true,
              openEditorOnSingleCapture: false,
            ),
          ),
        );

    if (!mounted || result == null || result.images.isEmpty) {
      return;
    }

    setState(() {
      _pages = <XFile>[..._pages, ...result.images];
      _resizeModes = <EditorResizeMode>[
        ..._resizeModes,
        ...List<EditorResizeMode>.filled(
          result.images.length,
          EditorResizeMode.autoFit,
        ),
      ];
      _currentPage = _pages.length - 1;
    });

    await _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _saveAsDraft() async {
    final String name = _nameController.text.trim().isEmpty
        ? 'Untitled scan'
        : _nameController.text.trim();

    final String draftId =
        widget.existingDraftId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final DocumentDraft draft = DocumentDraft(
      id: draftId,
      name: name,
      pagePaths: _pages.map((XFile file) => file.path).toList(growable: false),
      updatedAt: DateTime.now(),
    );

    DocumentDraftStore.instance.upsert(draft);

    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Saved as draft'),
          content: const Text(
            'You can continue this document later from Recent Files.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _editFileName() {
    final TextEditingController tempController = TextEditingController(
      text: _nameController.text,
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: tempController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _nameController.text = tempController.text.trim().isEmpty
                      ? _nameController.text
                      : tempController.text.trim();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _ToolAction {
  const _ToolAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
