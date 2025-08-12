// android/app/src/main/kotlin/com/example/events/MainActivity.kt
package com.example.events

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "alarmChannel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setAlarm") {
                    val timeInMillis = call.argument<Long>("timeInMillis")
                    val title = call.argument<String>("title")
                    if (timeInMillis != null && title != null) {
                        setAlarm(timeInMillis, title)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Arguments missing", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun setAlarm(timeInMillis: Long, title: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("title", title)
        }
        // Use a unique request code based on time
        val requestCode = timeInMillis.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
        }
    }
}
