package com.itsash.hydra

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

data class LogEntry(val id: Long, val ts: Long, val ml: Int)

/**
 * The water log: SQLite file "hydra.db", table `logs(id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER, ml INTEGER)`
 * (`ts` = epoch ms). Native code (notification action, widget) and Dart (through the channel) use this one store.
 */
class WaterDb private constructor(context: Context) : SQLiteOpenHelper(context, "hydra.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE logs (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, ml INTEGER NOT NULL)")
        db.execSQL("CREATE INDEX logs_ts ON logs (ts)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun add(ts: Long, ml: Int): Long = writableDatabase.insert(
        "logs", null,
        ContentValues().apply {
            put("ts", ts)
            put("ml", ml)
        },
    )

    fun delete(id: Long) {
        writableDatabase.delete("logs", "id = ?", arrayOf(id.toString()))
    }

    /** Entries with `ts >= fromMs`, oldest first. */
    fun logsSince(fromMs: Long): List<LogEntry> {
        val out = ArrayList<LogEntry>()
        readableDatabase.rawQuery(
            "SELECT id, ts, ml FROM logs WHERE ts >= ? ORDER BY ts ASC, id ASC",
            arrayOf(fromMs.toString()),
        ).use { c ->
            while (c.moveToNext()) out.add(LogEntry(c.getLong(0), c.getLong(1), c.getInt(2)))
        }
        return out
    }

    /** Total ml logged on the local day containing [nowMs]. */
    fun totalToday(nowMs: Long): Int {
        val from = Days.startOfDay(nowMs)
        val to = Days.startOfDay(nowMs, plusDays = 1)
        readableDatabase.rawQuery(
            "SELECT COALESCE(SUM(ml), 0) FROM logs WHERE ts >= ? AND ts < ?",
            arrayOf(from.toString(), to.toString()),
        ).use { c -> return if (c.moveToFirst()) c.getInt(0) else 0 }
    }

    /** Time of the latest entry, 0 when the log is empty. */
    fun lastLogTs(): Long {
        readableDatabase.rawQuery("SELECT COALESCE(MAX(ts), 0) FROM logs", null)
            .use { c -> return if (c.moveToFirst()) c.getLong(0) else 0L }
    }

    companion object {
        @Volatile private var instance: WaterDb? = null

        fun get(context: Context): WaterDb =
            instance ?: synchronized(this) {
                instance ?: WaterDb(context.applicationContext).also { instance = it }
            }
    }
}
