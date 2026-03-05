package com.example.timelog

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetProvider : HomeWidgetProvider() {
    companion object {
        const val ACTION_TILE_CLICKED = "com.example.timelog.ACTION_TILE_CLICKED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TILE_CLICKED) {
            val offset = intent.getIntExtra("tile_offset", 0)
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetData.edit().putInt("selected_day_offset", offset).apply()
            
            // Trigger update
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, ScheduleWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Notify data changed for the list
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.schedule_list)
            
            // Update the UI (highlights etc)
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

            // Setup ListView adapter
            val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("selected_day_offset", selectedOffset)
                // Important: data must be unique for fresh factory instantiation
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME) + "?offset=$selectedOffset")
            }
            views.setRemoteAdapter(R.id.schedule_list, serviceIntent)

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("wdmtg://schedule")
            }
            val appPendingIntent = PendingIntent.getActivity(context, 0, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setPendingIntentTemplate(R.id.schedule_list, appPendingIntent)

            // Read tile data
            val tilesJsonStr = widgetData.getString("schedule_tiles_json", null)
            if (tilesJsonStr != null) {
                try {
                    val tilesArray = JSONArray(tilesJsonStr)
                    val boxIds = intArrayOf(R.id.tile_0_box, R.id.tile_1_box, R.id.tile_2_box, R.id.tile_3_box)
                    val dayIds = intArrayOf(R.id.tile_0_day, R.id.tile_1_day, R.id.tile_2_day, R.id.tile_3_day)
                    val countIds = intArrayOf(R.id.tile_0_count, R.id.tile_1_count, R.id.tile_2_count, R.id.tile_3_count)

                    for (i in 0 until 4) {
                        val boxId = boxIds[i]
                        val dayId = dayIds[i]
                        val countId = countIds[i]

                        if (i < tilesArray.length()) {
                            val t = tilesArray.getJSONObject(i)
                            views.setTextViewText(dayId, t.getString("label"))
                            views.setTextViewText(countId, "${t.getInt("count")}")
                            
                            // Highlight selected tile
                            if (i == selectedOffset) {
                                views.setInt(boxId, "setBackgroundResource", R.drawable.widget_item_selected_bg)
                                views.setTextColor(dayId, android.graphics.Color.WHITE)
                                views.setTextColor(countId, android.graphics.Color.LTGRAY)
                            } else {
                                views.setInt(boxId, "setBackgroundResource", 0)
                                views.setTextColor(dayId, android.graphics.Color.parseColor("#A0A0A0"))
                                views.setTextColor(countId, android.graphics.Color.parseColor("#808080"))
                            }

                            // Broadcast Click Intent
                            val clickIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
                                action = ACTION_TILE_CLICKED
                                putExtra("tile_offset", i)
                            }
                            val clickPendingIntent = PendingIntent.getBroadcast(
                                context, i, clickIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            views.setOnClickPendingIntent(boxId, clickPendingIntent)
                        } else {
                            views.setTextViewText(dayId, "")
                            views.setTextViewText(countId, "")
                            views.setInt(boxId, "setBackgroundResource", 0)
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
