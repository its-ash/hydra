package com.itsash.hydra

import android.content.Context
import android.content.SharedPreferences

/**
 * Settings shared with Dart (SharedPreferences file [FILE]). Dart owns the values and sends them through
 * `saveSettings`; native code only reads the ones it needs. Keys and types are the data contract
 * documented in CLAUDE.md and mirrored in lib/water/settings.dart.
 */
class HydraPrefs(context: Context) {
    private val sp: SharedPreferences = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /** Resolved daily goal in ml (Dart computes it from weight/activity or the manual value). */
    val goalMl: Int get() = sp.getInt("goalMl", 2000)
    val defaultCupMl: Int get() = sp.getInt("defaultCupMl", 250)
    val useOz: Boolean get() = sp.getString("unit", "ml") == "oz"
    val remindersOn: Boolean get() = sp.getBoolean("remindersOn", false)

    val reminderConfig: ReminderConfig
        get() = ReminderConfig(
            intervalMin = sp.getInt("intervalMin", 90),
            wakeMin = sp.getInt("wakeMin", 7 * 60),
            sleepMin = sp.getInt("sleepMin", 22 * 60),
        )

    /** Native only: end of the last "Snooze 30 min" (epoch ms), 0 when none. */
    var snoozeUntil: Long
        get() = sp.getLong("snoozeUntil", 0L)
        set(value) = sp.edit().putLong("snoozeUntil", value).apply()

    var askedNotifications: Boolean
        get() = sp.getBoolean("askedNotifications", false)
        set(value) = sp.edit().putBoolean("askedNotifications", value).apply()

    /** Everything Dart stored, for `getSettings`. */
    fun toMap(): Map<String, Any?> = sp.all.filterKeys { it !in NATIVE_ONLY }

    /** Saves a settings map from Dart. Ints, bools and strings only. */
    fun save(map: Map<String, Any?>) {
        val e = sp.edit()
        for ((key, value) in map) {
            when (value) {
                is Boolean -> e.putBoolean(key, value)
                is Number -> e.putInt(key, value.toInt())
                is String -> e.putString(key, value)
            }
        }
        e.apply()
    }

    companion object {
        const val FILE = "hydra_prefs"
        private val NATIVE_ONLY = setOf("snoozeUntil", "askedNotifications")
    }
}
