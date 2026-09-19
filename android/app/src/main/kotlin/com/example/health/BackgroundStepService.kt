package com.example.health

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class BackgroundStepService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundWithHealthType()

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    }

    private fun startForegroundWithHealthType() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        registerSensorListener()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (!BackgroundStepStore.isBackgroundEnabled(this)) {
            return
        }
        val restartIntent = Intent(applicationContext, BackgroundStepService::class.java).apply {
            setPackage(packageName)
        }
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager
        alarmManager?.set(
            android.app.AlarmManager.RTC,
            System.currentTimeMillis() + 1000,
            pendingIntent,
        )
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        val value = event?.values?.firstOrNull() ?: return
        val stepsToday = BackgroundStepStore.updateFromRawStepCount(
            context = applicationContext,
            currentSteps = value.toInt(),
            eventTimeMillis = System.currentTimeMillis(),
        )
        updateNotification(stepsToday)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun registerSensorListener() {
        val sensor = stepCounterSensor ?: run {
            stopSelf()
            return
        }
        sensorManager?.unregisterListener(this)
        sensorManager?.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
    }

    private fun buildNotification(stepsToday: Int? = null): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val contentText = if (stepsToday != null) {
            "Tracking in background: $stepsToday steps today"
        } else {
            "Tracking your steps in the background"
        }

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Step tracking active")
            .setContentText(contentText)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(stepsToday: Int) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(notificationId, buildNotification(stepsToday))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(channelId)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            channelId,
            "Background step tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the step counter running when the app is in the background."
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val channelId = "background_step_tracking"
        private const val notificationId = 22041

        fun start(context: Context) {
            BackgroundStepStore.setBackgroundEnabled(context, true)
            val intent = Intent(context, BackgroundStepService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            BackgroundStepStore.setBackgroundEnabled(context, false)
            context.stopService(Intent(context, BackgroundStepService::class.java))
        }
    }
}
