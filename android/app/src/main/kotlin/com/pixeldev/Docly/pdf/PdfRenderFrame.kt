package com.pixeldev.Docly.pdf

import android.graphics.Bitmap

data class PdfRenderFrame(
    val pageIndex: Int,
    val pageCount: Int,
    val baseBitmap: Bitmap?,
    val strokes: List<StrokeOperation>,
    val highlights: List<HighlightOperation>,
    val texts: List<TextOperation>,
    val images: List<ImageOperation>,
)
