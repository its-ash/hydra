package com.itsash.hydra

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

/** Schedules the single pending reminder alarm. Call [reschedule] after anything that changes the plan. */
object ReminderScheduler {
    const val ACTION_REMIND = "com.itsash.hydra.REMIND"

    fun reschedule(context: Context) {
        val app = context.applicationContext
        val am = app.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(app)
        am.cancel(pending)

        val prefs = HydraPrefs(app)
        if (!prefs.remindersOn) return

        val now = System.currentTimeMillis()
        val total = WaterDb.get(app).totalToday(now)
        val at = ReminderPlanner.nextTrigger(
            nowMs = now,
            c = prefs.reminderConfig,
            snoozeUntilMs = prefs.snoozeUntil,
            goalReached = total >= prefs.goalMl,
        )
        try {
            if (canScheduleExact(am)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        } catch (_: SecurityException) {
            // Exact alarms were revoked between the check and the call: fall back to inexact.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    fun canScheduleExact(am: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_ALARM,
        Intent(context, ReminderReceiver::class.java).setAction(ACTION_REMIND),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private const val REQUEST_ALARM = 1
}

/** The reminder notification with its two actions, which work without opening the app. */
object Notifier {
    const val ACTION_ADD = "com.itsash.hydra.ADD"
    const val ACTION_SNOOZE = "com.itsash.hydra.SNOOZE"
    const val EXTRA_ML = "ml"

    private const val CHANNEL = "reminders"
    private const val NOTIFICATION_ID = 1
    private const val REQUEST_ADD = 11
    private const val REQUEST_SNOOZE = 12
    private const val REQUEST_OPEN = 13

    /** Pending intent that logs [ml] natively. Also used by the home-screen widget. */
    fun addIntent(context: Context, ml: Int, requestCode: Int = REQUEST_ADD): PendingIntent = PendingIntent.getBroadcast(
        context,
        requestCode,
        Intent(context, ActionReceiver::class.java).setAction(ACTION_ADD).putExtra(EXTRA_ML, ml),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        REQUEST_OPEN,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun show(context: Context, todayMl: Int, prefs: HydraPrefs) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, context.getString(R.string.channel_reminders), NotificationManager.IMPORTANCE_DEFAULT),
        )
        val oz = prefs.useOz
        val cup = prefs.defaultCupMl
        val icon = Icon.createWithResource(context, R.drawable.ic_stat_water)
        val snooze = PendingIntent.getBroadcast(
            context,
            REQUEST_SNOOZE,
            Intent(context, ActionReceiver::class.java).setAction(ACTION_SNOOZE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_water)
            .setContentTitle(context.getString(R.string.reminder_title))
            .setContentText(
                context.getString(
                    R.string.reminder_text,
                    Volume.format(todayMl, oz),
                    Volume.format(prefs.goalMl, oz),
                ),
            )
            .setContentIntent(openAppIntent(context))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .addAction(
                Notification.Action.Builder(
                    icon,
                    context.getString(R.string.action_add, Volume.format(cup, oz)),
                    addIntent(context, cup),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(icon, context.getString(R.string.action_snooze), snooze).build(),
            )
            .build()
        nm.notify(NOTIFICATION_ID, notification)
    }

    fun cancel(context: Context) {
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }
}

/** Reschedules the reminder and redraws the widget. */
object HydraSync {
    fun refresh(context: Context) {
        runCatching { ReminderScheduler.reschedule(context) }
        runCatching { HydraWidget.updateAll(context) }
    }
}
