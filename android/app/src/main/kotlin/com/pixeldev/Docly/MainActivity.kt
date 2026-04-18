package com.pixeldev.Docly

import android.content.Intent
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val storageChannel = "com.pixeldev.Docly/storage"
    private val imageChannel = "com.pixeldev.Docly/image"
    private val fileOpenChannel = "com.pixeldev.Docly/file_open"
    private val imageProcessor = ImageProcessor()
    private var pendingPdfPath: String? = null
    private var nativeDrawingEngine: NativeDrawingEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureIncomingPdf(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIncomingPdf(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativeDrawingEngine = NativeDrawingEngine(flutterEngine)
        nativeDrawingEngine?.attach()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "saveFileToDownloads" -> saveFileToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, imageChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "processImage" -> processImage(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileOpenChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "consumePendingPdfPath" -> {
                        val path = pendingPdfPath
                        pendingPdfPath = null
                        result.success(path)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        nativeDrawingEngine?.dispose()
        nativeDrawingEngine = null
        super.onDestroy()
    }

    private fun captureIncomingPdf(intent: Intent?) {
        if (intent == null) {
            return
        }

        try {
            when (intent.action) {
                Intent.ACTION_VIEW -> {
                    val uri = intent.data
                    if (uri != null && isPdfIntent(uri, intent.type)) {
                        pendingPdfPath = copyUriToCache(uri)
                    }
                }
                Intent.ACTION_SEND -> {
                    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_STREAM)
                    }
                    if (uri != null && isPdfIntent(uri, intent.type)) {
                        pendingPdfPath = copyUriToCache(uri)
                    }
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun isPdfIntent(uri: Uri, mimeType: String?): Boolean {
        val lowerType = mimeType?.lowercase() ?: ""
        if (lowerType.contains("application/pdf")) {
            return true
        }
        val path = uri.toString().lowercase()
        return path.endsWith(".pdf")
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val name = "external_${System.currentTimeMillis()}.pdf"
            val target = File(cacheDir, name)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { out ->
                    input.copyTo(out)
                }
            }
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun processImage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val action = call.argument<String>("action")
            val bytes = call.argument<ByteArray>("bytes")
            val params = call.argument<Map<String, Any>>("params") as? Map<String, Any> ?: emptyMap()

            if (action.isNullOrEmpty() || bytes == null) {
                result.error("invalid_args", "action and bytes are required", null)
                return
            }

            val processed = imageProcessor.processImage(action, bytes, params)
            result.success(processed)
        } catch (e: Exception) {
            result.error("processing_error", e.message, null)
        }
    }

    private fun saveFileToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val displayName = call.argument<String>("displayName")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val subFolder = call.argument<String>("subFolder") ?: "Docly"

        if (sourcePath.isNullOrBlank() || displayName.isNullOrBlank()) {
            result.error("invalid_args", "sourcePath and displayName are required", null)
            return
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            result.error("missing_source", "Source file does not exist", null)
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val relativePath = Environment.DIRECTORY_DOWNLOADS + File.separator + subFolder

                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Could not create MediaStore entry")

                resolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: throw IllegalStateException("Could not open output stream")

                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)

                result.success("Downloads/$subFolder/$displayName")
                return
            }

            val legacyDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                subFolder
            )
            if (!legacyDir.exists()) {
                legacyDir.mkdirs()
            }

            val target = File(legacyDir, displayName)
            sourceFile.copyTo(target, overwrite = true)
            result.success(target.absolutePath)
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }
}