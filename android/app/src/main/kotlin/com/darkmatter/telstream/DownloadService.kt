package com.darkmatter.telstream

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class DownloadService : Service() {
    private val NOTIFICATION_ID = 2001
    private val CHANNEL_ID = "telstream_downloads"
    private val CHANNEL_NAME = "Active Downloads"

    companion object {
        const val ACTION_PAUSE = "com.darkmatter.telstream.action.PAUSE"
        const val ACTION_RESUME = "com.darkmatter.telstream.action.RESUME"
        const val ACTION_CANCEL = "com.darkmatter.telstream.action.CANCEL"
        const val NOTIFICATION_ACTION = "com.darkmatter.telstream.DOWNLOAD_ACTION"
    }
    
    // Store active download titles, progress values, and paused states
    private val activeDownloads = mutableMapOf<Int, Triple<String, Double, Boolean>>()

    inner class LocalBinder : Binder() {
        fun getService(): DownloadService = this@DownloadService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            val action = it.action
            val fileId = it.getIntExtra("fileId", -1)

            if (action != null && fileId != -1) {
                // Send broadcast to MainActivity to forward to Flutter
                val broadcastIntent = Intent(NOTIFICATION_ACTION).apply {
                    putExtra("action", action)
                    putExtra("fileId", fileId)
                    setPackage(packageName)
                }
                sendBroadcast(broadcastIntent)

                // If it is cancel, remove from activeDownloads immediately
                if (action == ACTION_CANCEL) {
                    activeDownloads.remove(fileId)
                }
            } else {
                val title = it.getStringExtra("title") ?: "Download"
                val progress = it.getDoubleExtra("progress", 0.0)
                val isCompleted = it.getBooleanExtra("isCompleted", false)
                val isCancelled = it.getBooleanExtra("isCancelled", false)
                val isPaused = it.getBooleanExtra("isPaused", false)

                if (fileId != -1) {
                    if (isCancelled || isCompleted) {
                        activeDownloads.remove(fileId)
                    } else {
                        activeDownloads[fileId] = Triple(title, progress, isPaused)
                    }
                }
            }

            if (activeDownloads.isEmpty()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            } else {
                showOrUpdateNotification()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress of active video downloads"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun showOrUpdateNotification() {
        val count = activeDownloads.size
        val titleText = if (count == 1) {
            "Downloading: ${activeDownloads.values.first().first}"
        } else {
            "Downloading $count videos"
        }

        // Calculate average progress
        val totalProgress = activeDownloads.values.sumOf { it.second }
        val avgProgress = if (count > 0) totalProgress / count else 0.0
        val progressPercent = (avgProgress * 100).toInt()

        val anyPaused = activeDownloads.values.any { it.third }
        val contentText = if (anyPaused) "Paused" else "${progressPercent}% completed"

        // Open app when notification clicked
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(titleText)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_sys_download) // Standard Android download icon
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setProgress(100, progressPercent, false)

        if (count == 1) {
            val fileId = activeDownloads.keys.first()
            val download = activeDownloads.values.first()
            val isPaused = download.third

            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Pause/Resume action button
            val actionIntent = Intent(this, DownloadService::class.java).apply {
                action = if (isPaused) ACTION_RESUME else ACTION_PAUSE
                putExtra("fileId", fileId)
            }
            val actionPendingIntent = PendingIntent.getService(
                this,
                1001,
                actionIntent,
                flag
            )
            val actionTitle = if (isPaused) "Resume" else "Pause"
            val actionIcon = if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause
            notificationBuilder.addAction(actionIcon, actionTitle, actionPendingIntent)

            // Cancel action button
            val cancelIntent = Intent(this, DownloadService::class.java).apply {
                action = ACTION_CANCEL
                putExtra("fileId", fileId)
            }
            val cancelPendingIntent = PendingIntent.getService(
                this,
                1002,
                cancelIntent,
                flag
            )
            notificationBuilder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelPendingIntent
            )
        }

        val notification = notificationBuilder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, 
                notification, 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Clear active notifications
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        
        // Clear download cache folders on app kill from recents
        try {
            val appFlutterDir = File(applicationContext.filesDir.parentFile, "app_flutter")
            val targetDirs = listOf("videos", "documents", "temp", "voice", "music", "video_notes", "stickers", "animations")
            for (dirName in targetDirs) {
                val dir = File(appFlutterDir, dirName)
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        if (file.isFile) {
                            val path = file.absolutePath.lowercase(java.util.Locale.ROOT)
                            val isDatabase = path.endsWith(".db") || 
                                             path.endsWith(".db-journal") || 
                                             path.endsWith(".db-wal") || 
                                             path.endsWith(".db-shm") || 
                                             path.endsWith(".bin") ||
                                             path.endsWith(".binlog") ||
                                             path.endsWith(".key")
                            if (!isDatabase) {
                                file.delete()
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        stopSelf()
    }
}
