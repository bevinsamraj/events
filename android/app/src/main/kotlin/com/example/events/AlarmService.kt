// android/app/src/main/kotlin/com/example/events/AlarmService.kt
package com.example.events

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AlarmService : Service() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate() {
        super.onCreate()
        // Get the default alarm sound URI
        val alarmSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        mediaPlayer = MediaPlayer().apply {
            setDataSource(this@AlarmService, alarmSoundUri)
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = true
            prepare()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "alarm_service_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Channel for Alarm Service"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Alarm")
            .setContentText("Your alarm is ringing")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .build()

        startForeground(1, notification)

        // Start playing the alarm sound
        mediaPlayer?.start()

        // For demonstration, stop the alarm after 60 seconds.
        Thread {
            Thread.sleep(60000)
            stopSelf()
        }.start()

        return START_STICKY
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
