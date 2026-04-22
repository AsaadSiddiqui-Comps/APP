package com.pixeldev.Docly.pdf

data class StrokePoint(
    val x: Float,
    val y: Float
)

data class StrokeOperation(
    val page: Int,
    val color: Int,
    val width: Float,
    val points: List<StrokePoint>
)

class DrawingHandler {
    private val operations = mutableListOf<StrokeOperation>()

    fun addStroke(page: Int, color: Int, width: Float, points: List<StrokePoint>) {
        if (points.size < 2) {
            return
        }
        operations += StrokeOperation(page = page, color = color, width = width, points = points)
    }

    fun getOperations(): List<StrokeOperation> = operations.toList()

    fun clear() {
        operations.clear()
    }
}
