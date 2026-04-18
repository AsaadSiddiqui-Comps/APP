import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/constants/app_colors.dart';

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
  double _zoom = 1.0;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  bool _searchMode = false;
  bool _chromeVisible = true;
  String? _loadError;
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_handleSearchResultChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final File file = File(widget.pdfPath);
    if (!await file.exists()) {
      return;
    }

    final String fileName = file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  void _zoomIn() {
    final double next = (_zoom + 0.25).clamp(1.0, 5.0);
    _controller.zoomLevel = next;
  }

  void _zoomOut() {
    final double next = (_zoom - 0.25).clamp(1.0, 5.0);
    _controller.zoomLevel = next;
  }

  void _nextPage() {
    if (_currentPage >= _pageCount) {
      return;
    }
    _controller.nextPage();
  }

  void _previousPage() {
    if (_currentPage <= 1) {
      return;
    }
    _controller.previousPage();
  }

  void _toggleChrome() {
    if (!mounted) {
      return;
    }
    setState(() {
      _chromeVisible = !_chromeVisible;
    });
  }

  void _setChromeVisible(bool visible) {
    if (!mounted || _chromeVisible == visible) {
      return;
    }
    setState(() {
      _chromeVisible = visible;
    });
  }

  Future<void> _showJumpToPageDialog() async {
    if (_pageCount <= 0) {
      return;
    }

    final TextEditingController pageController = TextEditingController(
      text: _currentPage.toString(),
    );

    final int? targetPage = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Jump To Page'),
          content: TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Page number (1-$_pageCount)',
            ),
            onSubmitted: (String value) {
              final int? parsed = int.tryParse(value.trim());
              Navigator.of(context).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int? parsed = int.tryParse(pageController.text.trim());
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    pageController.dispose();

    if (targetPage == null) {
      return;
    }

    final int clamped = targetPage.clamp(1, _pageCount);
    _controller.jumpToPage(clamped);
  }

  void _openSearchMode() {
    setState(() {
      _searchMode = true;
      _chromeVisible = true;
    });
  }

  void _closeSearchMode() {
    _searchResult?.removeListener(_handleSearchResultChanged);
    _searchResult?.clear();
    _searchResult = null;

    setState(() {
      _searchMode = false;
      _searchController.clear();
    });
  }

  void _handleSearchResultChanged() {
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

    _searchResult?.removeListener(_handleSearchResultChanged);
    final PdfTextSearchResult result = _controller.searchText(query);
    result.addListener(_handleSearchResultChanged);
    _searchResult = result;
    setState(() {});
  }

  void _nextSearchResult() {
    _searchResult?.nextInstance();
  }

  void _previousSearchResult() {
    _searchResult?.previousInstance();
  }

  PreferredSizeWidget? _buildAppBar() {
    if (!_chromeVisible) {
      return null;
    }

    if (_searchMode) {
      final PdfTextSearchResult? sr = _searchResult;
      final String suffix = (sr != null && sr.hasResult)
          ? '${sr.currentInstanceIndex}/${sr.totalInstanceCount}'
          : '';

      return AppBar(
        leading: IconButton(
          tooltip: 'Close search',
          onPressed: _closeSearchMode,
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
            onPressed: _previousSearchResult,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: 'Next result',
            onPressed: _nextSearchResult,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: _openSearchMode,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Zoom out',
          onPressed: _zoomOut,
          icon: const Icon(Icons.zoom_out_rounded),
        ),
        IconButton(
          tooltip: 'Zoom in',
          onPressed: _zoomIn,
          icon: const Icon(Icons.zoom_in_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'share') {
              _share();
            } else if (value == 'open_external') {
              _share();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'share', child: Text('Share')),
            const PopupMenuItem<String>(
              value: 'open_external',
              child: Text('Open in default browser/apps'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBar(bool isDark) {
    final Color panel = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;
    return SafeArea(
      top: false,
      child: Container(
        color: panel,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: _previousPage,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Jump to page',
              onPressed: _showJumpToPageDialog,
              icon: const Icon(Icons.menu_book_rounded),
            ),
            Expanded(
              child: InkWell(
                onTap: _showJumpToPageDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _pageCount > 0
                        ? 'Page $_currentPage/$_pageCount  •  Zoom ${(100 * _zoom).round()}%'
                        : 'Loading document...',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _nextPage,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: File(widget.pdfPath).existsSync()
          ? Stack(
              children: [
                SfPdfViewer.file(
                  File(widget.pdfPath),
                  controller: _controller,
                  canShowPaginationDialog: true,
                  canShowScrollHead: true,
                  canShowPageLoadingIndicator: true,
                  canShowScrollStatus: false,
                  interactionMode: PdfInteractionMode.pan,
                  enableTextSelection: false,
                  maxZoomLevel: 5,
                  pageSpacing: 6,
                  onTap: (PdfGestureDetails details) {
                    _toggleChrome();
                  },
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

                    if (details.newPageNumber > details.oldPageNumber) {
                      _setChromeVisible(false);
                    } else if (details.newPageNumber < details.oldPageNumber ||
                        details.newPageNumber == 1) {
                      _setChromeVisible(true);
                    }
                  },
                  onZoomLevelChanged: (PdfZoomDetails details) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _zoom = details.newZoomLevel;
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
              ],
            )
          : const Center(child: Text('PDF file not found.')),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: _chromeVisible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _chromeVisible ? 1 : 0,
          child: _buildStatusBar(isDark),
        ),
      ),
    );
  }
}
