// android/app/src/main/kotlin/com/example/events/AlarmReceiver.kt
package com.example.events

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val title = intent?.getStringExtra("title") ?: "Alarm"
        Log.d("AlarmReceiver", "Alarm fired for: $title")
        if (context != null) {
            // Start the alarm service to play the alarm sound even if the app is closed
            val serviceIntent = Intent(context, AlarmService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
