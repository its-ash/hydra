package com.itsash.hydra

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private val UTC: TimeZone = TimeZone.getTimeZone("UTC")

/** Epoch ms for a UTC date and time. */
private fun at(day: Int, hour: Int, minute: Int = 0): Long {
    val c = Calendar.getInstance(UTC)
    c.clear()
    c.set(2026, Calendar.MARCH, day, hour, minute, 0)
    return c.timeInMillis
}

private val DAYTIME = ReminderConfig(intervalMin = 120, wakeMin = 7 * 60, sleepMin = 21 * 60)
private val NIGHT_SHIFT = ReminderConfig(intervalMin = 120, wakeMin = 20 * 60, sleepMin = 4 * 60)

class PlannerTest {

    @Test
    fun windowLength() {
        assertEquals(14 * 60, DAYTIME.windowMin)
        assertEquals(8 * 60, NIGHT_SHIFT.windowMin)
        assertEquals(DAY_MINUTES, ReminderConfig(60, 300, 300).windowMin)
    }

    @Test
    fun awakeWindow() {
        assertTrue(ReminderPlanner.isAwake(at(10, 7), DAYTIME, UTC))
        assertTrue(ReminderPlanner.isAwake(at(10, 21), DAYTIME, UTC))
        assertFalse(ReminderPlanner.isAwake(at(10, 21, 1), DAYTIME, UTC))
        assertFalse(ReminderPlanner.isAwake(at(10, 3), DAYTIME, UTC))
    }

    @Test
    fun awakeWindowAcrossMidnight() {
        assertTrue(ReminderPlanner.isAwake(at(10, 23), NIGHT_SHIFT, UTC))
        assertTrue(ReminderPlanner.isAwake(at(11, 2), NIGHT_SHIFT, UTC))
        assertFalse(ReminderPlanner.isAwake(at(11, 12), NIGHT_SHIFT, UTC))
    }

    @Test
    fun slotsRunFromWakeToSleep() {
        val slots = ReminderPlanner.slotsOfDay(at(10, 12), DAYTIME, UTC)
        assertEquals(at(10, 7), slots.first())
        assertEquals(at(10, 21), slots.last())
        assertEquals(8, slots.size)
    }

    @Test
    fun nextSlotIsStrictlyAfter() {
        assertEquals(at(10, 11), ReminderPlanner.nextSlotAfter(at(10, 9), DAYTIME, UTC))
        assertEquals(at(10, 11), ReminderPlanner.nextSlotAfter(at(10, 9, 30), DAYTIME, UTC))
        assertEquals(at(10, 11), ReminderPlanner.nextSlotAfter(at(10, 9) + 1, DAYTIME, UTC))
    }

    @Test
    fun afterSleepNextSlotIsTomorrowsWake() {
        assertEquals(at(11, 7), ReminderPlanner.nextSlotAfter(at(10, 22), DAYTIME, UTC))
        assertEquals(at(11, 7), ReminderPlanner.nextSlotAfter(at(11, 3), DAYTIME, UTC))
    }

    @Test
    fun nightShiftSlotsContinuePastMidnight() {
        assertEquals(at(11, 0), ReminderPlanner.nextSlotAfter(at(10, 22, 30), NIGHT_SHIFT, UTC))
        assertEquals(at(11, 20), ReminderPlanner.nextSlotAfter(at(11, 5), NIGHT_SHIFT, UTC))
    }

    @Test
    fun goalReachedPostponesToTomorrow() {
        val next = ReminderPlanner.nextTrigger(at(10, 12), DAYTIME, 0, goalReached = true, tz = UTC)
        assertEquals(at(11, 7), next)
    }

    @Test
    fun snoozeFiresWhenItEnds() {
        val now = at(10, 12)
        val next = ReminderPlanner.nextTrigger(now, DAYTIME, now + ReminderPlanner.SNOOZE_MS, goalReached = false, tz = UTC)
        assertEquals(now + ReminderPlanner.SNOOZE_MS, next)
    }

    @Test
    fun snoozeIntoQuietHoursMovesToNextSlot() {
        val now = at(10, 20, 50)
        val next = ReminderPlanner.nextTrigger(now, DAYTIME, now + ReminderPlanner.SNOOZE_MS, goalReached = false, tz = UTC)
        assertEquals(at(11, 7), next)
    }

    @Test
    fun expiredSnoozeIsIgnored() {
        val now = at(10, 12)
        assertEquals(at(10, 13), ReminderPlanner.nextTrigger(now, DAYTIME.copy(intervalMin = 60), now - 1, false, UTC))
    }

    @Test
    fun decisionRules() {
        val now = at(10, 12)
        val longAgo = now - 2 * 60 * MINUTE_MS
        assertEquals(Decision.NOTIFY, ReminderPlanner.decide(now, longAgo, 800, 2000, DAYTIME, UTC))
        assertEquals(Decision.NOTIFY, ReminderPlanner.decide(now, 0, 0, 2000, DAYTIME, UTC))
        assertEquals(Decision.SKIP_RECENT_LOG, ReminderPlanner.decide(now, now - 10 * MINUTE_MS, 800, 2000, DAYTIME, UTC))
        assertEquals(Decision.SKIP_GOAL_REACHED, ReminderPlanner.decide(now, longAgo, 2000, 2000, DAYTIME, UTC))
        assertEquals(Decision.SKIP_QUIET_HOURS, ReminderPlanner.decide(at(10, 23), longAgo, 800, 2000, DAYTIME, UTC))
    }

    @Test
    fun recentLogBoundaryIsThirtyMinutes() {
        val now = at(10, 12)
        assertEquals(Decision.NOTIFY, ReminderPlanner.decide(now, now - 30 * MINUTE_MS, 800, 2000, DAYTIME, UTC))
        assertEquals(Decision.SKIP_RECENT_LOG, ReminderPlanner.decide(now, now - 30 * MINUTE_MS + 1, 800, 2000, DAYTIME, UTC))
    }

    @Test
    fun volumeFormatting() {
        assertEquals("250 ml", Volume.format(250, oz = false))
        assertEquals("8 oz", Volume.format(237, oz = true))
        assertEquals(50, Volume.percent(1000, 2000))
        assertEquals(100, Volume.percent(3000, 2000))
        assertEquals(0, Volume.percent(100, 0))
    }
}
