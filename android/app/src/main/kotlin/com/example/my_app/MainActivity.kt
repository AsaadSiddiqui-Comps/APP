package com.example.my_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
	private val storageChannel = "com.example.my_app/storage"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"saveFileToDownloads" -> saveFileToDownloads(call, result)
					else -> result.notImplemented()
				}
			}
	}

	private fun saveFileToDownloads(call: MethodCall, result: MethodChannel.Result) {
		val sourcePath = call.argument<String>("sourcePath")
		val displayName = call.argument<String>("displayName")
		val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
		val subFolder = call.argument<String>("subFolder") ?: "my_app"

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
