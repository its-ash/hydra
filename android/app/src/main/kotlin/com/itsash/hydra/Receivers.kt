package com.itsash.hydra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires when a reminder alarm goes off: notifies unless a rule says to skip, then schedules the next one. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderScheduler.ACTION_REMIND) return
        val prefs = HydraPrefs(context)
        if (prefs.remindersOn) {
            val now = System.currentTimeMillis()
            val db = WaterDb.get(context)
            val total = db.totalToday(now)
            val decision = ReminderPlanner.decide(
                nowMs = now,
                lastLogMs = db.lastLogTs(),
                todayMl = total,
                goalMl = prefs.goalMl,
                c = prefs.reminderConfig,
            )
            if (decision == Decision.NOTIFY) Notifier.show(context, total, prefs)
        }
        HydraSync.refresh(context)
    }
}

/** Notification and widget buttons: logs water or snoozes, without opening the app. */
class ActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = HydraPrefs(context)
        val now = System.currentTimeMillis()
        when (intent.action) {
            Notifier.ACTION_ADD -> {
                val ml = intent.getIntExtra(Notifier.EXTRA_ML, prefs.defaultCupMl)
                if (ml > 0) WaterDb.get(context).add(now, ml)
                prefs.snoozeUntil = 0L
                Notifier.cancel(context)
            }
            Notifier.ACTION_SNOOZE -> {
                prefs.snoozeUntil = now + ReminderPlanner.SNOOZE_MS
                Notifier.cancel(context)
            }
            else -> return
        }
        HydraSync.refresh(context)
    }
}

/** Restores alarms and the widget after a reboot, an app update, or a clock / time zone / date change. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            -> HydraSync.refresh(context)
        }
    }
}
