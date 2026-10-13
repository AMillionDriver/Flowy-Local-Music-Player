package com.example.flowy

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.flowy.music/media_manager"
    private val REQUEST_DELETE_MEDIA = 2001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "deleteAudioMedia" -> {
                    val mediaId = (call.argument<Number>("mediaId"))?.toLong()
                    val filePath = call.argument<String>("filePath")
                    deleteAudioMedia(mediaId, filePath, result)
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        android.media.MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(filePath),
                            arrayOf("audio/mpeg")
                        ) { scannedPath, uri ->
                            // File media berhasil dipindai dan dimasukkan ke Android MediaStore
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "getPublicMusicDir" -> {
                    try {
                        val musicDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_MUSIC)
                        val flowyDir = java.io.File(musicDir, "Flowy")
                        if (!flowyDir.exists()) {
                            flowyDir.mkdirs()
                        }
                        result.success(flowyDir.absolutePath)
                    } catch (e: Exception) {
                        try {
                            val downloadDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                            val flowyDir = java.io.File(downloadDir, "Flowy")
                            if (!flowyDir.exists()) {
                                flowyDir.mkdirs()
                            }
                            result.success(flowyDir.absolutePath)
                        } catch (ex: Exception) {
                            result.success(null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun deleteAudioMedia(mediaId: Long?, filePath: String?, result: MethodChannel.Result) {
        pendingResult = result

        // 1. Resolve content URI from mediaId or filePath
        val contentUri: Uri? = if (mediaId != null && mediaId > 0) {
            ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, mediaId)
        } else if (filePath != null) {
            getMediaUriFromPath(filePath)
        } else null

        if (contentUri == null) {
            // If MediaStore URI not found, try raw file deletion as fallback
            if (filePath != null) {
                try {
                    val f = File(filePath)
                    if (f.exists() && f.delete()) {
                        result.success(true)
                        pendingResult = null
                        return
                    }
                } catch (e: Exception) {
                    // Ignore, proceed to report error
                }
            }
            result.error("URI_NOT_FOUND", "Tidak dapat menemukan berkas di MediaStore", null)
            pendingResult = null
            return
        }

        try {
            // Android 11+ (API 30, 31, 32, 33, 34+) - System User Consent Dialog
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, listOf(contentUri))
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    REQUEST_DELETE_MEDIA,
                    null, 0, 0, 0, null
                )
            }
            // Android 10 (API 29)
            else if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
                try {
                    val rowsDeleted = contentResolver.delete(contentUri, null, null)
                    result.success(rowsDeleted > 0)
                    pendingResult = null
                } catch (e: RecoverableSecurityException) {
                    val intentSender = e.userAction.actionIntent.intentSender
                    startIntentSenderForResult(intentSender, REQUEST_DELETE_MEDIA, null, 0, 0, 0, null)
                }
            }
            // Android 9 and below
            else {
                var isDeleted = false
                if (filePath != null) {
                    val file = File(filePath)
                    if (file.exists()) isDeleted = file.delete()
                }
                if (!isDeleted) {
                    val rows = contentResolver.delete(contentUri, null, null)
                    isDeleted = rows > 0
                }
                result.success(isDeleted)
                pendingResult = null
            }
        } catch (e: Exception) {
            result.error("DELETE_FAILED", e.localizedMessage, null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DELETE_MEDIA) {
            val isSuccess = (resultCode == Activity.RESULT_OK)
            pendingResult?.success(isSuccess)
            pendingResult = null
        }
    }

    private fun getMediaUriFromPath(path: String): Uri? {
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        val selectionArgs = arrayOf(path)
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                return ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
            }
        }
        return null
    }
}
