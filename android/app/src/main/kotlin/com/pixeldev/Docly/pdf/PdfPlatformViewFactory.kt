package com.pixeldev.Docly.pdf

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PdfPlatformViewFactory(
    private val engine: PdfEngine,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return PdfPlatformView(context, engine)
    }
}
