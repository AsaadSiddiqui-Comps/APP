import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';

import '../../../core/constants/app_colors.dart';
import '../../camera/models/camera_capture_result.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../../documents/data/document_draft_store.dart';
import '../../documents/data/document_storage_service.dart';
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

class _EditorComingSoonScreenState extends State<EditorComingSoonScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final TextEditingController _nameController;
  late List<XFile> _pages;
  late List<EditorResizeMode> _resizeModes;

  bool _applyToAllPages = false;
  bool _isProcessing = false;
  int _currentPage = 0;

  bool _isCropMode = false;
  bool _isAutoCropMode = false;
  int _cropTargetIndex = 0;
  NormalizedQuad? _cropQuad;
  Size? _cropImageSize;

  bool _showFilterStrip = false;
  EditorFilterType _activeFilterSelection = EditorFilterType.none;
  final Map<int, EditorFilterType> _appliedFilterByPage =
      <int, EditorFilterType>{};
  final Map<int, String> _filterOriginalPaths = <int, String>{};

  final Map<int, String> _autoOriginalPaths = <int, String>{};

  int _previewGenerationToken = 0;
  Map<EditorFilterType, String> _filterPreviewPaths =
      <EditorFilterType, String>{};

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

    _prepareFilterPreviews();
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
            if (_isCropMode) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildInlineCropBar(accent: accent),
              ),
            ],
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
                      physics: _isCropMode
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      onPageChanged: (int index) {
                        setState(() {
                          _currentPage = index;
                          _exitInlineModes();
                          _activeFilterSelection =
                              _appliedFilterByPage[index] ??
                              EditorFilterType.none;
                        });
                        _prepareFilterPreviews();
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _buildPageItem(index: index, accent: accent);
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
                    onTap: _isCropMode
                        ? null
                        : () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                            );
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _showFilterStrip
                  ? _buildInlineFilterStrip(isDark: isDark, accent: accent)
                  : const SizedBox.shrink(),
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

  Widget _buildPageItem({required int index, required Color accent}) {
    final bool isCropTarget =
        _isCropMode && index == _cropTargetIndex && _cropQuad != null;

    if (!isCropTarget) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: InteractiveViewer(
          key: ValueKey<String>(_pages[index].path),
          minScale: 0.9,
          maxScale: 4,
          child: Image.file(File(_pages[index].path), fit: BoxFit.contain),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final Size imageSize = _cropImageSize ?? const Size(1000, 1400);

        final FittedSizes fitted = applyBoxFit(
          BoxFit.contain,
          imageSize,
          viewport,
        );
        final Rect imageRect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & viewport,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_pages[index].path), fit: BoxFit.contain),
            _InlineQuadCropOverlay(
              imageRect: imageRect,
              quad: _cropQuad!,
              accent: accent,
              onChanged: (NormalizedQuad next) {
                setState(() {
                  _cropQuad = next;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineCropBar({required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.all(color: accent.withOpacity(0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.crop_rounded, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isAutoCropMode
                  ? 'Auto edge crop ready. Drag corners if needed.'
                  : 'Manual crop active. Drag corners and apply.',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          TextButton(onPressed: _cancelInlineCrop, child: const Text('Cancel')),
          FilledButton(onPressed: _applyInlineCrop, child: const Text('Apply')),
        ],
      ),
    );
  }

  Widget _buildInlineFilterStrip({
    required bool isDark,
    required Color accent,
  }) {
    final List<EditorFilterType> filters = EditorFilterType.values;

    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final EditorFilterType filter = filters[index];
          final bool selected = _activeFilterSelection == filter;
          final String? previewPath = _filterPreviewPaths[filter];

          return GestureDetector(
            onTap: () => _applyFilterSelection(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 88,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark
                    ? AppColors.darkSurfaceContainerLow
                    : AppColors.lightSurfaceContainer,
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: previewPath == null
                          ? Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : Image.file(File(previewPath), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labelForFilter(filter),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolsBar({required bool isDark, required Color accent}) {
    final List<_ToolAction> tools = <_ToolAction>[
      _ToolAction(
        label: 'Auto',
        icon: Icons.auto_fix_high_rounded,
        onTap: _toggleAutoCropMode,
      ),
      _ToolAction(
        label: 'Retake',
        icon: Icons.camera_alt_outlined,
        onTap: _retakeCurrent,
      ),
      _ToolAction(
        label: 'Crop',
        icon: Icons.crop_outlined,
        onTap: _toggleManualCropMode,
      ),
      _ToolAction(
        label: 'Rotate',
        icon: Icons.rotate_90_degrees_ccw_rounded,
        onTap: _rotateCurrent,
      ),
      _ToolAction(
        label: 'Filter',
        icon: Icons.auto_awesome_rounded,
        onTap: _toggleFilterStrip,
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
            onTap: _isProcessing
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    tool.onTap();
                  },
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

  Future<void> _toggleAutoCropMode() async {
    if (_isProcessing || _pages.isEmpty) {
      return;
    }

    if (_isCropMode && _isAutoCropMode) {
      _cancelInlineCrop();
      return;
    }

    final bool canRevertThisPage = _autoOriginalPaths.containsKey(_currentPage);
    if (canRevertThisPage) {
      setState(() {
        _pages[_currentPage] = XFile(_autoOriginalPaths.remove(_currentPage)!);
      });
      _prepareFilterPreviews();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto crop reverted for this page.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _showFilterStrip = false;
    });

    try {
      final String sourcePath = _pages[_currentPage].path;
      final NormalizedQuad quad =
          await ImageEditService.detectDocumentQuadNormalized(sourcePath);
      final Size imageSize = await ImageEditService.readImageSize(sourcePath);

      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _isCropMode = true;
        _isAutoCropMode = true;
        _cropTargetIndex = _currentPage;
        _cropQuad = quad;
        _cropImageSize = imageSize;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto edge detection failed.')),
      );
    }
  }

  Future<void> _toggleManualCropMode() async {
    if (_isProcessing || _pages.isEmpty) {
      return;
    }

    if (_isCropMode && !_isAutoCropMode) {
      _cancelInlineCrop();
      return;
    }

    setState(() {
      _isProcessing = true;
      _showFilterStrip = false;
    });

    try {
      final String sourcePath = _pages[_currentPage].path;
      final Size imageSize = await ImageEditService.readImageSize(sourcePath);

      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
        _isCropMode = true;
        _isAutoCropMode = false;
        _cropTargetIndex = _currentPage;
        _cropQuad = const NormalizedQuad(
          topLeft: Offset(0.08, 0.08),
          topRight: Offset(0.92, 0.08),
          bottomRight: Offset(0.92, 0.92),
          bottomLeft: Offset(0.08, 0.92),
        );
        _cropImageSize = imageSize;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual crop setup failed.')),
      );
    }
  }

  Future<void> _applyInlineCrop() async {
    if (_cropQuad == null || _isProcessing) {
      return;
    }

    final int targetIndex = _cropTargetIndex;
    final String sourcePath = _pages[targetIndex].path;

    setState(() {
      _isProcessing = true;
    });

    try {
      final String warped =
          await ImageEditService.cropByNormalizedQuadPerspective(
            sourcePath,
            _cropQuad!,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        if (_isAutoCropMode && !_autoOriginalPaths.containsKey(targetIndex)) {
          _autoOriginalPaths[targetIndex] = sourcePath;
        }
        _pages[targetIndex] = XFile(warped);
        _isProcessing = false;
        _exitInlineCropOnly();
      });

      _prepareFilterPreviews();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAutoCropMode ? 'Auto crop applied.' : 'Crop applied.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not apply crop.')));
    }
  }

  void _cancelInlineCrop() {
    setState(() {
      _exitInlineCropOnly();
    });
  }

  Future<void> _rotateCurrent() async {
    await _applyEdit(
      actionName: 'Rotate',
      run: (String path) => ImageEditService.rotate90(path),
    );
    _prepareFilterPreviews();
  }

  void _toggleFilterStrip() {
    if (_isCropMode) {
      _cancelInlineCrop();
    }
    setState(() {
      _showFilterStrip = !_showFilterStrip;
      _activeFilterSelection =
          _appliedFilterByPage[_currentPage] ?? EditorFilterType.none;
    });
    if (_showFilterStrip) {
      _prepareFilterPreviews();
    }
  }

  Future<void> _applyFilterSelection(EditorFilterType filter) async {
    if (_isProcessing || _pages.isEmpty) {
      return;
    }

    final List<int> indexes = _applyToAllPages
        ? List<int>.generate(_pages.length, (int i) => i)
        : <int>[_currentPage];

    setState(() {
      _isProcessing = true;
      _activeFilterSelection = filter;
    });

    try {
      for (final int index in indexes) {
        if (filter == EditorFilterType.none) {
          final String? original = _filterOriginalPaths.remove(index);
          if (original != null) {
            _pages[index] = XFile(original);
          }
          _appliedFilterByPage[index] = EditorFilterType.none;
          continue;
        }

        _filterOriginalPaths[index] ??= _pages[index].path;
        final String filtered = await ImageEditService.applyFilter(
          _pages[index].path,
          filter,
        );
        _pages[index] = XFile(filtered);
        _appliedFilterByPage[index] = filter;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      _prepareFilterPreviews();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not apply filter.')));
    }
  }

  Future<void> _prepareFilterPreviews() async {
    if (_pages.isEmpty || !_showFilterStrip) {
      return;
    }

    final int token = ++_previewGenerationToken;
    final String sourcePath = _pages[_currentPage].path;

    setState(() {
      _filterPreviewPaths = <EditorFilterType, String>{
        EditorFilterType.none: sourcePath,
      };
    });

    for (final EditorFilterType filter in EditorFilterType.values) {
      if (filter == EditorFilterType.none) {
        continue;
      }
      try {
        final String preview = await ImageEditService.applyFilterPreview(
          sourcePath,
          filter,
        );
        if (!mounted || token != _previewGenerationToken) {
          return;
        }
        setState(() {
          _filterPreviewPaths[filter] = preview;
        });
      } catch (_) {}
    }

    if (!mounted || token != _previewGenerationToken) {
      return;
    }
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
    _prepareFilterPreviews();
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
      _exitInlineModes();
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
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$actionName applied.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionName failed. Try a different image.')),
      );
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
      _autoOriginalPaths.remove(_currentPage);
      _filterOriginalPaths.remove(_currentPage);
      _appliedFilterByPage[_currentPage] = EditorFilterType.none;
      _activeFilterSelection = EditorFilterType.none;
      _exitInlineModes();
    });

    _prepareFilterPreviews();
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
      _exitInlineModes();
    });

    await _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    _prepareFilterPreviews();
  }

  Future<void> _saveAsDraft() async {
    if (_isProcessing || _pages.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _exitInlineModes();
    });

    final String name = _nameController.text.trim().isEmpty
        ? 'Untitled scan'
        : _nameController.text.trim();

    final String draftId =
        widget.existingDraftId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final List<String> persistedPaths = <String>[];
      for (int i = 0; i < _pages.length; i += 1) {
        final String saved = await DocumentStorageService.instance
            .copyPageToDraft(_pages[i].path, draftId, i);
        persistedPaths.add(saved);
      }

      final DocumentDraft draft = DocumentDraft(
        id: draftId,
        name: name,
        pagePaths: persistedPaths,
        updatedAt: DateTime.now(),
      );

      await DocumentDraftStore.instance.upsert(draft);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved as draft.')));
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save draft. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

  void _exitInlineCropOnly() {
    _isCropMode = false;
    _isAutoCropMode = false;
    _cropQuad = null;
    _cropImageSize = null;
  }

  void _exitInlineModes() {
    _exitInlineCropOnly();
    _showFilterStrip = false;
  }

  String _labelForFilter(EditorFilterType filter) {
    switch (filter) {
      case EditorFilterType.none:
        return 'None';
      case EditorFilterType.enhanced:
        return 'Enhanced';
      case EditorFilterType.pro:
        return 'Pro';
      case EditorFilterType.grayscale:
        return 'Greyscale';
      case EditorFilterType.blackWhite:
        return 'B&W';
      case EditorFilterType.vivid:
        return 'Vivid';
      case EditorFilterType.cleanText:
        return 'Text';
      case EditorFilterType.warm:
        return 'Warm';
    }
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

class _InlineQuadCropOverlay extends StatelessWidget {
  const _InlineQuadCropOverlay({
    required this.imageRect,
    required this.quad,
    required this.accent,
    required this.onChanged,
  });

  final Rect imageRect;
  final NormalizedQuad quad;
  final Color accent;
  final ValueChanged<NormalizedQuad> onChanged;

  @override
  Widget build(BuildContext context) {
    final Offset tl = _toScreen(quad.topLeft);
    final Offset tr = _toScreen(quad.topRight);
    final Offset br = _toScreen(quad.bottomRight);
    final Offset bl = _toScreen(quad.bottomLeft);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _QuadOverlayPainter(
              imageRect: imageRect,
              topLeft: tl,
              topRight: tr,
              bottomRight: br,
              bottomLeft: bl,
              accent: accent,
            ),
          ),
        ),
        _handle(
          point: tl,
          onDrag: (Offset delta) =>
              _updateCorner(corner: _QuadCorner.topLeft, delta: delta),
        ),
        _handle(
          point: tr,
          onDrag: (Offset delta) =>
              _updateCorner(corner: _QuadCorner.topRight, delta: delta),
        ),
        _handle(
          point: br,
          onDrag: (Offset delta) =>
              _updateCorner(corner: _QuadCorner.bottomRight, delta: delta),
        ),
        _handle(
          point: bl,
          onDrag: (Offset delta) =>
              _updateCorner(corner: _QuadCorner.bottomLeft, delta: delta),
        ),
      ],
    );
  }

  Widget _handle({
    required Offset point,
    required ValueChanged<Offset> onDrag,
  }) {
    return Positioned(
      left: point.dx - 14,
      top: point.dy - 14,
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails details) => onDrag(details.delta),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: accent, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateCorner({required _QuadCorner corner, required Offset delta}) {
    const double minGap = 0.05;

    NormalizedQuad next = quad;
    final Offset normalizedDelta = Offset(
      delta.dx / imageRect.width,
      delta.dy / imageRect.height,
    );

    switch (corner) {
      case _QuadCorner.topLeft:
        next = next.copyWith(
          topLeft: (next.topLeft + normalizedDelta).clamp01(),
        );
        break;
      case _QuadCorner.topRight:
        next = next.copyWith(
          topRight: (next.topRight + normalizedDelta).clamp01(),
        );
        break;
      case _QuadCorner.bottomRight:
        next = next.copyWith(
          bottomRight: (next.bottomRight + normalizedDelta).clamp01(),
        );
        break;
      case _QuadCorner.bottomLeft:
        next = next.copyWith(
          bottomLeft: (next.bottomLeft + normalizedDelta).clamp01(),
        );
        break;
    }

    // Keep a minimum shape size for stable perspective mapping.
    final double minX = [
      next.topLeft.dx,
      next.bottomLeft.dx,
    ].reduce((double a, double b) => a < b ? a : b);
    final double maxX = [
      next.topRight.dx,
      next.bottomRight.dx,
    ].reduce((double a, double b) => a > b ? a : b);
    final double minY = [
      next.topLeft.dy,
      next.topRight.dy,
    ].reduce((double a, double b) => a < b ? a : b);
    final double maxY = [
      next.bottomLeft.dy,
      next.bottomRight.dy,
    ].reduce((double a, double b) => a > b ? a : b);

    if (maxX - minX < minGap || maxY - minY < minGap) {
      return;
    }

    onChanged(next.clamped());
  }

  Offset _toScreen(Offset normalized) {
    return Offset(
      imageRect.left + normalized.dx * imageRect.width,
      imageRect.top + normalized.dy * imageRect.height,
    );
  }
}

class _QuadOverlayPainter extends CustomPainter {
  const _QuadOverlayPainter({
    required this.imageRect,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.accent,
  });

  final Rect imageRect;
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outside = Path()..addRect(Offset.zero & size);
    final Path polygon = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    final Path shaded = Path.combine(
      PathOperation.difference,
      outside,
      polygon,
    );
    canvas.drawPath(shaded, Paint()..color = const Color(0x8A000000));

    final Paint line = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(polygon, line);

    final Paint imageBorder = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(imageRect, imageBorder);
  }

  @override
  bool shouldRepaint(covariant _QuadOverlayPainter oldDelegate) {
    return oldDelegate.topLeft != topLeft ||
        oldDelegate.topRight != topRight ||
        oldDelegate.bottomRight != bottomRight ||
        oldDelegate.bottomLeft != bottomLeft ||
        oldDelegate.accent != accent ||
        oldDelegate.imageRect != imageRect;
  }
}

enum _QuadCorner { topLeft, topRight, bottomRight, bottomLeft }

extension on Offset {
  Offset clamp01() {
    return Offset(dx.clamp(0.0, 1.0), dy.clamp(0.0, 1.0));
  }
}
