package com.pixeldev.Docly.pdf

import java.io.File

class PdfEditor(
    private val drawingHandler: DrawingHandler,
    private val annotationHandler: AnnotationHandler,
) {
    // This method is intentionally isolated so a full PDFium implementation can be dropped in.
    fun save(sourcePath: String): String {
        val src = File(sourcePath)
        val out = File(src.parentFile ?: src.parent?.let(::File), "edited_${System.currentTimeMillis()}.pdf")
        src.copyTo(out, overwrite = true)

        // Placeholder hook for real PDF mutation pipeline.
        // drawOperations = drawingHandler.getOperations()
        // highlightOperations = annotationHandler.highlightOperations()
        // textOperations = annotationHandler.textOperations()
        // imageOperations = annotationHandler.imageOperations()

        return out.absolutePath
    }

    fun clearOps() {
        drawingHandler.clear()
        annotationHandler.clear()
    }
}
