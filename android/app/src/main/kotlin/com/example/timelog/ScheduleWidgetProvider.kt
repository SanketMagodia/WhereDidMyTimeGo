package com.example.timelog

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class ScheduleWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val ACTION_TILE_CLICKED = "com.example.timelog.ACTION_TILE_CLICKED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TILE_CLICKED) {
            val offset = intent.getIntExtra("tile_offset", 0)
            val widgetData = HomeWidgetPlugin.getData(context)

            // Use commit() (synchronous) so onDataSetChanged reads the new
            // value immediately — avoids the "still showing old day" race.
            widgetData.edit().putInt("selected_day_offset", offset).commit()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(
                context, ScheduleWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            // Notify the list adapter first, then redraw chrome (highlights).
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetIds, R.id.schedule_list)
            for (id in appWidgetIds) {
                onUpdate(context, appWidgetManager, intArrayOf(id), widgetData)
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        val selectedOffset = widgetData.getInt("selected_day_offset", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_schedule)

            // ── ListView adapter ──────────────────────────────────────────────
            val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("selected_day_offset", selectedOffset)
                // Unique URI per offset forces Android to create a fresh factory.
                data = Uri.parse(
                    toUri(Intent.URI_INTENT_SCHEME) + "?wid=$appWidgetId&off=$selectedOffset")
            }
            views.setRemoteAdapter(R.id.schedule_list, serviceIntent)

            // Item tap → open app on the schedule/tasks screen
            // Must use home_widget LAUNCH action so Flutter sees the URI via
            // initiallyLaunchedFromHomeWidget / widgetClicked (not ACTION_VIEW).
            val openScheduleIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("wdmtg://schedule")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val schedulePendingIntent = PendingIntent.getActivity(
                context, 100, openScheduleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setPendingIntentTemplate(R.id.schedule_list, schedulePendingIntent)

            // ── Action buttons: Expense / Schedule / Notes ───────────────────
            val openExpenseIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("wdmtg://expenses")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val expensePendingIntent = PendingIntent.getActivity(
                context, 200, openExpenseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_add_expense, expensePendingIntent)

            val openScheduleTabIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("wdmtg://schedule")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val scheduleTabPendingIntent = PendingIntent.getActivity(
                context, 201, openScheduleTabIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_open_schedule, scheduleTabPendingIntent)

            val openNotesIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("wdmtg://todos")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val notesPendingIntent = PendingIntent.getActivity(
                context, 202, openNotesIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_open_notes, notesPendingIntent)

            // ── Day-selector tiles ────────────────────────────────────────────
            val tilesJsonStr = widgetData.getString("schedule_tiles_json", null)
            if (tilesJsonStr != null) {
                try {
                    val tilesArray = JSONArray(tilesJsonStr)
                    val boxIds = intArrayOf(
                        R.id.tile_0_box, R.id.tile_1_box,
                        R.id.tile_2_box, R.id.tile_3_box)
                    val dayIds = intArrayOf(
                        R.id.tile_0_day, R.id.tile_1_day,
                        R.id.tile_2_day, R.id.tile_3_day)
                    val countIds = intArrayOf(
                        R.id.tile_0_count, R.id.tile_1_count,
                        R.id.tile_2_count, R.id.tile_3_count)

                    for (i in 0 until 4) {
                        if (i < tilesArray.length()) {
                            val t = tilesArray.getJSONObject(i)
                            views.setTextViewText(dayIds[i], t.getString("label"))
                            views.setTextViewText(countIds[i], "${t.getInt("count")}")

                            val isSelected = (i == selectedOffset)
                            views.setInt(
                                boxIds[i], "setBackgroundResource",
                                if (isSelected) R.drawable.widget_item_selected_bg
                                else R.drawable.widget_item_unselected_bg)
                            views.setTextColor(
                                dayIds[i],
                                if (isSelected) android.graphics.Color.WHITE
                                else android.graphics.Color.parseColor("#A0A0A0"))
                            views.setTextColor(
                                countIds[i],
                                if (isSelected) android.graphics.Color.LTGRAY
                                else android.graphics.Color.parseColor("#808080"))

                            // Click → switch day
                            val clickIntent = Intent(
                                context, ScheduleWidgetProvider::class.java).apply {
                                action = ACTION_TILE_CLICKED
                                putExtra("tile_offset", i)
                            }
                            // Use i+10 as request code to avoid collisions with
                            // the schedule (100) and expense (200) pending intents.
                            val clickPending = PendingIntent.getBroadcast(
                                context, i + 10, clickIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            views.setOnClickPendingIntent(boxIds[i], clickPending)
                        } else {
                            views.setTextViewText(dayIds[i], "")
                            views.setTextViewText(countIds[i], "")
                            views.setInt(boxIds[i], "setBackgroundResource",
                                R.drawable.widget_item_unselected_bg)
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
