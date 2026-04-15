import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../documents/data/document_storage_service.dart';
import '../services/document_export_service.dart';

enum ExportDestinationType { appStorage, customFolder, downloads }

enum SaveAsAction { appStorage, chooseFolder, downloads, share }

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
  static const String _prefDestinationMode = 'export.destination.mode';
  static const String _prefCustomFolder = 'export.destination.custom_folder';
  static const String _prefDownloadsFolder =
      'export.destination.downloads_folder';

  bool _isExporting = false;
  ExportFormat _selectedExportFormat = ExportFormat.pdf;
  ExportDestinationType _destinationType = ExportDestinationType.appStorage;
  String? _destinationDirectory;
  String? _downloadsDirectory;
  late String _documentName;
  double _estimatedSizeMb = 0;

  @override
  void initState() {
    super.initState();
    _documentName = widget.documentName;
    _refreshEstimate();
    _loadSavedDestination();
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
                              Icon(Icons.folder_outlined, color: accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _destinationTitle(),
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: sub),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _destinationSubtitle(),
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
                              TextButton(
                                onPressed: _isExporting
                                    ? null
                                    : _showSaveAsBottomSheet,
                                child: const Text('Change'),
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
                        Text(
                          'Please keep the app open until the file is saved.',
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
                  onPressed: _isExporting ? null : _showSaveAsBottomSheet,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Save to...'),
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

  Future<void> _loadSavedDestination() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? mode = prefs.getString(_prefDestinationMode);
    final String? customFolder = prefs.getString(_prefCustomFolder);
    final String? downloadsFolder = prefs.getString(_prefDownloadsFolder);

    if (!mounted) {
      return;
    }

    setState(() {
      _destinationDirectory = customFolder;
      _downloadsDirectory = downloadsFolder;

      switch (mode) {
        case 'custom':
          _destinationType = ExportDestinationType.customFolder;
          break;
        case 'downloads':
          _destinationType = ExportDestinationType.downloads;
          break;
        default:
          _destinationType = ExportDestinationType.appStorage;
      }
    });
  }

  Future<void> _saveDestinationState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode;
    switch (_destinationType) {
      case ExportDestinationType.customFolder:
        mode = 'custom';
        break;
      case ExportDestinationType.downloads:
        mode = 'downloads';
        break;
      case ExportDestinationType.appStorage:
        mode = 'app';
        break;
    }
    await prefs.setString(_prefDestinationMode, mode);

    if (_destinationDirectory != null && _destinationDirectory!.isNotEmpty) {
      await prefs.setString(_prefCustomFolder, _destinationDirectory!);
    }

    if (_downloadsDirectory != null && _downloadsDirectory!.isNotEmpty) {
      await prefs.setString(_prefDownloadsFolder, _downloadsDirectory!);
    }
  }

  String _destinationTitle() {
    switch (_destinationType) {
      case ExportDestinationType.customFolder:
        return 'Custom Folder';
      case ExportDestinationType.downloads:
        return 'Downloads';
      case ExportDestinationType.appStorage:
        return 'App Storage (Default)';
    }
  }

  String _destinationSubtitle() {
    switch (_destinationType) {
      case ExportDestinationType.customFolder:
        return _destinationDirectory ?? 'No folder selected';
      case ExportDestinationType.downloads:
        return _downloadsDirectory ??
            'Will use Downloads when available, else app folder';
      case ExportDestinationType.appStorage:
        return 'Files will be saved in app folder';
    }
  }

  Future<void> _showSaveAsBottomSheet() async {
    if (_isExporting) {
      return;
    }

    final SaveAsAction? action = await showModalBottomSheet<SaveAsAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    'Save As',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Choose where to export this document.'),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Default (App Storage)'),
                  onTap: () =>
                      Navigator.of(context).pop(SaveAsAction.appStorage),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Choose Folder'),
                  onTap: () =>
                      Navigator.of(context).pop(SaveAsAction.chooseFolder),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Save to Downloads'),
                  subtitle: const Text(
                    'SAF folder first, safe fallback if needed',
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(SaveAsAction.downloads),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () => Navigator.of(context).pop(SaveAsAction.share),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }

    await _applySaveAsAction(action);
  }

  Future<void> _applySaveAsAction(SaveAsAction action) async {
    switch (action) {
      case SaveAsAction.appStorage:
        setState(() {
          _destinationType = ExportDestinationType.appStorage;
        });
        await _saveDestinationState();
        break;
      case SaveAsAction.chooseFolder:
        await _chooseDestination();
        break;
      case SaveAsAction.downloads:
        await _chooseDownloadsDestination();
        break;
      case SaveAsAction.share:
        await _shareNow();
        break;
    }
  }

  Future<void> _exportToDevicePdf() async {
    final String preferredDirectory = await _selectDestinationFolder();

    await _runExport(() async {
      try {
        final String exportedPath = await DocumentExportService.exportPdf(
          destinationDirectory: preferredDirectory,
          fileName: _documentName,
          pages: widget.pages,
        );
        await DocumentStorageService.instance.scanFile(exportedPath);
      } catch (_) {
        final Directory fallback = await DocumentStorageService.instance
            .getBestExportDirectory();
        final String fallbackPath = await DocumentExportService.exportPdf(
          destinationDirectory: fallback.path,
          fileName: _documentName,
          pages: widget.pages,
        );
        await DocumentStorageService.instance.scanFile(fallbackPath);

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selected folder not accessible. Saved to: ${fallback.path}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }, successMessage: 'PDF exported successfully to: $preferredDirectory');
  }

  Future<void> _exportImages() async {
    final String preferredDirectory = await _selectDestinationFolder();

    await _runExport(() async {
      try {
        final List<String> outputPaths =
            await DocumentExportService.exportImages(
              destinationDirectory: preferredDirectory,
              fileName: _documentName,
              pages: widget.pages,
            );
        for (final String path in outputPaths) {
          await DocumentStorageService.instance.scanFile(path);
        }
      } catch (_) {
        final Directory fallback = await DocumentStorageService.instance
            .getBestExportDirectory();
        final List<String> outputPaths =
            await DocumentExportService.exportImages(
              destinationDirectory: fallback.path,
              fileName: _documentName,
              pages: widget.pages,
            );
        for (final String path in outputPaths) {
          await DocumentStorageService.instance.scanFile(path);
        }

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selected folder not accessible. Saved to: ${fallback.path}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }, successMessage: 'Images exported successfully to: $preferredDirectory');
  }

  Future<void> _runExport(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      await action();
      if (!mounted) {
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
        });
      }
    }
  }

  Future<String> _selectDestinationFolder() async {
    if (_destinationType == ExportDestinationType.customFolder) {
      final Directory bestDir = await DocumentStorageService.instance
          .getBestExportDirectory(customPath: _destinationDirectory);
      if (_destinationDirectory == null && mounted) {
        setState(() {
          _destinationDirectory = bestDir.path;
        });
      }
      return bestDir.path;
    }

    if (_destinationType == ExportDestinationType.downloads) {
      final Directory bestDir = await DocumentStorageService.instance
          .getBestDownloadsDirectory(safPath: _downloadsDirectory);
      if (_downloadsDirectory == null && mounted) {
        setState(() {
          _downloadsDirectory = bestDir.path;
        });
        await _saveDestinationState();
      }
      return bestDir.path;
    }

    final Directory bestDir = await DocumentStorageService.instance
        .getBestExportDirectory();
    return bestDir.path;
  }

  Future<void> _chooseDestination() async {
    final String? selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder to save export',
    );

    if (selectedDir == null) {
      return;
    }

    setState(() {
      _destinationType = ExportDestinationType.customFolder;
      _destinationDirectory = selectedDir;
    });
    await _saveDestinationState();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Folder selected: $selectedDir'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _chooseDownloadsDestination() async {
    String? selectedDownloadsDir = _downloadsDirectory;

    if (selectedDownloadsDir == null || selectedDownloadsDir.isEmpty) {
      selectedDownloadsDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Downloads folder (recommended)',
      );
    }

    setState(() {
      _destinationType = ExportDestinationType.downloads;
      if (selectedDownloadsDir != null && selectedDownloadsDir.isNotEmpty) {
        _downloadsDirectory = selectedDownloadsDir;
      }
    });

    await _saveDestinationState();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedDownloadsDir == null
              ? 'Downloads selected. If direct Downloads is unavailable, app storage will be used.'
              : 'Downloads folder selected. Export will use this folder when accessible.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
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
