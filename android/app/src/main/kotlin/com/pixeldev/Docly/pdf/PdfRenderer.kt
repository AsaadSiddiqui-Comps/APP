package com.pixeldev.Docly.pdf

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer as AndroidPdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File

class PdfRenderer {
    private var fd: ParcelFileDescriptor? = null
    private var renderer: AndroidPdfRenderer? = null

    fun load(path: String) {
        dispose()
        fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        renderer = AndroidPdfRenderer(fd!!)
    }

    fun pageCount(): Int = renderer?.pageCount ?: 0

    fun renderPage(pageIndex: Int, width: Int, height: Int): Bitmap? {
        val r = renderer ?: return null
        if (pageIndex !in 0 until r.pageCount) {
            return null
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        r.openPage(pageIndex).use { page ->
            page.render(bitmap, null, null, AndroidPdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        }
        return bitmap
    }

    fun dispose() {
        renderer?.close()
        renderer = null
        fd?.close()
        fd = null
    }
}
