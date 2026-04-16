package com.pixeldev.Docly

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import java.io.ByteArrayOutputStream

class ImageProcessor {

    fun processImage(
        action: String,
        bytes: ByteArray,
        params: Map<String, Any>
    ): ByteArray {
        return when (action) {
            "readSize" -> readSize(bytes)
            "crop" -> crop(bytes, params)
            "rotate" -> rotate(bytes, params)
            "filter" -> applyFilter(bytes, params)
            "resize" -> resize(bytes, params)
            "detectQuad" -> detectQuad(bytes)
            else -> bytes
        }
    }

    private fun readSize(bytes: ByteArray): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return ByteArray(0)
        val stream = ByteArrayOutputStream()
        stream.write((bitmap.width shr 24).toByte().toInt())
        stream.write((bitmap.width shr 16).toByte().toInt())
        stream.write((bitmap.width shr 8).toByte().toInt())
        stream.write(bitmap.width.toByte().toInt())
        stream.write((bitmap.height shr 24).toByte().toInt())
        stream.write((bitmap.height shr 16).toByte().toInt())
        stream.write((bitmap.height shr 8).toByte().toInt())
        stream.write(bitmap.height.toByte().toInt())
        bitmap.recycle()
        return stream.toByteArray()
    }

    private fun crop(bytes: ByteArray, params: Map<String, Any>): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return bytes
        
        try {
            val x = (params["x"] as? Number)?.toInt() ?: 0
            val y = (params["y"] as? Number)?.toInt() ?: 0
            val width = (params["width"] as? Number)?.toInt() ?: bitmap.width
            val height = (params["height"] as? Number)?.toInt() ?: bitmap.height

            val cropped = Bitmap.createBitmap(
                bitmap,
                x.coerceIn(0, bitmap.width - 1),
                y.coerceIn(0, bitmap.height - 1),
                width.coerceIn(1, bitmap.width - x),
                height.coerceIn(1, bitmap.height - y)
            )

            val stream = ByteArrayOutputStream()
            cropped.compress(Bitmap.CompressFormat.JPEG, 90, stream)
            bitmap.recycle()
            cropped.recycle()
            return stream.toByteArray()
        } catch (e: Exception) {
            bitmap.recycle()
            return bytes
        }
    }

    private fun rotate(bytes: ByteArray, params: Map<String, Any>): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return bytes
        
        try {
            val angle = (params["angle"] as? Number)?.toFloat() ?: 0f
            val matrix = Matrix()
            matrix.postRotate(angle)

            val rotated = Bitmap.createBitmap(
                bitmap,
                0,
                0,
                bitmap.width,
                bitmap.height,
                matrix,
                true
            )

            val stream = ByteArrayOutputStream()
            rotated.compress(Bitmap.CompressFormat.JPEG, 90, stream)
            bitmap.recycle()
            rotated.recycle()
            return stream.toByteArray()
        } catch (e: Exception) {
            bitmap.recycle()
            return bytes
        }
    }

    private fun applyFilter(bytes: ByteArray, params: Map<String, Any>): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return bytes
        
        try {
            val filterName = params["filterName"] as? String ?: "none"
            val previewWidth = (params["previewWidth"] as? Number)?.toInt() ?: null

            var workBitmap = bitmap
            
            // Resize for preview if requested
            if (previewWidth != null && bitmap.width > previewWidth) {
                val scaledHeight = (bitmap.height * previewWidth) / bitmap.width
                workBitmap = Bitmap.createScaledBitmap(bitmap, previewWidth, scaledHeight, true)
            }

            val filtered = applyFilterEffect(workBitmap, filterName)
            
            val stream = ByteArrayOutputStream()
            filtered.compress(Bitmap.CompressFormat.JPEG, if (previewWidth != null) 85 else 92, stream)
            
            bitmap.recycle()
            if (workBitmap != bitmap) workBitmap.recycle()
            filtered.recycle()
            
            return stream.toByteArray()
        } catch (e: Exception) {
            bitmap.recycle()
            return bytes
        }
    }

    private fun applyFilterEffect(bitmap: Bitmap, filterName: String): Bitmap {
        val config = bitmap.config ?: Bitmap.Config.ARGB_8888
        val result = Bitmap.createBitmap(bitmap.width, bitmap.height, config)
        val canvas = Canvas(result)
        val paint = Paint()

        when (filterName) {
            "enhanced" -> {
                val cm = ColorMatrix()
                cm.setSaturation(1.08f)
                cm.setScale(1.03f, 1.03f, 1.03f, 1f)
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "grayscale" -> {
                val cm = ColorMatrix()
                cm.setSaturation(0f)
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "blackWhite" -> {
                val cm = ColorMatrix()
                cm.setSaturation(0f)
                cm.set(FloatArray(20) { if (it % 5 == 4) 1f else if (it / 5 == it % 5) 1.55f else 0f })
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "vivid" -> {
                val cm = ColorMatrix()
                cm.setSaturation(1.25f)
                cm.setScale(1.05f, 1.05f, 1.05f, 1f)
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "cleanText" -> {
                val cm = ColorMatrix()
                cm.setSaturation(0f)
                cm.setScale(1.08f, 1.08f, 1.08f, 1f)
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "warm" -> {
                val cm = ColorMatrix()
                cm.setSaturation(1.1f)
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            else -> {} // none
        }

        canvas.drawBitmap(bitmap, 0f, 0f, paint)
        return result
    }

    private fun resize(bytes: ByteArray, params: Map<String, Any>): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return bytes
        
        try {
            val modeName = params["modeName"] as? String ?: "autoFit"
            
            var targetWidth = 1240
            var targetHeight = 1754

            when (modeName) {
                "a4" -> {
                    targetWidth = 1654
                    targetHeight = 2339
                }
                "a3" -> {
                    targetWidth = 2339
                    targetHeight = 3307
                }
            }

            val isLandscape = bitmap.width > bitmap.height
            if (isLandscape) {
                val temp = targetWidth
                targetWidth = targetHeight
                targetHeight = temp
            }

            val resized = Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
            
            val stream = ByteArrayOutputStream()
            resized.compress(Bitmap.CompressFormat.JPEG, 95, stream)
            
            bitmap.recycle()
            resized.recycle()
            
            return stream.toByteArray()
        } catch (e: Exception) {
            bitmap.recycle()
            return bytes
        }
    }

    private fun detectQuad(bytes: ByteArray): ByteArray {
        // For now return a default normalized quad (0.08, 0.08, 0.92, 0.92)
        // Full implementation would use ML Kit or OpenCV
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return ByteArray(0)
        
        bitmap.recycle()
        
        val stream = ByteArrayOutputStream()
        // Write 8 floats: topLeft.dx, topLeft.dy, topRight.dx, topRight.dy, bottomRight.dx, bottomRight.dy, bottomLeft.dx, bottomLeft.dy
        val values = floatArrayOf(0.08f, 0.08f, 0.92f, 0.08f, 0.92f, 0.92f, 0.08f, 0.92f)
        for (v in values) {
            val bits = v.toBits()
            stream.write((bits shr 24).toByte().toInt())
            stream.write((bits shr 16).toByte().toInt())
            stream.write((bits shr 8).toByte().toInt())
            stream.write(bits.toByte().toInt())
        }
        return stream.toByteArray()
    }
}
