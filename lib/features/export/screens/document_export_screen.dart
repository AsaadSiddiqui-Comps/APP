import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../documents/data/document_draft_store.dart';
import '../../documents/data/document_storage_service.dart';
import '../../documents/models/document_draft.dart';
import '../services/document_export_service.dart';

class DocumentExportScreen extends StatefulWidget {
  const DocumentExportScreen({
    super.key,
    required this.pages,
    required this.documentName,
  });

  final List<XFile> pages;
  final String documentName;

  @override
  State<DocumentExportScreen> createState() => _DocumentExportScreenState();
}

class _DocumentExportScreenState extends State<DocumentExportScreen> {
  bool _isExporting = false;
  double _exportProgress = 0;
  ExportFormat _selectedExportFormat = ExportFormat.pdf;
  late String _documentName;
  double _estimatedSizeMb = 0;

  @override
  void initState() {
    super.initState();
    _documentName = widget.documentName;
    _refreshEstimate();
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
    final Color accent = isDark ? const Color(0xFF6E83FF) : AppColors.primary;
    final Color text = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final Color sub = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_documentName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${widget.pages.length} page(s)',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: sub),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isExporting ? null : _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'watermark') {
                _comingSoon('Watermark');
              } else if (value == 'signature') {
                _comingSoon('Digital signature');
              } else if (value == 'rename') {
                _rename();
              } else if (value == 'print') {
                _comingSoon('Print');
              } else if (value == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'watermark',
                child: Text('Add watermark'),
              ),
              const PopupMenuItem<String>(
                value: 'signature',
                child: Text('Add digital signature'),
              ),
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename'),
              ),
              const PopupMenuItem<String>(value: 'print', child: Text('Print')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Settings',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how you want to save this document.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: sub),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _exportTypeCard(
                                title: 'PDF',
                                subtitle: 'One file with all pages',
                                selected:
                                    _selectedExportFormat == ExportFormat.pdf,
                                accent: accent,
                                panelLow: panelLow,
                                onTap: () {
                                  setState(() {
                                    _selectedExportFormat = ExportFormat.pdf;
                                  });
                                  _refreshEstimate();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _exportTypeCard(
                                title: 'Images',
                                subtitle: 'Export each page separately',
                                selected:
                                    _selectedExportFormat ==
                                    ExportFormat.images,
                                accent: accent,
                                panelLow: panelLow,
                                onTap: () {
                                  setState(() {
                                    _selectedExportFormat = ExportFormat.images;
                                  });
                                  _refreshEstimate();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Destination',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: sub),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: panelLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.download_outlined, color: accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Downloads (Fixed)',
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: sub),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Internal storage/Download/Docly',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: text),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.water_drop_outlined,
                    label: 'Add watermark',
                    onTap: () => _comingSoon('Watermark'),
                  ),
                  _actionTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Add digital signature',
                    onTap: () => _comingSoon('Digital signature'),
                  ),
                  _actionTile(
                    icon: Icons.drive_file_rename_outline,
                    label: 'Rename',
                    onTap: _rename,
                  ),
                  _actionTile(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    onTap: () => _comingSoon('Print'),
                  ),
                  _actionTile(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onTap: _confirmDelete,
                    destructive: true,
                  ),
                ],
              ),
            ),
          ),
          if (_isExporting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.28),
                child: Center(
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Exporting…',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _exportProgress > 0 ? _exportProgress : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _exportProgress > 0
                              ? 'Processing ${(100 * _exportProgress).clamp(0, 100).toStringAsFixed(0)}%'
                              : 'Please keep the app open until the file is saved.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: sub),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isExporting ? null : _shareNow,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Share'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _isExporting ? null : _exportNow,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Export (${_estimatedSizeMb.toStringAsFixed(1)} MB)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportTypeCard({
    required String title,
    required String subtitle,
    required bool selected,
    required Color accent,
    required Color panelLow,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panelLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: accent,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;
    final Color iconColor = destructive
        ? AppColors.error
        : (isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportNow() async {
    if (_selectedExportFormat == ExportFormat.pdf) {
      await _exportToDevicePdf();
    } else {
      await _exportImages();
    }
  }

  Future<void> _exportToDevicePdf() async {
    await _runExport(() async {
      final Directory tempDir = await DocumentStorageService.instance
          .getExportedDir();
      final String tempPdfPath = await DocumentExportService.exportPdf(
        destinationDirectory: tempDir.path,
        fileName: _documentName,
        pages: widget.pages,
        onProgress: (double progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _exportProgress = progress;
          });
        },
      );

      await DocumentStorageService.instance.saveFileToPublicDownloads(
        sourcePath: tempPdfPath,
        displayName: '$_documentName.pdf',
        mimeType: 'application/pdf',
      );
    }, successMessage: 'PDF exported to Downloads/Docly', saveDraftAndExit: true);
  }

  Future<void> _exportImages() async {
    await _runExport(() async {
      final Directory tempDir = await DocumentStorageService.instance
          .getExportedDir();
      final List<String> outputPaths = await DocumentExportService.exportImages(
        destinationDirectory: tempDir.path,
        fileName: _documentName,
        pages: widget.pages,
      );

      for (final String path in outputPaths) {
        final String fileName = path.split(Platform.pathSeparator).last;
        await DocumentStorageService.instance.saveFileToPublicDownloads(
          sourcePath: path,
          displayName: fileName,
          mimeType: _imageMime(path),
        );
      }
    }, successMessage: 'Images exported to Downloads/Docly', saveDraftAndExit: true);
  }

  Future<void> _runExport(
    Future<void> Function() action, {
    required String successMessage,
    bool saveDraftAndExit = false,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }

      if (saveDraftAndExit) {
        await _saveAsDraftAndGoHome();
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 0;
        });
      }
    }
  }

  Future<void> _saveAsDraftAndGoHome() async {
    final String draftId = DateTime.now().millisecondsSinceEpoch.toString();
    final List<String> persistedPaths = <String>[];

    for (int i = 0; i < widget.pages.length; i += 1) {
      final String saved = await DocumentStorageService.instance.copyPageToDraft(
        widget.pages[i].path,
        draftId,
        i,
      );
      persistedPaths.add(saved);
    }

    final DocumentDraft draft = DocumentDraft(
      id: draftId,
      name: _documentName.trim().isEmpty ? 'Untitled scan' : _documentName.trim(),
      pagePaths: persistedPaths,
      updatedAt: DateTime.now(),
    );

    await DocumentDraftStore.instance.upsert(draft);
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  String _imageMime(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<void> _shareNow() async {
    await _runExport(() async {
      final Directory shareDir = await DocumentStorageService.instance
          .getBestExportDirectory();

      if (_selectedExportFormat == ExportFormat.pdf) {
        final String pdfPath = await DocumentExportService.exportPdf(
          destinationDirectory: shareDir.path,
          fileName: _documentName,
          pages: widget.pages,
          onProgress: (double progress) {
            if (!mounted) {
              return;
            }
            setState(() {
              _exportProgress = progress;
            });
          },
        );
        final File file = File(pdfPath);
        final Uint8List bytes = await file.readAsBytes();
        await DocumentStorageService.instance.scanFile(pdfPath);
        await Printing.sharePdf(
          bytes: bytes,
          filename: file.uri.pathSegments.last,
        );
        return;
      }

      final String pdfPath = await DocumentExportService.exportPdf(
        destinationDirectory: shareDir.path,
        fileName: _documentName,
        pages: widget.pages,
        onProgress: (double progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _exportProgress = progress;
          });
        },
      );
      final File file = File(pdfPath);
      final Uint8List bytes = await file.readAsBytes();
      await DocumentStorageService.instance.scanFile(pdfPath);
      await Printing.sharePdf(
        bytes: bytes,
        filename: file.uri.pathSegments.last,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared as PDF for better compatibility.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }, successMessage: 'Share opened successfully.');
  }

  Future<void> _refreshEstimate() async {
    final double estimate = await DocumentExportService.estimateOutputSizeMb(
      pages: widget.pages,
      format: _selectedExportFormat,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _estimatedSizeMb = estimate;
    });
  }

  Future<void> _rename() async {
    final TextEditingController controller = TextEditingController(
      text: _documentName,
    );
    final String? renamed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Document name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (renamed == null || renamed.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _documentName = renamed;
    });
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete document?'),
          content: const Text(
            'This will remove the current in-memory document from the editor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).popUntil((Route<dynamic> route) => route.isFirst);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature feature coming soon.')));
  }
}
