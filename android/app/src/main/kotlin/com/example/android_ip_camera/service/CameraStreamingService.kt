package com.example.android_ip_camera.service

import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.android_ip_camera.IpCameraEngine
import com.example.android_ip_camera.MainActivity
import com.example.android_ip_camera.R

class CameraStreamingService : Service() {
    companion object {
        private const val TAG = "CameraStreamingService"
        const val CHANNEL_ID = "ip_camera_streaming"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.example.android_ip_camera.STOP_STREAM"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            IpCameraEngine.stopStream()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        // System may restart sticky services with a null intent while backgrounded.
        // Calling startForeground then crashes on Android 12+ / Vivo.
        if (intent == null && !IpCameraEngine.isStreaming()) {
            Log.w(TAG, "Ignoring null restart while not streaming")
            stopSelf()
            return START_NOT_STICKY
        }

        val rtspUrl = intent?.getStringExtra("rtspUrl")
            ?: IpCameraEngine.getStreamInfo()["rtspUrl"]?.toString()
            ?: "Streaming"

        return try {
            startForeground(NOTIFICATION_ID, buildNotification(rtspUrl))
            Log.i(TAG, "Foreground service started url=$rtspUrl")
            START_STICKY
        } catch (e: Exception) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                e is ForegroundServiceStartNotAllowedException
            ) {
                Log.e(TAG, "Foreground start not allowed; stopping service", e)
                stopSelf()
                return START_NOT_STICKY
            }
            Log.e(TAG, "Failed to start foreground service", e)
            stopSelf()
            START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "Foreground service destroyed")
        super.onDestroy()
    }

    private fun buildNotification(rtspUrl: String): Notification {
        createChannel()
        val launchIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, CameraStreamingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.notification_streaming, rtspUrl))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(launchIntent)
            .setOngoing(true)
            .addAction(0, getString(R.string.notification_stop), stopIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.notification_channel_desc)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
