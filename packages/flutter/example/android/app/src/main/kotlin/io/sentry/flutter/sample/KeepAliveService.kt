package io.sentry.flutter.sample

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * A no-op foreground service whose only job is to keep the process classified
 * as foreground after the app's task is removed, so Android does not kill the
 * process outright and does not deliver the background trim callbacks that
 * would otherwise let Flutter purge caches. Started on demand by MainActivity
 * when running lib/memleak_repro_main.dart. This mirrors the "BLE +
 * foreground service" setup from the reproduction in
 * https://github.com/getsentry/sentry-dart/issues/3960.
 */
class KeepAliveService : Service() {
  companion object {
    private const val CHANNEL_ID = "memleak_repro_keep_alive"
    private const val NOTIFICATION_ID = 1

    fun start(context: Context) {
      context.startForegroundService(Intent(context, KeepAliveService::class.java))
    }
  }

  override fun onCreate() {
    super.onCreate()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Mem Leak Repro Keep-Alive",
        NotificationManager.IMPORTANCE_MIN,
      )
      getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, CHANNEL_ID)
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
    }
    val notification = builder
      .setContentTitle("Mem leak repro running")
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .build()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
  }

  // Restarting on its own would restart the process's foreground
  // classification independent of MemLeakReproActivity's lifecycle, which
  // would muddy the measurement.
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY

  override fun onBind(intent: Intent?): IBinder? = null
}
