package com.example.events

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmClockReceiver : BroadcastReceiver() {
    companion object {
        const val ALARM_INTENT = "com.example.events.ALARM_INTENT"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val eventName = intent?.getStringExtra("EVENT_NAME") ?: "Event"
        context?.let {
            val serviceIntent = Intent(it, AlarmForegroundService::class.java).apply {
                putExtra("EVENT_NAME", eventName)
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                it.startForegroundService(serviceIntent)
            } else {
                it.startService(serviceIntent)
            }
        }
    }
}
