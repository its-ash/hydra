package com.itsash.hydra

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel "com.itsash.hydra/control" (Dart side: lib/water/water_platform.dart):
 *   - getSettings() -> Map of every saved setting (see HydraPrefs).
 *   - saveSettings(Map): saves, reschedules reminders, redraws the widget.
 *   - getLogs({from}) -> [{id, ts, ml}] with ts >= from (epoch ms), oldest first.
 *   - addLog({ml, ts?}) -> id. ts defaults to now.
 *   - deleteLog({id}).
 *   - status() -> {notifications, exactAlarms}.
 *   - requestNotifications(): system dialog the first time, then the app's notification settings.
 *   - openExactAlarmSettings().
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.itsash.hydra/control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val prefs = HydraPrefs(this)
        val db = WaterDb.get(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getSettings" -> result.success(prefs.toMap())
                    "saveSettings" -> {
                        prefs.save(call.arguments<Map<String, Any?>>() ?: emptyMap())
                        HydraSync.refresh(this)
                        result.success(null)
                    }
                    "getLogs" -> {
                        val from = (call.argument<Number>("from") ?: 0).toLong()
                        result.success(db.logsSince(from).map { mapOf("id" to it.id, "ts" to it.ts, "ml" to it.ml) })
                    }
                    "addLog" -> {
                        val ml = call.argument<Number>("ml")?.toInt() ?: 0
                        val ts = call.argument<Number>("ts")?.toLong() ?: System.currentTimeMillis()
                        if (ml <= 0) {
                            result.error("bad_amount", "ml must be positive", null)
                        } else {
                            val id = db.add(ts, ml)
                            Notifier.cancel(this)
                            HydraSync.refresh(this)
                            result.success(id)
                        }
                    }
                    "deleteLog" -> {
                        db.delete((call.argument<Number>("id") ?: 0).toLong())
                        HydraSync.refresh(this)
                        result.success(null)
                    }
                    "status" -> result.success(status())
                    "requestNotifications" -> {
                        requestNotifications(prefs)
                        result.success(null)
                    }
                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                result.error("failed", e.message, null)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Reminders might have been waiting for the permission.
        HydraSync.refresh(this)
    }

    private fun notificationsAllowed(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        }

    private fun status(): Map<String, Any?> = mapOf(
        "notifications" to notificationsAllowed(),
        "exactAlarms" to ReminderScheduler.canScheduleExact(getSystemService(AlarmManager::class.java)),
    )

    /** Asks with the system dialog once (Android 13+); after a denial the dialog no longer shows, so open settings. */
    private fun requestNotifications(prefs: HydraPrefs) {
        if (notificationsAllowed()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !prefs.askedNotifications) {
            prefs.askedNotifications = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        } else {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
            )
        }
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")),
            )
        }
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 1
    }
}
