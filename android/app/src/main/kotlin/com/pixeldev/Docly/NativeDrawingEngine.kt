package com.pixeldev.Docly

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class NativeDrawingEngine(flutterEngine: FlutterEngine) {
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.docly.pdf_drawing/native_renderer"
    )

    private var bitmap: Bitmap? = null
    private var canvas: Canvas? = null

    private data class Stroke(
        val points: List<Pair<Float, Float>>,
        val color: Int,
        val width: Float,
        val opacity: Float
    )

    private val strokes = mutableListOf<Stroke>()
    private val redoStrokes = mutableListOf<Stroke>()

    fun attach() {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initDrawingContext" -> {
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        result.success(initDrawingContext(width, height))
                    }
                    "drawStroke" -> {
                        val points = call.argument<List<Double>>("points") ?: emptyList()
                        val color = call.argument<Int>("color") ?: Color.BLACK
                        val strokeWidth = (call.argument<Double>("strokeWidth") ?: 3.0).toFloat()
                        val opacity = (call.argument<Double>("opacity") ?: 1.0).toFloat()
                        drawStroke(points, color, strokeWidth, opacity)
                        result.success(null)
                    }
                    "erase" -> {
                        val centerX = (call.argument<Double>("centerX") ?: 0.0).toFloat()
                        val centerY = (call.argument<Double>("centerY") ?: 0.0).toFloat()
                        val radius = (call.argument<Double>("radius") ?: 20.0).toFloat()
                        erase(centerX, centerY, radius)
                        result.success(null)
                    }
                    "renderToPNG" -> result.success(renderToPNG())
                    "clearBuffer" -> {
                        clearBuffer()
                        result.success(null)
                    }
                    "undo" -> result.success(undo())
                    "redo" -> result.success(redo())
                    "getStrokeCount" -> result.success(strokes.size)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_draw_error", e.message, null)
            }
        }
    }

    private fun initDrawingContext(width: Int, height: Int): Boolean {
        if (width <= 0 || height <= 0) return false

        bitmap?.recycle()
        bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        canvas = Canvas(bitmap!!)
        canvas?.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)

        strokes.clear()
        redoStrokes.clear()
        return true
    }

    private fun drawStroke(flatPoints: List<Double>, color: Int, strokeWidth: Float, opacity: Float) {
        if (flatPoints.size < 4 || canvas == null) return

        val points = mutableListOf<Pair<Float, Float>>()
        var i = 0
        while (i + 1 < flatPoints.size) {
            points.add(Pair(flatPoints[i].toFloat(), flatPoints[i + 1].toFloat()))
            i += 2
        }

        if (points.size < 2) return

        val stroke = Stroke(points, color, strokeWidth, opacity)
        strokes.add(stroke)
        redoStrokes.clear()
        drawStrokeToCanvas(stroke)
    }

    private fun drawStrokeToCanvas(stroke: Stroke) {
        val c = canvas ?: return

        val paint = Paint().apply {
            this.color = withOpacity(stroke.color, stroke.opacity)
            this.strokeWidth = stroke.width
            this.style = Paint.Style.STROKE
            this.strokeCap = Paint.Cap.ROUND
            this.strokeJoin = Paint.Join.ROUND
            this.isAntiAlias = true
        }

        val path = Path().apply {
            moveTo(stroke.points.first().first, stroke.points.first().second)
            for (idx in 1 until stroke.points.size) {
                lineTo(stroke.points[idx].first, stroke.points[idx].second)
            }
        }

        c.drawPath(path, paint)
    }

    private fun erase(centerX: Float, centerY: Float, radius: Float) {
        val c = canvas ?: return
        val erasePaint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
            isAntiAlias = true
        }
        c.drawCircle(centerX, centerY, radius, erasePaint)
    }

    private fun renderToPNG(): ByteArray? {
        val bmp = bitmap ?: return null
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun clearBuffer() {
        canvas?.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        strokes.clear()
        redoStrokes.clear()
    }

    private fun undo(): Boolean {
        if (strokes.isEmpty()) return false
        val last = strokes.removeLast()
        redoStrokes.add(last)
        redrawAll()
        return true
    }

    private fun redo(): Boolean {
        if (redoStrokes.isEmpty()) return false
        val stroke = redoStrokes.removeLast()
        strokes.add(stroke)
        drawStrokeToCanvas(stroke)
        return true
    }

    private fun redrawAll() {
        canvas?.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        strokes.forEach { drawStrokeToCanvas(it) }
    }

    private fun withOpacity(color: Int, opacity: Float): Int {
        val alpha = (Color.alpha(color) * opacity).toInt().coerceIn(0, 255)
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        bitmap?.recycle()
        bitmap = null
        canvas = null
        strokes.clear()
        redoStrokes.clear()
    }
}
