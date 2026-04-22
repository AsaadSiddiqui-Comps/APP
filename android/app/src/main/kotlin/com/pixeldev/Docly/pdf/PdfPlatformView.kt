package com.pixeldev.Docly.pdf

import android.content.Context
import android.view.View
import io.flutter.plugin.platform.PlatformView

class PdfPlatformView(
    context: Context,
    private val engine: PdfEngine,
) : PlatformView {
    private val view = PdfRenderView(context, engine)

    override fun getView(): View = view

    override fun dispose() {
        engine.attachInvalidator(null)
    }
}
