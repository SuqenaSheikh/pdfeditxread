package com.example.pdf_editor

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "folio/open_pdf"
    private var pendingPath: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialPdf" -> {
                    result.success(pendingPath)
                    pendingPath = null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "folio/save_images")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveImages") {
                    val paths = (call.arguments as? Map<*, *>)?.get("paths") as? List<*>
                    val files = paths?.mapNotNull { it as? String } ?: emptyList()
                    result.success(saveImagesToGallery(files))
                } else {
                    result.notImplemented()
                }
            }
        handleIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
        pendingPath?.let {
            channel?.invokeMethod("onOpenPdf", it)
            pendingPath = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val uri: Uri? = when {
            action == Intent.ACTION_VIEW -> intent.data
            action == Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            else -> null
        }
        if (uri == null) return
        pendingPath = copyUriToCache(uri)
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val input = contentResolver.openInputStream(uri) ?: return null
            val outFile = File(cacheDir, "open_${System.currentTimeMillis()}.pdf")
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
            input.close()
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /// Writes images into Pictures/Folio via MediaStore. No storage permission
    /// is required on Android 10+ (API 29).
    private fun saveImagesToGallery(paths: List<String>): Int {
        var saved = 0
        for (path in paths) {
            val file = File(path)
            if (!file.exists()) continue
            val mime = if (path.lowercase().endsWith(".png")) "image/png" else "image/jpeg"
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/Folio",
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            ) ?: continue
            try {
                val stream = contentResolver.openOutputStream(uri)
                if (stream == null) {
                    contentResolver.delete(uri, null, null)
                    continue
                }
                stream.use { output ->
                    FileInputStream(file).use { input -> input.copyTo(output) }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                }
                saved += 1
            } catch (_: Exception) {
                contentResolver.delete(uri, null, null)
            }
        }
        return saved
    }
}
