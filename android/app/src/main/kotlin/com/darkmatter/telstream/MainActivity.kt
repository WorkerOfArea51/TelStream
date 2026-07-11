package com.darkmatter.telstream

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.content.FileProvider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var downloadReceiver: BroadcastReceiver? = null
    private val CHANNEL = "com.darkmatter.telstream/updater"
    private val DOWNLOAD_CHANNEL = "com.darkmatter.telstream/downloads"

    private val lastUpdateTimes = java.util.Collections.synchronizedMap(mutableMapOf<Int, Long>())
    private val lastProgressValues = java.util.Collections.synchronizedMap(mutableMapOf<Int, Double>())

    override fun onDestroy() {
        downloadReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore if not registered
            }
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
        
        val filter = IntentFilter("com.darkmatter.telstream.DOWNLOAD_ACTION")
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let {
                    val action = it.getStringExtra("action") ?: ""
                    val fileId = it.getIntExtra("fileId", -1)
                    if (action.isNotEmpty() && fileId != -1) {
                        val flutterAction = when (action) {
                            "com.darkmatter.telstream.action.PAUSE" -> "pause"
                            "com.darkmatter.telstream.action.RESUME" -> "resume"
                            "com.darkmatter.telstream.action.CANCEL" -> "cancel"
                            else -> ""
                        }
                        if (flutterAction.isNotEmpty()) {
                            methodChannel.invokeMethod("onNotificationAction", mapOf(
                                "action" to flutterAction,
                                "fileId" to fileId
                            ))
                        }
                    }
                }
            }
        }

        downloadReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {}
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            androidx.core.content.ContextCompat.registerReceiver(this, receiver, filter, androidx.core.content.ContextCompat.RECEIVER_NOT_EXPORTED)
        }
        downloadReceiver = receiver
        
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
                "getStorageSpace" -> {
                    try {
                        // Check the EXTERNAL storage (where downloads actually go)
                        val target = getExternalFilesDir(null) ?: filesDir
                        val stat = StatFs(target.absolutePath)
                        val space = mapOf(
                            "total" to (stat.blockCountLong * stat.blockSizeLong),
                            "free" to (stat.availableBlocksLong * stat.blockSizeLong),
                            "path" to target.absolutePath
                        )
                        result.success(space)
                    } catch (e: Exception) {
                        result.error("STORAGE_FAILED", e.message, null)
                    }
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
                    val isPaused = call.argument<Boolean>("isPaused") ?: false

                    // Throttle: max 4 updates/sec per fileId, skip if no meaningful change
                    val now = android.os.SystemClock.elapsedRealtime()
                    val lastTime = lastUpdateTimes[fileId] ?: 0L
                    val lastProgress = lastProgressValues[fileId] ?: -1.0
                    val isTerminal = isCompleted || isCancelled || isPaused
                    val progressChanged = kotlin.math.abs(progress - lastProgress) >= 0.01
                    val throttleOk = (now - lastTime) >= 250L

                    if (!isTerminal && !progressChanged) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (!isTerminal && !throttleOk) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    lastUpdateTimes[fileId] = now
                    lastProgressValues[fileId] = progress

                    val serviceIntent = Intent(this, DownloadService::class.java).apply {
                        putExtra("fileId", fileId)
                        putExtra("title", title)
                        putExtra("progress", progress)
                        putExtra("isCompleted", isCompleted)
                        putExtra("isCancelled", isCancelled)
                        putExtra("isPaused", isPaused)
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                    } catch (e: IllegalStateException) {
                        android.util.Log.w("MainActivity", "startForegroundService rejected", e)
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
        
        // Security Sandbox: Restrict installable APKs exclusively to our updates directories
        val canonicalPath = file.canonicalPath
        val allowedCacheDir = File(context.cacheDir, "updates").canonicalPath + File.separator
        val allowedExtDir = context.getExternalFilesDir(null)?.let { File(it, "updates").canonicalPath + File.separator }
        
        val isCache = canonicalPath.startsWith(allowedCacheDir)
        val isExt = allowedExtDir != null && canonicalPath.startsWith(allowedExtDir)
        
        if (canonicalPath.isEmpty() || (!isCache && !isExt)) {
            throw SecurityException("Install path not whitelisted: $canonicalPath")
        }

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
