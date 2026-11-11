package com.itsash.hydra

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews

/** Home-screen widget: today's total against the goal, plus a button that logs the default cup. */
class HydraWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) manager.updateAppWidget(id, views)
    }

    companion object {
        private const val REQUEST_WIDGET_ADD = 21

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HydraWidget::class.java))
            if (ids.isEmpty()) return
            val views = build(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        private fun build(context: Context): RemoteViews {
            val prefs = HydraPrefs(context)
            val total = WaterDb.get(context).totalToday(System.currentTimeMillis())
            val goal = prefs.goalMl
            val oz = prefs.useOz
            val percent = Volume.percent(total, goal)

            return RemoteViews(context.packageName, R.layout.widget_hydra).apply {
                setTextViewText(R.id.widget_amount, Volume.format(total, oz))
                setTextViewText(R.id.widget_goal, context.getString(R.string.widget_goal, Volume.format(goal, oz), percent))
                setProgressBar(R.id.widget_progress, 100, percent, false)
                setTextViewText(R.id.widget_add, context.getString(R.string.widget_add, Volume.format(prefs.defaultCupMl, oz)))
                setOnClickPendingIntent(R.id.widget_add, Notifier.addIntent(context, prefs.defaultCupMl, REQUEST_WIDGET_ADD))
                setOnClickPendingIntent(R.id.widget_info, Notifier.openAppIntent(context))
            }
        }
    }
}
