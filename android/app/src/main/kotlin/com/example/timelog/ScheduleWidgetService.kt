package com.example.timelog

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        // Pass the intent so the factory can read the selected_day_offset
        // directly from it (avoids SharedPreferences race conditions).
        return ScheduleRemoteViewsFactory(this.applicationContext, intent)
    }
}

class ScheduleRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private var tasks = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)

        // Prefer the offset baked into the service intent URI; fall back to prefs.
        val selectedOffset = intent.getIntExtra("selected_day_offset",
            widgetData.getInt("selected_day_offset", 0))

        val tasksJsonStr = widgetData.getString("schedule_tasks_json", null)
        try {
            if (tasksJsonStr != null) {
                val fullMap = JSONObject(tasksJsonStr)
                val offsetKey = selectedOffset.toString()
                tasks = if (fullMap.has(offsetKey)) fullMap.getJSONArray(offsetKey)
                        else JSONArray()
            } else {
                tasks = JSONArray()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            tasks = JSONArray()
        }
    }

    override fun onDestroy() {}

    // +1 for the empty-state row shown only when tasks list is empty
    override fun getCount(): Int = if (tasks.length() == 0) 1 else tasks.length()

    override fun getViewAt(position: Int): RemoteViews {
        // Empty state
        if (tasks.length() == 0) {
            val empty = RemoteViews(context.packageName, R.layout.widget_schedule_empty)
            return empty
        }

        val views = RemoteViews(context.packageName, R.layout.widget_schedule_item)
        try {
            val taskObj = tasks.getJSONObject(position)
            views.setTextViewText(R.id.task_title, taskObj.getString("title"))
            views.setTextViewText(R.id.task_time, taskObj.getString("time"))

            // Fill-in intent carries no extra data; the template PendingIntent
            // (set in the provider) handles the actual navigation.
            val fillIn = Intent()
            views.setOnClickFillInIntent(R.id.schedule_item_root, fillIn)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 2   // normal row + empty-state row
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}
