package com.example.events

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "AlarmChannel"
        const val NOTIFICATION_ID = 101
        const val ACTION_STOP_ALARM = "com.example.events.ACTION_STOP_ALARM"
    }

    // Initialize the default alarm sound.
    private var ringtone = RingtoneManager.getRingtone(
        this,
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
    )

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Check if this intent is to stop the alarm.
        if (intent?.action == ACTION_STOP_ALARM) {
            stopAlarm()
            return START_NOT_STICKY
        }

        val eventName = intent?.getStringExtra("EVENT_NAME") ?: "Event"

        // Play the alarm sound.
        ringtone.play()

        // Vibrate the device.
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(2000, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(2000)
        }

        // Build a notification with a Stop Alarm action.
        val stopIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Alarm: $eventName")
            .setContentText("Tap 'Stop Alarm' to cancel the alarm.")
            // Use the default app logo (ic_launcher) as the notification icon.
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .addAction(NotificationCompat.Action(0, "Stop Alarm", stopPendingIntent))
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Return START_NOT_STICKY so that the service is not recreated if killed.
        return START_NOT_STICKY
    }

    private fun stopAlarm() {
        ringtone.stop()
        stopForeground(true)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Channel for Alarm notifications"
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
