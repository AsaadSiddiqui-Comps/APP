import 'dart:ui';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_permission_service.dart';
import '../../../core/services/external_file_open_service.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../../documents/data/document_draft_store.dart';
import '../../documents/models/document_draft.dart';
import '../../editor/screens/editor_coming_soon_screen.dart';
import '../../files/screens/files_screen.dart';
import '../../files/screens/pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DocumentDraftStore.instance.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeExternalPdfOpen();
    }
  }

  Future<void> _consumeExternalPdfOpen() async {
    final String? path = await ExternalFileOpenService.consumePendingPdfPath();
    if (!mounted || path == null || path.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen(pdfPath: path, title: 'External PDF'),
      ),
    );
  }

  final List<Map<String, dynamic>> _quickActions = <Map<String, dynamic>>[
    {
      'label': 'Scan Code',
      'icon': Icons.qr_code_scanner_rounded,
      'enabled': false,
    },
    {'label': 'Watermark', 'icon': Icons.water_drop_outlined, 'enabled': false},
    {'label': 'eSign PDF', 'icon': Icons.draw_rounded, 'enabled': false},
    {'label': 'Split PDF', 'icon': Icons.call_split_rounded, 'enabled': false},
    {'label': 'Merge PDF', 'icon': Icons.merge_type_rounded, 'enabled': false},
    {
      'label': 'Protect PDF',
      'icon': Icons.lock_outline_rounded,
      'enabled': false,
    },
    {'label': 'Compress PDF', 'icon': Icons.compress_rounded, 'enabled': false},
    {'label': 'All Tools', 'icon': Icons.grid_view_rounded, 'enabled': false},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffold = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Widget currentBody = _selectedIndex == 0
        ? _buildHomeBody(isDark)
        : _selectedIndex == 1
        ? _buildTabPlaceholder('Tools page coming soon')
        : _buildTabPlaceholder('Settings coming soon');

    return Scaffold(
      backgroundColor: scaffold,
      body: currentBody,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocumentSheet,
        backgroundColor: isDark ? const Color(0xFFB6CBC3) : AppColors.primary,
        foregroundColor: isDark ? const Color(0xFF12201B) : AppColors.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }

  Widget _buildHomeBody(bool isDark) {
    final Color titleColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final Color subColor = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;
    final Color actionBg = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6E83FF), Color(0xFF8AB5FF)],
                    ),
                  ),
                  child: const Icon(
                    Icons.blur_circular_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ProScan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.search_rounded, color: subColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildActionGrid(isDark, actionBg, titleColor, subColor),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Files',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 28 * 0.8,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FilesScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.arrow_forward_rounded, color: subColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: DocumentDraftStore.instance,
              builder: (BuildContext context, Widget? child) {
                final List<DocumentDraft> drafts =
                    DocumentDraftStore.instance.drafts;
                if (drafts.isEmpty) {
                  return _buildEmptyRecentCard(isDark);
                }

                return Column(
                  children: drafts
                      .map(
                        (DocumentDraft doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildRecentDocTile(doc, isDark),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(
    bool isDark,
    Color actionBg,
    Color titleColor,
    Color subColor,
  ) {
    return GridView.builder(
      itemCount: _quickActions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> action = _quickActions[index];
        final bool enabled = action['enabled'] as bool;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled
              ? () {
                  if (action['label'] == 'All Tools') {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  }
                }
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: actionBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action['icon'] as IconData,
                  size: 20,
                  color: enabled
                      ? (isDark ? const Color(0xFFB6CBC3) : AppColors.primary)
                      : subColor.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action['label'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled ? titleColor : subColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyRecentCard(bool isDark) {
    final Color bg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;
    final Color sub = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerHighest
                  : AppColors.lightSurfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: isDark ? const Color(0xFFB6CBC3) : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No files yet. Tap camera to scan your first document.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: sub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDocTile(DocumentDraft doc, bool isDark) {
    final Color bg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;
    final Color text = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final Color sub = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDraft(doc),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 76,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHighest
                    : AppColors.lightSurfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: File(doc.thumbnailPath).existsSync()
                    ? Image.file(
                        File(doc.thumbnailPath),
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                      )
                    : Icon(
                        Icons.picture_as_pdf_rounded,
                        color: isDark
                            ? const Color(0xFFB6CBC3)
                            : AppColors.primary,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${doc.pagePaths.length} page(s) · ${_formatUpdatedDate(doc.updatedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: sub),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: sub),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    final Color navBg = isDark
        ? AppColors.darkSurfaceContainer.withOpacity(0.82)
        : AppColors.lightSurfaceContainerLowest.withOpacity(0.82);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: BottomAppBar(
              color: navBg,
              elevation: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.home_rounded, 'Home', isDark),
                  _navItem(1, Icons.grid_view_rounded, 'Tools', isDark),
                  _navItem(2, Icons.settings_outlined, 'Settings', isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    final bool selected = _selectedIndex == index;
    final Color active = isDark ? const Color(0xFF6E83FF) : AppColors.primary;
    final Color idle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? active : idle),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? active : idle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPlaceholder(String title) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  void _showAddDocumentSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Document',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _sheetTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  subtitle: 'Scan documents with camera',
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openCamera();
                  },
                ),
                const SizedBox(height: 10),
                _sheetTile(
                  icon: Icons.image_outlined,
                  title: 'Gallery',
                  subtitle: 'Import images from gallery',
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openGalleryEditor();
                  },
                ),
                const SizedBox(height: 10),
                _sheetTile(
                  icon: Icons.description_outlined,
                  title: 'Files',
                  subtitle: 'Import PDF or DOC files',
                  enabled: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tileBg = isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainer;
    final Color boxBg = isDark
        ? AppColors.darkSurfaceContainerHighest
        : const Color(0xFFD6E6F7);
    final Color iconColor = enabled
        ? (isDark ? const Color(0xFFB6CBC3) : const Color(0xFF1E88E5))
        : (isDark
              ? AppColors.darkOnSurfaceVariant
              : AppColors.lightOnSurfaceVariant);

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Material(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.lightOnSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    final PermissionCheckResult result = await AppPermissionService.instance
        .requestCameraPermission();
    if (!result.allGranted) {
      _showPermissionRequiredMessage(
        result,
        'Camera permission is needed to scan documents.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CameraCaptureScreen()),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openGalleryEditor() async {
    final PermissionCheckResult permissionResult = await AppPermissionService
        .instance
        .requestPhotosPermission();
    if (!permissionResult.allGranted) {
      _showPermissionRequiredMessage(
        permissionResult,
        'Photos permission is needed to import images.',
      );
      return;
    }

    final FilePickerResult? pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    final List<XFile> images = (pickerResult?.files ?? <PlatformFile>[])
        .where((PlatformFile file) => file.path != null)
        .map((PlatformFile file) => XFile(file.path!))
        .toList(growable: false);
    if (images.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorComingSoonScreen(initialImages: images),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _showPermissionRequiredMessage(
    PermissionCheckResult result,
    String message,
  ) {
    if (!mounted) {
      return;
    }

    final bool showSettings = result.permanentlyDenied.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: showSettings
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _openDraft(DocumentDraft draft) async {
    final List<String> existingPaths = <String>[];
    for (int i = 0; i < draft.pagePaths.length; i += 1) {
      final String primary = draft.pagePaths[i];
      final File primaryFile = File(primary);
      if (primaryFile.existsSync() && primaryFile.lengthSync() > 0) {
        existingPaths.add(primary);
        continue;
      }

      if (i < draft.filterBasePaths.length) {
        final String fallback = draft.filterBasePaths[i];
        final File fallbackFile = File(fallback);
        if (fallbackFile.existsSync() && fallbackFile.lengthSync() > 0) {
          existingPaths.add(fallback);
        }
      }
    }

    if (existingPaths.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft files not found on device.')),
      );
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

    if (mounted) {
      setState(() {});
    }
  }

  String _formatUpdatedDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
