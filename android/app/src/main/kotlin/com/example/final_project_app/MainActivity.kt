package com.example.final_project_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createSafetyAlertChannel()
    }

    private fun createSafetyAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(SAFETY_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            SAFETY_CHANNEL_ID,
            "미하차 안전 경고",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "통학버스 미하차 의심 등 긴급 안전 알림"
            enableVibration(true)
            enableLights(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val SAFETY_CHANNEL_ID = "safety_alerts"
    }
}
