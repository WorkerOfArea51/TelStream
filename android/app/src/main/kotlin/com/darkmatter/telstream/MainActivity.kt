package com.darkmatter.telstream

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.darkmatter.telstream/updater"
    private val DOWNLOAD_CHANNEL = "com.darkmatter.telstream/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("filePath")
                    if (path != null) {
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is null", null)
                    }
                }
                "getAndroidSdkVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                "updateDownloadNotification" -> {
                    val fileId = call.argument<Int>("fileId") ?: -1
                    val title = call.argument<String>("title") ?: "Download"
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val isCompleted = call.argument<Boolean>("isCompleted") ?: false
                    val isCancelled = call.argument<Boolean>("isCancelled") ?: false

                    val serviceIntent = Intent(this, DownloadService::class.java).apply {
                        putExtra("fileId", fileId)
                        putExtra("title", title)
                        putExtra("progress", progress)
                        putExtra("isCompleted", isCompleted)
                        putExtra("isCancelled", isCancelled)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("File does not exist: $filePath")
        }
        val context = applicationContext
        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        } else {
            Uri.fromFile(file)
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
