import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
import '../../documents/data/document_draft_store.dart';
import '../../documents/data/document_storage_service.dart';
import '../../documents/models/document_draft.dart';
import '../../editor/screens/editor_coming_soon_screen.dart';
import '../../export/services/document_export_service.dart';
import 'pdf_viewer_screen.dart';

enum FilesBucket { drafts, exported }

enum FilesSort { date, name }

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  FilesBucket _bucket = FilesBucket.drafts;
  FilesSort _sort = FilesSort.date;
  bool _loadingExported = true;
  bool _sharingDraft = false;
  double _shareProgress = 0.0;
  String _shareLabel = 'Preparing...';
  List<FileSystemEntity> _exportedFiles = <FileSystemEntity>[];

  @override
  void initState() {
    super.initState();
    DocumentDraftStore.instance.initialize();
    _loadExportedFiles();
  }

  Future<void> _loadExportedFiles() async {
    setState(() {
      _loadingExported = true;
    });

    final Directory dir = await DocumentStorageService.instance
        .getExportedDir();
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<FileSystemEntity> files = entities
        .where((FileSystemEntity e) => FileSystemEntity.isFileSync(e.path))
        .toList(growable: false);

    if (!mounted) {
      return;
    }

    setState(() {
      _exportedFiles = _sortExported(files);
      _loadingExported = false;
    });
  }

  List<DocumentDraft> _sortedDrafts(List<DocumentDraft> input) {
    final List<DocumentDraft> drafts = List<DocumentDraft>.from(input);
    if (_sort == FilesSort.name) {
      drafts.sort(
        (DocumentDraft a, DocumentDraft b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else {
      drafts.sort(
        (DocumentDraft a, DocumentDraft b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    }
    return drafts;
  }

  List<FileSystemEntity> _sortExported(List<FileSystemEntity> input) {
    final List<FileSystemEntity> files = List<FileSystemEntity>.from(input);
    if (_sort == FilesSort.name) {
      files.sort(
        (FileSystemEntity a, FileSystemEntity b) => a.uri.pathSegments.last
            .toLowerCase()
            .compareTo(b.uri.pathSegments.last.toLowerCase()),
      );
    } else {
      files.sort((FileSystemEntity a, FileSystemEntity b) {
        final DateTime am = File(a.path).lastModifiedSync();
        final DateTime bm = File(b.path).lastModifiedSync();
        return bm.compareTo(am);
      });
    }
    return files;
  }

  List<String> _resolvedDraftPaths(DocumentDraft draft) {
    final List<String> resolved = <String>[];
    for (int i = 0; i < draft.pagePaths.length; i += 1) {
      final String primary = draft.pagePaths[i];
      final File primaryFile = File(primary);
      if (primaryFile.existsSync() && primaryFile.lengthSync() > 0) {
        resolved.add(primary);
        continue;
      }

      if (i < draft.filterBasePaths.length) {
        final String fallback = draft.filterBasePaths[i];
        final File fallbackFile = File(fallback);
        if (fallbackFile.existsSync() && fallbackFile.lengthSync() > 0) {
          resolved.add(fallback);
        }
      }
    }
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color panel = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          PopupMenuButton<FilesSort>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (FilesSort value) {
              setState(() {
                _sort = value;
                _exportedFiles = _sortExported(_exportedFiles);
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<FilesSort>>[
              const PopupMenuItem<FilesSort>(
                value: FilesSort.date,
                child: Text('Sort by date'),
              ),
              const PopupMenuItem<FilesSort>(
                value: FilesSort.name,
                child: Text('Sort by name'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _bucketChip(
                            label: 'Drafts',
                            selected: _bucket == FilesBucket.drafts,
                            onTap: () {
                              setState(() {
                                _bucket = FilesBucket.drafts;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _bucketChip(
                            label: 'Exported',
                            selected: _bucket == FilesBucket.exported,
                            onTap: () {
                              setState(() {
                                _bucket = FilesBucket.exported;
                              });
                              _loadExportedFiles();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _bucket == FilesBucket.drafts
                        ? _buildDrafts(isDark)
                        : _buildExported(isDark),
                  ),
                ],
              ),
            ),
          ),
          if (_sharingDraft) _buildShareProgressOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildShareProgressOverlay(bool isDark) {
    final Color cardColor = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;

    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preparing share',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _shareProgress.clamp(0.0, 1.0)),
              const SizedBox(height: 8),
              Text(_shareLabel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bucketChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.primary.withOpacity(0.22)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrafts(bool isDark) {
    return ListenableBuilder(
      listenable: DocumentDraftStore.instance,
      builder: (BuildContext context, Widget? child) {
        final List<DocumentDraft> drafts = _sortedDrafts(
          DocumentDraftStore.instance.drafts,
        );
        if (drafts.isEmpty) {
          return const Center(child: Text('No drafts yet.'));
        }

        return ListView.separated(
          itemCount: drafts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final DocumentDraft draft = drafts[index];
            return _draftTile(draft, isDark);
          },
        );
      },
    );
  }

  Widget _draftTile(DocumentDraft draft, bool isDark) {
    final Color panel = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;
    final String subtitle =
        '${draft.pagePaths.length} page(s) • ${draft.updatedAt.day.toString().padLeft(2, '0')}/${draft.updatedAt.month.toString().padLeft(2, '0')}/${draft.updatedAt.year}';

    return InkWell(
      onTap: () => _openDraft(draft),
      onLongPress: () => _showDraftMenu(draft),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: File(draft.thumbnailPath).existsSync()
                      ? Image.file(
                          File(draft.thumbnailPath),
                          width: 56,
                          height: 72,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 72,
                          color: Colors.black12,
                          child: const Icon(Icons.description_outlined),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showDraftMenu(draft),
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _quickRow(
              actions: <_QuickActionItem>[
                _QuickActionItem(
                  icon: Icons.edit_note_rounded,
                  label: 'Edit',
                  onTap: () => _openDraft(draft),
                ),
                _QuickActionItem(
                  icon: Icons.upload_file_rounded,
                  label: 'Export',
                  onTap: () => _exportDraft(draft),
                ),
                _QuickActionItem(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _shareDraft(draft),
                ),
                _QuickActionItem(
                  icon: Icons.draw_rounded,
                  label: 'Signature',
                  onTap: () => _comingSoon('Add signature'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExported(bool isDark) {
    if (_loadingExported) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exportedFiles.isEmpty) {
      return const Center(child: Text('No exported files yet.'));
    }

    final Color panel = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;

    return ListView.separated(
      itemCount: _exportedFiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final File file = File(_exportedFiles[index].path);
        final String name = file.uri.pathSegments.last;
        final bool isPdf = name.toLowerCase().endsWith('.pdf');
        final DateTime modified = file.lastModifiedSync();
        final String subtitle =
            '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB • ${modified.day.toString().padLeft(2, '0')}/${modified.month.toString().padLeft(2, '0')}/${modified.year}';

        return InkWell(
          onTap: () => _openExported(file),
          onLongPress: () => _showExportedMenu(file),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black12,
                      ),
                      child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(subtitle),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showExportedMenu(file),
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _quickRow(
                  actions: <_QuickActionItem>[
                    _QuickActionItem(
                      icon: Icons.open_in_new_rounded,
                      label: 'Open',
                      onTap: () => _openExported(file),
                    ),
                    _QuickActionItem(
                      icon: Icons.save_alt_rounded,
                      label: 'Save',
                      onTap: () => _saveToDeviceAgain(file),
                    ),
                    _QuickActionItem(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: () => _shareExported(file),
                    ),
                    _QuickActionItem(
                      icon: Icons.draw_rounded,
                      label: 'Signature',
                      onTap: () => _comingSoon('Add signature'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quickRow({required List<_QuickActionItem> actions}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (_QuickActionItem action) => Expanded(
              child: InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Icon(action.icon, size: 20),
                      const SizedBox(height: 4),
                      Text(action.label, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _openDraft(DocumentDraft draft) async {
    final List<String> existingPaths = _resolvedDraftPaths(draft);
    if (existingPaths.isEmpty || !mounted) {
      return;
    }

    final List<XFile> pages = existingPaths
        .map((String path) => XFile(path))
        .toList(growable: false);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorComingSoonScreen(
          initialImages: pages,
          initialName: draft.name,
          existingDraftId: draft.id,
        ),
      ),
    );
  }

  Future<void> _exportDraft(DocumentDraft draft) async {
    final List<String> existingPaths = _resolvedDraftPaths(draft);
    if (existingPaths.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorComingSoonScreen(
          initialImages: existingPaths
              .map((String path) => XFile(path))
              .toList(growable: false),
          initialName: draft.name,
          existingDraftId: draft.id,
        ),
      ),
    );
  }

  Future<void> _shareDraft(DocumentDraft draft) async {
    final List<String> existingPaths = _resolvedDraftPaths(draft);
    if (existingPaths.isEmpty) {
      return;
    }

    try {
      _setShareProgress(0.05, 'Checking existing export...');
      final String signature = _buildDraftSignature(draft.name, existingPaths);
      final String? reusablePdf = _findReusablePdf(draft, signature);

      String pdfPath;
      if (reusablePdf != null) {
        pdfPath = reusablePdf;
        _setShareProgress(0.7, 'Using existing PDF...');
      } else {
        _setShareProgress(0.1, 'Exporting PDF...');
        final Directory dir = await DocumentStorageService.instance
            .getExportedDir();
        pdfPath = await DocumentExportService.exportPdf(
          destinationDirectory: dir.path,
          fileName: draft.name,
          pages: existingPaths
              .map((String p) => XFile(p))
              .toList(growable: false),
          onProgress: (double progress) {
            _setShareProgress(0.1 + (0.8 * progress), 'Exporting PDF...');
          },
        );

        await DocumentDraftStore.instance.upsert(
          draft.copyWith(
            exportedPdfPath: pdfPath,
            exportedSignature: signature,
          ),
        );
      }

      _setShareProgress(0.95, 'Opening share sheet...');
      final File file = File(pdfPath);
      final Uint8List bytes = await file.readAsBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: file.uri.pathSegments.last,
      );
      _setShareProgress(1.0, 'Done');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to prepare draft for sharing.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharingDraft = false;
          _shareProgress = 0.0;
          _shareLabel = 'Preparing...';
        });
      }
    }
  }

  void _setShareProgress(double progress, String label) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sharingDraft = true;
      _shareProgress = progress;
      _shareLabel = label;
    });
  }

  String _buildDraftSignature(String name, List<String> paths) {
    final StringBuffer buffer = StringBuffer(name.trim().toLowerCase());
    for (final String path in paths) {
      final File file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final FileStat stat = file.statSync();
      buffer
        ..write('|')
        ..write(path)
        ..write(':')
        ..write(stat.size)
        ..write(':')
        ..write(stat.modified.millisecondsSinceEpoch);
    }
    return buffer.toString();
  }

  String? _findReusablePdf(DocumentDraft draft, String currentSignature) {
    final String? path = draft.exportedPdfPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (draft.exportedSignature != currentSignature) {
      return null;
    }

    final File exported = File(path);
    if (!exported.existsSync()) {
      return null;
    }
    if (exported.lengthSync() <= 0) {
      return null;
    }
    return path;
  }

  Future<void> _openExported(File file) async {
    final String lower = file.path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(
            pdfPath: file.path,
            title: file.uri.pathSegments.last,
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: InteractiveViewer(
            child: Image.file(file, fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  Future<void> _saveToDeviceAgain(File file) async {
    final String name = file.uri.pathSegments.last;
    final String lower = name.toLowerCase();
    final String mime = lower.endsWith('.pdf')
        ? 'application/pdf'
        : lower.endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    await DocumentStorageService.instance.saveFileToPublicDownloads(
      sourcePath: file.path,
      displayName: name,
      mimeType: mime,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved to Downloads/Docly')));
  }

  Future<void> _shareExported(File file) async {
    final String name = file.uri.pathSegments.last;
    if (name.toLowerCase().endsWith('.pdf')) {
      final Uint8List bytes = await file.readAsBytes();
      await Printing.sharePdf(bytes: bytes, filename: name);
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }

  Future<void> _renameDraft(DocumentDraft draft) async {
    final TextEditingController controller = TextEditingController(
      text: draft.name,
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename draft'),
          content: TextField(controller: controller, autofocus: true),
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

    if (value == null || value.isEmpty) {
      return;
    }

    await DocumentDraftStore.instance.upsert(
      draft.copyWith(name: value, updatedAt: DateTime.now()),
    );
  }

  Future<void> _deleteDraft(DocumentDraft draft) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete draft?'),
          content: const Text('This removes the draft and all pages.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await DocumentDraftStore.instance.remove(draft.id);
  }

  Future<void> _renameExported(File file) async {
    final TextEditingController controller = TextEditingController(
      text: file.uri.pathSegments.last,
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename exported file'),
          content: TextField(controller: controller, autofocus: true),
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

    if (value == null || value.isEmpty) {
      return;
    }

    final String safe = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final File target = File(
      '${file.parent.path}${Platform.pathSeparator}$safe',
    );
    await file.rename(target.path);
    await _loadExportedFiles();
  }

  Future<void> _deleteExported(File file) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete file?'),
          content: const Text(
            'This removes the exported file from app storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (await file.exists()) {
      await file.delete();
    }
    await _loadExportedFiles();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon.')));
  }

  Future<void> _showDraftMenu(DocumentDraft draft) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit draft'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openDraft(draft);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_rounded),
                title: const Text('Export this scan'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportDraft(draft);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareDraft(draft);
                },
              ),
              ListTile(
                leading: const Icon(Icons.draw_rounded),
                title: const Text('Add signature'),
                onTap: () {
                  Navigator.of(context).pop();
                  _comingSoon('Add signature');
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(context).pop();
                  _renameDraft(draft);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteDraft(draft);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExportedMenu(File file) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open in app'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openExported(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_alt_rounded),
                title: const Text('Save to device'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveToDeviceAgain(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareExported(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.draw_rounded),
                title: const Text('Add signature'),
                onTap: () {
                  Navigator.of(context).pop();
                  _comingSoon('Add signature');
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(context).pop();
                  _renameExported(file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteExported(file);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
