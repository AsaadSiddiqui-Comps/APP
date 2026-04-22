package com.pixeldev.Docly.pdf

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PlatformBridge(private val flutterEngine: FlutterEngine) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pdf_editor")
    val engine = PdfEngine()

    fun attach() {
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "loadPdf" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_args", "path is required", null)
                    } else {
                        engine.loadPdf(path)
                        result.success(null)
                    }
                }
                "drawStroke" -> {
                    val pointsRaw = call.argument<List<Map<String, Any>>>("points") ?: emptyList()
                    val color = call.argument<Int>("color") ?: 0xFF000000.toInt()
                    val width = (call.argument<Double>("width") ?: 3.0).toFloat()
                    val points = pointsRaw.mapNotNull { m ->
                        val x = (m["x"] as? Number)?.toFloat()
                        val y = (m["y"] as? Number)?.toFloat()
                        if (x == null || y == null) null else StrokePoint(x, y)
                    }
                    engine.addStroke(points, color, width)
                    result.success(null)
                }
                "addHighlight" -> {
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    val w = (call.argument<Number>("w") ?: 0.0).toDouble()
                    val h = (call.argument<Number>("h") ?: 0.0).toDouble()
                    val color = call.argument<Int>("color") ?: 0xFFFFFF00.toInt()
                    val opacity = (call.argument<Number>("opacity") ?: 0.35).toDouble()
                    engine.addHighlight(x, y, w, h, color, opacity)
                    result.success(null)
                }
                "addText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    engine.addText(text, x, y)
                    result.success(null)
                }
                "addImage" -> {
                    val path = call.argument<String>("path") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    engine.addImage(path, x, y)
                    result.success(null)
                }
                "addPage" -> {
                    val afterPage = call.argument<Int>("afterPage")
                    engine.addPage(afterPage)
                    result.success(null)
                }
                "savePdf" -> {
                    result.success(engine.savePdf())
                }
                "setCurrentPage" -> {
                    val page = call.argument<Int>("page") ?: 1
                    engine.setCurrentPage(page)
                    result.success(null)
                }
                "getPageCount" -> {
                    result.success(engine.getPageCount())
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        engine.dispose()
    }
}
