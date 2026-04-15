import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/camera_capture_result.dart';
import '../../editor/screens/editor_coming_soon_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    this.initialBatchMode = false,
    this.allowModeSwitch = true,
    this.allowSettings = true,
    this.allowGalleryImport = true,
    this.openEditorOnSingleCapture = true,
    this.returnCapturesOnly = false,
  });

  final bool initialBatchMode;
  final bool allowModeSwitch;
  final bool allowSettings;
  final bool allowGalleryImport;
  final bool openEditorOnSingleCapture;
  final bool returnCapturesOnly;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _isLoading = true;
  bool _isBatchMode = false;
  bool _isTakingPicture = false;
  List<XFile> _capturedImages = <XFile>[];
  FlashMode _flashMode = FlashMode.off;
  int _selectedDocTypeIndex = 2;

  static const List<String> _docTypes = <String>[
    'Book',
    'ID Card',
    'Document',
    'Business Card',
  ];

  @override
  void initState() {
    super.initState();
    _isBatchMode = widget.initialBatchMode;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      CameraDescription selected = cameras.first;
      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selected = camera;
          break;
        }
      }

      final CameraController controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final XFile file = await _controller!.takePicture();
      if (!mounted) {
        return;
      }

      if (_isBatchMode) {
        setState(() {
          _capturedImages.add(file);
        });
      } else {
        if (widget.returnCapturesOnly) {
          if (mounted) {
            Navigator.of(
              context,
            ).pop(CameraCaptureResult(images: <XFile>[file]));
          }
          return;
        }

        if (widget.openEditorOnSingleCapture) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  EditorComingSoonScreen(initialImages: <XFile>[file]),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not capture photo.')));
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<void> _importFromGallery() async {
    if (!widget.allowGalleryImport) {
      return;
    }

    try {
      if (_isBatchMode) {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        final List<XFile> images = (result?.files ?? <PlatformFile>[])
            .where((PlatformFile file) => file.path != null)
            .map((PlatformFile file) => XFile(file.path!))
            .toList(growable: false);

        if (images.isEmpty || !mounted) {
          return;
        }

        if (widget.returnCapturesOnly) {
          Navigator.of(context).pop(CameraCaptureResult(images: images));
          return;
        }

        setState(() {
          _capturedImages.addAll(images);
        });
      } else {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        final String? selectedPath = (result != null && result.files.isNotEmpty)
            ? result.files.first.path
            : null;
        final XFile? image = selectedPath == null ? null : XFile(selectedPath);

        if (image == null || !mounted) {
          return;
        }

        if (widget.returnCapturesOnly) {
          Navigator.of(
            context,
          ).pop(CameraCaptureResult(images: <XFile>[image]));
          return;
        }

        if (widget.openEditorOnSingleCapture) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  EditorComingSoonScreen(initialImages: <XFile>[image]),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import image from gallery.')),
      );
    }
  }

  Future<void> _toggleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final FlashMode next = _flashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;

    try {
      await _controller!.setFlashMode(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _flashMode = next;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this device.')),
      );
    }
  }

  IconData _flashIconForMode() {
    return _flashMode == FlashMode.torch
        ? Icons.flash_on_rounded
        : Icons.flash_off_rounded;
  }

  void _showCapturedImagesSheet() {
    if (_capturedImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No captured photos yet.')));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Captured Photos (${_capturedImages.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _capturedImages.isEmpty
                                    ? null
                                    : () => _confirmClearAll(setModalState),
                                icon: const Icon(Icons.delete_sweep_outlined),
                                label: const Text('Clear all'),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'Tap to preview, hold and drag to reorder, long press to delete.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          itemCount: _capturedImages.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.85,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final XFile image = _capturedImages[index];
                            return _buildDraggableGridTile(
                              index: index,
                              image: image,
                              setModalState: setModalState,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDraggableGridTile({
    required int index,
    required XFile image,
    required StateSetter setModalState,
  }) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (DragTargetDetails<int> details) {
        return details.data != index;
      },
      onAcceptWithDetails: (DragTargetDetails<int> details) {
        _reorderGridItems(details.data, index, setModalState);
      },
      builder:
          (
            BuildContext context,
            List<int?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final bool highlighted = candidateData.isNotEmpty;
            return LongPressDraggable<int>(
              data: index,
              feedback: SizedBox(
                width: 110,
                height: 140,
                child: Opacity(
                  opacity: 0.9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(image.path), fit: BoxFit.cover),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: _buildGridTileContent(image: image, index: index),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: highlighted ? Colors.blueAccent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: GestureDetector(
                  onTap: () => _showImagePreview(image.path),
                  onLongPress: () => _confirmDelete(index, setModalState),
                  child: _buildGridTileContent(image: image, index: index),
                ),
              ),
            );
          },
    );
  }

  Widget _buildGridTileContent({required XFile image, required int index}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(image.path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photo ${index + 1}', style: const TextStyle(fontSize: 12)),
            const Icon(Icons.drag_indicator, size: 16),
          ],
        ),
      ],
    );
  }

  void _reorderGridItems(
    int oldIndex,
    int newIndex,
    StateSetter setModalState,
  ) {
    if (oldIndex == newIndex) {
      return;
    }
    setState(() {
      final XFile moved = _capturedImages.removeAt(oldIndex);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      _capturedImages.insert(newIndex, moved);
    });
    setModalState(() {});
  }

  void _confirmClearAll(StateSetter setModalState) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear all photos?'),
          content: const Text(
            'This will remove every captured image in this batch.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _capturedImages.clear();
                });
                setModalState(() {});
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  void _showImagePreview(String path) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(int index, StateSetter setModalState) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Photo?'),
          content: const Text('This photo will be removed from the batch.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _capturedImages.removeAt(index);
                });
                setModalState(() {});
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeBatch() async {
    if (_capturedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture at least one photo first.')),
      );
      return;
    }

    if (widget.returnCapturesOnly) {
      Navigator.of(
        context,
      ).pop(CameraCaptureResult(images: List<XFile>.from(_capturedImages)));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorComingSoonScreen(
          initialImages: List<XFile>.from(_capturedImages),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool cameraReady =
        _controller != null && _controller!.value.isInitialized;
    final Color bg = AppColors.darkBackground;
    final Color panel = AppColors.darkSurfaceContainer;
    final Color panelLow = AppColors.darkSurfaceContainerLow;
    final Color panelHigh = AppColors.darkSurfaceContainerHighest;
    final Color subText = AppColors.darkOnSurfaceVariant;
    final Color active = const Color(0xFF6E83FF);

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !cameraReady
          ? const Center(
              child: Text(
                'Camera not available',
                style: TextStyle(color: AppColors.darkOnSurface),
              ),
            )
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        _topActionButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (widget.allowModeSwitch)
                          Container(
                            decoration: BoxDecoration(
                              color: panel,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildModeButton(
                                  label: 'Single',
                                  isSelected: !_isBatchMode,
                                  active: active,
                                  panelHigh: panelHigh,
                                ),
                                _buildModeButton(
                                  label: 'Batch',
                                  isSelected: _isBatchMode,
                                  active: active,
                                  panelHigh: panelHigh,
                                ),
                              ],
                            ),
                          ),
                        if (widget.allowSettings) ...[
                          const SizedBox(width: 10),
                          _topActionButton(
                            icon: _flashIconForMode(),
                            onTap: _toggleFlashMode,
                          ),
                          const SizedBox(width: 8),
                          _topActionButton(
                            icon: Icons.more_horiz_rounded,
                            onTap: null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: active, width: 2),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.allowSettings)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _docTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final bool selected = _selectedDocTypeIndex == index;
                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            setState(() {
                              _selectedDocTypeIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: selected
                                  ? active.withOpacity(0.16)
                                  : panel,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _docTypes[index],
                              style: TextStyle(
                                color: selected ? active : subText,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (widget.allowSettings) const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 92,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildGalleryButton(
                              active: active,
                              subText: subText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: _capturePhoto,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active.withOpacity(0.9),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: _isTakingPicture ? 50 : 64,
                                    height: _isTakingPicture ? 50 : 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isTakingPicture
                                          ? active.withOpacity(0.65)
                                          : active,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildPreviewButton(
                              active: active,
                              panelLow: panelLow,
                              subText: subText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isBatchMode) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: FilledButton(
                        onPressed: _capturedImages.isEmpty
                            ? null
                            : _completeBatch,
                        style: FilledButton.styleFrom(
                          backgroundColor: active,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isSelected,
    required Color active,
    required Color panelHigh,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        final bool nextBatch = label == 'Batch';
        if (_isBatchMode == nextBatch) {
          return;
        }
        setState(() {
          _isBatchMode = nextBatch;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? panelHigh : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? active : AppColors.darkOnSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(
          icon,
          color: enabled
              ? AppColors.darkOnSurface
              : AppColors.darkOnSurfaceVariant,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildGalleryButton({required Color active, required Color subText}) {
    return GestureDetector(
      onTap: widget.allowGalleryImport ? _importFromGallery : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceContainerLow,
          border: Border.all(color: active.withOpacity(0.35)),
        ),
        child: Icon(
          widget.allowGalleryImport
              ? Icons.photo_library_outlined
              : Icons.block_rounded,
          color: widget.allowGalleryImport ? subText : subText.withOpacity(0.5),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildPreviewButton({
    required Color active,
    required Color panelLow,
    required Color subText,
  }) {
    return GestureDetector(
      onTap: _capturedImages.isEmpty ? null : _showCapturedImagesSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: active.withOpacity(0.55)),
              color: panelLow,
            ),
            child: ClipOval(
              child: _capturedImages.isEmpty
                  ? Center(
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          color: subText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Image.file(
                      File(_capturedImages.last.path),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (_capturedImages.isNotEmpty)
            Positioned(
              right: -4,
              top: -6,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.error,
                child: Text(
                  '${_capturedImages.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.darkOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
