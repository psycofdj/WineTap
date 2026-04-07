package com.winetap.mobile

import android.app.Activity
import android.content.Intent
import android.util.Log
import java.io.FileInputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.winetap.mobile/file_io"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAction: String? = null
    private var pendingBytes: ByteArray? = null

    companion object {
        private const val TAG = "WineTapFileIO"
        private const val PICK_FILE_REQUEST = 71
        private const val CREATE_FILE_REQUEST = 72
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFileBytes" -> {
                        pendingResult = result
                        pendingAction = "pick"
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivityForResult(intent, PICK_FILE_REQUEST)
                    }
                    "saveFile" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "file"
                        if (bytes == null) {
                            result.error("invalid_argument", "bytes is required", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        pendingAction = "save"
                        pendingBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        startActivityForResult(intent, CREATE_FILE_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Handle our request codes BEFORE super to prevent Flutter plugins from
        // consuming the result or invalidating the URI permission grant.
        when (requestCode) {
            PICK_FILE_REQUEST -> {
                handlePickResult(resultCode, data)
                return
            }
            CREATE_FILE_REQUEST -> {
                handleSaveResult(resultCode, data)
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun handlePickResult(resultCode: Int, data: Intent?) {
        val result = pendingResult ?: return
        pendingResult = null
        pendingAction = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri = data.data!!
        Log.d(TAG, "Picked URI: $uri (flags: ${data.flags})")

        // Take persistable permission so the URI stays readable.
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "takePersistableUriPermission failed (non-fatal): ${e.message}")
        }

        // Try openInputStream first, fall back to ParcelFileDescriptor.
        var bytes: ByteArray? = null
        try {
            bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            Log.w(TAG, "openInputStream failed: ${e.message}, trying openFileDescriptor")
        }

        if (bytes == null) {
            try {
                bytes = contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                    FileInputStream(pfd.fileDescriptor).use { it.readBytes() }
                }
            } catch (e: Exception) {
                Log.e(TAG, "openFileDescriptor also failed: ${e.message}")
            }
        }

        if (bytes != null) {
            result.success(bytes)
        } else {
            result.error("read_failed", "Could not read file — it may have been moved or deleted", null)
        }
    }

    private fun handleSaveResult(resultCode: Int, data: Intent?) {
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingAction = null
        pendingBytes = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(false)
            return
        }

        try {
            val uri = data.data!!
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("Could not open output stream")
            result.success(true)
        } catch (e: Exception) {
            result.error("write_failed", e.message, null)
        }
    }
}
