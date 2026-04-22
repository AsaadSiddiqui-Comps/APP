package com.pixeldev.Docly.pdf

data class HighlightOperation(
    val page: Int,
    val x: Double,
    val y: Double,
    val w: Double,
    val h: Double,
    val color: Int,
    val opacity: Double
)

data class TextOperation(
    val page: Int,
    val text: String,
    val x: Double,
    val y: Double,
    val color: Int = 0xFF000000.toInt(),
    val fontSize: Double = 16.0
)

data class ImageOperation(
    val page: Int,
    val path: String,
    val x: Double,
    val y: Double,
    val width: Double = 100.0,
    val height: Double = 100.0
)

class AnnotationHandler {
    private val highlights = mutableListOf<HighlightOperation>()
    private val texts = mutableListOf<TextOperation>()
    private val images = mutableListOf<ImageOperation>()

    fun addHighlight(op: HighlightOperation) {
        highlights += op
    }

    fun addText(op: TextOperation) {
        texts += op
    }

    fun addImage(op: ImageOperation) {
        images += op
    }

    fun highlightOperations(): List<HighlightOperation> = highlights.toList()

    fun textOperations(): List<TextOperation> = texts.toList()

    fun imageOperations(): List<ImageOperation> = images.toList()

    fun clear() {
        highlights.clear()
        texts.clear()
        images.clear()
    }
}
