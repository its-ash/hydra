package com.itsash.hydra

import java.util.Calendar
import java.util.TimeZone

const val MINUTE_MS = 60_000L
const val DAY_MINUTES = 24 * 60
private const val ML_PER_OZ = 29.5735

/** Local-day arithmetic, DST-safe because it goes through [Calendar]. */
object Days {
    /** Midnight at the start of the local day [plusDays] days after the one containing [ms]. */
    fun startOfDay(ms: Long, tz: TimeZone = TimeZone.getDefault(), plusDays: Int = 0): Long {
        val c = Calendar.getInstance(tz)
        c.timeInMillis = ms
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        if (plusDays != 0) c.add(Calendar.DAY_OF_MONTH, plusDays)
        return c.timeInMillis
    }

    fun minuteOfDay(ms: Long, tz: TimeZone = TimeZone.getDefault()): Int {
        val c = Calendar.getInstance(tz)
        c.timeInMillis = ms
        return c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
    }
}

/** Reminder settings: a reminder every [intervalMin] minutes from [wakeMin] to [sleepMin] (minutes after midnight). */
data class ReminderConfig(val intervalMin: Int, val wakeMin: Int, val sleepMin: Int) {
    /** Length of the awake window in minutes, 1..1440. The window may cross midnight; wake == sleep means all day. */
    val windowMin: Int
        get() {
            val d = ((sleepMin - wakeMin) % DAY_MINUTES + DAY_MINUTES) % DAY_MINUTES
            return if (d == 0) DAY_MINUTES else d
        }
}

enum class Decision { NOTIFY, SKIP_GOAL_REACHED, SKIP_QUIET_HOURS, SKIP_RECENT_LOG }

/** Pure reminder rules (no Android types) so they can be unit tested on the JVM. */
object ReminderPlanner {
    const val RECENT_LOG_MS = 30 * MINUTE_MS
    const val SNOOZE_MS = 30 * MINUTE_MS

    /** True when [ms] falls inside the awake window. */
    fun isAwake(ms: Long, c: ReminderConfig, tz: TimeZone = TimeZone.getDefault()): Boolean {
        val sinceWake = ((Days.minuteOfDay(ms, tz) - c.wakeMin) % DAY_MINUTES + DAY_MINUTES) % DAY_MINUTES
        return sinceWake <= c.windowMin
    }

    /** Reminder slots of the window that starts on the local day containing [dayMs]: wake, wake + N, ... */
    fun slotsOfDay(dayMs: Long, c: ReminderConfig, tz: TimeZone = TimeZone.getDefault(), plusDays: Int = 0): List<Long> {
        val cal = Calendar.getInstance(tz)
        cal.timeInMillis = Days.startOfDay(dayMs, tz, plusDays)
        cal.set(Calendar.HOUR_OF_DAY, c.wakeMin / 60)
        cal.set(Calendar.MINUTE, c.wakeMin % 60)
        val base = cal.timeInMillis
        val interval = c.intervalMin.coerceAtLeast(1)
        val window = c.windowMin
        val slots = ArrayList<Long>()
        var offset = 0
        // A full-day window must not repeat the wake slot of the next day.
        while (if (window == DAY_MINUTES) offset < window else offset <= window) {
            slots.add(base + offset * MINUTE_MS)
            offset += interval
        }
        return slots
    }

    /** First slot strictly after [afterMs]. */
    fun nextSlotAfter(afterMs: Long, c: ReminderConfig, tz: TimeZone = TimeZone.getDefault()): Long {
        var best = Long.MAX_VALUE
        // A window that crosses midnight started yesterday, so look one day back and one ahead.
        for (day in -1..1) {
            for (t in slotsOfDay(afterMs, c, tz, day)) {
                if (t > afterMs && t < best) best = t
            }
        }
        return if (best == Long.MAX_VALUE) afterMs + c.intervalMin.coerceAtLeast(1) * MINUTE_MS else best
    }

    /**
     * When the next reminder alarm should fire. After the goal is reached the next one is tomorrow's first slot.
     * A snooze replaces the pending slot: it fires when the snooze ends (or at the next slot if that is asleep time).
     */
    fun nextTrigger(
        nowMs: Long,
        c: ReminderConfig,
        snoozeUntilMs: Long,
        goalReached: Boolean,
        tz: TimeZone = TimeZone.getDefault(),
    ): Long {
        var after = nowMs
        if (goalReached) after = maxOf(after, Days.startOfDay(nowMs, tz, 1) - 1)
        if (snoozeUntilMs > after) {
            return if (isAwake(snoozeUntilMs, c, tz)) snoozeUntilMs else nextSlotAfter(snoozeUntilMs, c, tz)
        }
        return nextSlotAfter(after, c, tz)
    }

    /** What to do when a reminder alarm fires. */
    fun decide(
        nowMs: Long,
        lastLogMs: Long,
        todayMl: Int,
        goalMl: Int,
        c: ReminderConfig,
        tz: TimeZone = TimeZone.getDefault(),
    ): Decision = when {
        todayMl >= goalMl -> Decision.SKIP_GOAL_REACHED
        !isAwake(nowMs, c, tz) -> Decision.SKIP_QUIET_HOURS
        lastLogMs > 0 && nowMs - lastLogMs < RECENT_LOG_MS -> Decision.SKIP_RECENT_LOG
        else -> Decision.NOTIFY
    }
}

/** Volume text shared by the notification and the widget. */
object Volume {
    fun format(ml: Int, oz: Boolean): String =
        if (oz) "${Math.round(ml / ML_PER_OZ)} oz" else "$ml ml"

    fun number(ml: Int, oz: Boolean): Int = if (oz) Math.round(ml / ML_PER_OZ).toInt() else ml

    fun percent(todayMl: Int, goalMl: Int): Int =
        if (goalMl <= 0) 0 else (todayMl.toLong() * 100 / goalMl).toInt().coerceIn(0, 100)
}
