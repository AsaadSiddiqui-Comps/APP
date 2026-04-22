package com.pixeldev.Docly.pdf

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.view.View
import kotlin.math.abs

class PdfRenderView(
    context: Context,
    private val engine: PdfEngine,
) : View(context) {
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 18f
    }
    private val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    init {
        engine.attachInvalidator {
            postInvalidateOnAnimation()
        }
    }

    override fun onDetachedFromWindow() {
        engine.attachInvalidator(null)
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w > 0 && h > 0) {
            engine.onSurfaceSizeChanged(w, h)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(Color.BLACK)

        val frame = engine.currentFrame()
        val base = frame.baseBitmap
        if (base == null) {
            drawLoading(canvas)
            return
        }

        canvas.drawBitmap(base, null, Rect(0, 0, width, height), bitmapPaint)
        drawHighlights(canvas, frame)
        drawStrokes(canvas, frame)
        drawTexts(canvas, frame)
        drawImages(canvas, frame)
    }

    private fun drawLoading(canvas: Canvas) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 18f
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("Loading PDF...", width / 2f, height / 2f, paint)
    }

    private fun drawHighlights(canvas: Canvas, frame: PdfRenderFrame) {
        frame.highlights.forEach { op ->
            highlightPaint.color = op.color
            highlightPaint.alpha = (255 * op.opacity).toInt().coerceIn(0, 255)
            canvas.drawRect(
                RectF(op.x.toFloat(), op.y.toFloat(), (op.x + op.w).toFloat(), (op.y + op.h).toFloat()),
                highlightPaint,
            )
        }
    }

    private fun drawStrokes(canvas: Canvas, frame: PdfRenderFrame) {
        frame.strokes.forEach { op ->
            if (op.points.size < 2) {
                return@forEach
            }

            strokePaint.color = op.color
            strokePaint.strokeWidth = op.width
            val path = Path()
            val first = op.points.first()
            path.moveTo(first.x, first.y)
            var previous = first
            for (index in 1 until op.points.size) {
                val point = op.points[index]
                val midX = (previous.x + point.x) / 2f
                val midY = (previous.y + point.y) / 2f
                path.quadTo(previous.x, previous.y, midX, midY)
                previous = point
            }
            path.lineTo(previous.x, previous.y)
            canvas.drawPath(path, strokePaint)
        }
    }

    private fun drawTexts(canvas: Canvas, frame: PdfRenderFrame) {
        frame.texts.forEach { op ->
            textPaint.color = op.color
            textPaint.textSize = op.fontSize.toFloat()
            canvas.drawText(op.text, op.x.toFloat(), op.y.toFloat(), textPaint)
        }
    }

    private fun drawImages(canvas: Canvas, frame: PdfRenderFrame) {
        frame.images.forEach { op ->
            val file = java.io.File(op.path)
            if (!file.exists()) {
                return@forEach
            }
            val bitmap = BitmapFactory.decodeFile(file.absolutePath) ?: return@forEach
            val left = op.x.toFloat()
            val top = op.y.toFloat()
            val right = left + op.width.toFloat().coerceAtLeast(1f)
            val bottom = top + op.height.toFloat().coerceAtLeast(1f)
            canvas.drawBitmap(bitmap, null, RectF(left, top, right, bottom), bitmapPaint)
        }
    }
}
