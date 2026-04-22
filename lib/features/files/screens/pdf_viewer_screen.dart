import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/constants/app_colors.dart';
import '../../pdf_editor/screens/pdf_editor_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  final String pdfPath;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _controller;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  bool _searchMode = false;
  String? _loadError;
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfEditorScreen(
          pdfPath: widget.pdfPath,
          title: widget.title,
        ),
      ),
    );
  }

  Future<void> _share() async {
    final File file = File(widget.pdfPath);
    if (!await file.exists()) {
      return;
    }
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.uri.pathSegments.last,
    );
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _runSearch([String? value]) {
    final String query = (value ?? _searchController.text).trim();
    if (query.isEmpty) {
      _searchResult?.clear();
      setState(() {});
      return;
    }

    _searchResult?.removeListener(_onSearchChanged);
    final PdfTextSearchResult result = _controller.searchText(query);
    result.addListener(_onSearchChanged);
    _searchResult = result;
    setState(() {});
  }

  void _closeSearch() {
    _searchResult?.removeListener(_onSearchChanged);
    _searchResult?.clear();
    _searchResult = null;
    setState(() {
      _searchMode = false;
      _searchController.clear();
    });
  }

  Future<void> _jumpToPageDialog() async {
    if (_pageCount <= 0) {
      return;
    }

    final TextEditingController pageController = TextEditingController(
      text: _currentPage.toString(),
    );

    final int? page = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Jump To Page'),
          content: TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Page (1-$_pageCount)'),
            onSubmitted: (String value) =>
                Navigator.of(context).pop(int.tryParse(value.trim())),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(pageController.text.trim())),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    pageController.dispose();

    if (page == null) {
      return;
    }

    _controller.jumpToPage(page.clamp(1, _pageCount));
  }

  PreferredSizeWidget _buildAppBar() {
    if (_searchMode) {
      final PdfTextSearchResult? sr = _searchResult;
      final String suffix = (sr != null && sr.hasResult)
          ? '${sr.currentInstanceIndex}/${sr.totalInstanceCount}'
          : '';

      return AppBar(
        leading: IconButton(
          onPressed: _closeSearch,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search in PDF',
            border: InputBorder.none,
            suffixText: suffix.isEmpty ? null : suffix,
          ),
          onChanged: _runSearch,
          onSubmitted: _runSearch,
        ),
        actions: [
          IconButton(
            tooltip: 'Previous result',
            onPressed: _searchResult?.previousInstance,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: 'Next result',
            onPressed: _searchResult?.nextInstance,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Open editor',
          onPressed: _openEditor,
          icon: const Icon(Icons.edit_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'search') {
              setState(() => _searchMode = true);
              return;
            }
            if (value == 'jump') {
              _jumpToPageDialog();
              return;
            }
            if (value == 'share') {
              _share();
            }
          },
          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'search', child: Text('Search in PDF')),
            PopupMenuItem<String>(value: 'jump', child: Text('Jump to page')),
            PopupMenuItem<String>(value: 'share', child: Text('Share')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: File(widget.pdfPath).existsSync()
          ? Stack(
              children: [
                SfPdfViewer.file(
                  File(widget.pdfPath),
                  controller: _controller,
                  canShowPaginationDialog: false,
                  canShowScrollHead: false,
                  canShowPageLoadingIndicator: true,
                  canShowScrollStatus: false,
                  maxZoomLevel: 5,
                  pageSpacing: 2,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isLoading = false;
                      _loadError = null;
                      _pageCount = details.document.pages.count;
                      _currentPage = _controller.pageNumber;
                    });
                  },
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _isLoading = false;
                      _loadError = details.description;
                    });
                  },
                  onPageChanged: (PdfPageChangedDetails details) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                  },
                ),
                if (_isLoading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2.5),
                  ),
                if (_loadError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_loadError!, textAlign: TextAlign.center),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        '$_currentPage / $_pageCount',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: Text('PDF file not found.')),
    );
  }
}
