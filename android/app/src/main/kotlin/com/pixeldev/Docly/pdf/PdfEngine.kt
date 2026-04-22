package com.pixeldev.Docly.pdf

import android.graphics.Bitmap

class PdfEngine {
    private val drawingHandler = DrawingHandler()
    private val annotationHandler = AnnotationHandler()
    private val renderer = PdfRenderer()
    private val editor = PdfEditor(drawingHandler, annotationHandler)

    private var currentPdfPath: String? = null
    private var currentPage: Int = 1
    private var surfaceWidth: Int = 0
    private var surfaceHeight: Int = 0
    private var currentBaseBitmap: Bitmap? = null
    private var invalidator: (() -> Unit)? = null
    private var renderFrame: PdfRenderFrame = PdfRenderFrame(
        pageIndex = 1,
        pageCount = 1,
        baseBitmap = null,
        strokes = emptyList(),
        highlights = emptyList(),
        texts = emptyList(),
        images = emptyList(),
    )

    fun attachInvalidator(callback: (() -> Unit)?) {
        invalidator = callback
    }

    fun loadPdf(path: String) {
        renderer.load(path)
        currentPdfPath = path
        currentPage = 1
        editor.clearOps()
        rebuildFrame(refreshBase = true)
    }

    fun onSurfaceSizeChanged(width: Int, height: Int) {
        if (width <= 0 || height <= 0) {
            return
        }
        if (surfaceWidth == width && surfaceHeight == height) {
            return
        }
        surfaceWidth = width
        surfaceHeight = height
        rebuildFrame(refreshBase = true)
    }

    fun getPageCount(): Int = renderer.pageCount().coerceAtLeast(1)

    fun setCurrentPage(page: Int) {
        val nextPage = page.coerceAtLeast(1).coerceAtMost(getPageCount())
        if (currentPage == nextPage) {
            return
        }
        currentPage = nextPage
        rebuildFrame(refreshBase = true)
    }

    fun currentPage(): Int = currentPage

    fun currentFrame(): PdfRenderFrame = renderFrame

    fun addStroke(points: List<StrokePoint>, color: Int, width: Float) {
        drawingHandler.addStroke(currentPage, color, width, points)
        rebuildFrame(refreshBase = false)
    }

    fun addHighlight(x: Double, y: Double, w: Double, h: Double, color: Int, opacity: Double) {
        annotationHandler.addHighlight(
            HighlightOperation(
                page = currentPage,
                x = x,
                y = y,
                w = w,
                h = h,
                color = color,
                opacity = opacity,
            )
        )
        rebuildFrame(refreshBase = false)
    }

    fun addText(text: String, x: Double, y: Double) {
        annotationHandler.addText(TextOperation(currentPage, text, x, y))
        rebuildFrame(refreshBase = false)
    }

    fun addImage(path: String, x: Double, y: Double) {
        annotationHandler.addImage(ImageOperation(currentPage, path, x, y))
        rebuildFrame(refreshBase = false)
    }

    fun addPage(afterPage: Int?) {
        val nextPage = (afterPage ?: currentPage + 1).coerceAtLeast(1)
        currentPage = nextPage
        rebuildFrame(refreshBase = true)
    }

    fun savePdf(): String {
        val sourcePath = currentPdfPath ?: return ""
        return editor.save(sourcePath)
    }

    fun dispose() {
        renderer.dispose()
        editor.clearOps()
        currentPdfPath = null
        currentBaseBitmap?.recycle()
        currentBaseBitmap = null
        renderFrame = PdfRenderFrame(
            pageIndex = 1,
            pageCount = 1,
            baseBitmap = null,
            strokes = emptyList(),
            highlights = emptyList(),
            texts = emptyList(),
            images = emptyList(),
        )
    }

    private fun rebuildFrame(refreshBase: Boolean) {
        if (refreshBase) {
            currentBaseBitmap?.recycle()
            currentBaseBitmap = if (surfaceWidth > 0 && surfaceHeight > 0) {
                renderer.renderPage(currentPage - 1, surfaceWidth, surfaceHeight)
            } else {
                null
            }
        }

        renderFrame = PdfRenderFrame(
            pageIndex = currentPage,
            pageCount = getPageCount(),
            baseBitmap = currentBaseBitmap,
            strokes = drawingHandler.getOperations().filter { it.page == currentPage },
            highlights = annotationHandler.highlightOperations().filter { it.page == currentPage },
            texts = annotationHandler.textOperations().filter { it.page == currentPage },
            images = annotationHandler.imageOperations().filter { it.page == currentPage },
        )
        invalidator?.invoke()
    }
}
