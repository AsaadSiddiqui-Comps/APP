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
                    val color = (call.argument<Number>("color") ?: 0xFF000000).toInt()
                    val width = (call.argument<Number>("width") ?: 3.0).toFloat()
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
                    val color = (call.argument<Number>("color") ?: 0xFFFFFF00).toInt()
                    val opacity = (call.argument<Number>("opacity") ?: 0.35).toDouble()
                    engine.addHighlight(x, y, w, h, color, opacity)
                    result.success(null)
                }
                "addText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    val color = (call.argument<Number>("color") ?: 0xFF000000).toInt()
                    val fontSize = (call.argument<Number>("fontSize") ?: 16.0).toDouble()
                    engine.addText(text, x, y, color, fontSize)
                    result.success(null)
                }
                "addImage" -> {
                    val path = call.argument<String>("path") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    val width = (call.argument<Number>("width") ?: 100.0).toDouble()
                    val height = (call.argument<Number>("height") ?: 100.0).toDouble()
                    engine.addImage(path, x, y, width, height)
                    result.success(null)
                }
                "updateText" -> {
                    val id = call.argument<String>("id") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    val color = (call.argument<Number>("color") ?: 0xFF000000).toInt()
                    val fontSize = (call.argument<Number>("fontSize") ?: 16.0).toDouble()
                    if (id.isNotBlank()) {
                        engine.updateText(id, text, x, y, color, fontSize)
                    }
                    result.success(null)
                }
                "updateImage" -> {
                    val id = call.argument<String>("id") ?: ""
                    val path = call.argument<String>("path") ?: ""
                    val x = (call.argument<Number>("x") ?: 0.0).toDouble()
                    val y = (call.argument<Number>("y") ?: 0.0).toDouble()
                    val width = (call.argument<Number>("width") ?: 100.0).toDouble()
                    val height = (call.argument<Number>("height") ?: 100.0).toDouble()
                    if (id.isNotBlank()) {
                        engine.updateImage(id, path, x, y, width, height)
                    }
                    result.success(null)
                }
                "deleteText" -> {
                    val id = call.argument<String>("id") ?: ""
                    if (id.isNotBlank()) {
                        engine.deleteText(id)
                    }
                    result.success(null)
                }
                "deleteImage" -> {
                    val id = call.argument<String>("id") ?: ""
                    if (id.isNotBlank()) {
                        engine.deleteImage(id)
                    }
                    result.success(null)
                }
                "addPage" -> {
                    val afterPage = call.argument<Number>("afterPage")?.toInt()
                    engine.addPage(afterPage)
                    result.success(null)
                }
                "savePdf" -> {
                    result.success(engine.savePdf())
                }
                "setCurrentPage" -> {
                    val page = call.argument<Number>("page")?.toInt() ?: 1
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
