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
        return ScheduleRemoteViewsFactory(this.applicationContext)
    }
}

class ScheduleRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val selectedOffset = widgetData.getInt("selected_day_offset", 0)
        val tasksJsonStr = widgetData.getString("schedule_tasks_json", null)
        try {
            if (tasksJsonStr != null) {
                val fullMap = JSONObject(tasksJsonStr)
                val offsetKey = selectedOffset.toString()
                if (fullMap.has(offsetKey)) {
                    tasks = fullMap.getJSONArray(offsetKey)
                } else {
                    tasks = JSONArray()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            tasks = JSONArray()
        }
    }

    override fun onDestroy() {}
    override fun getCount(): Int = tasks.length()
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_item)
        try {
            val taskObj = tasks.getJSONObject(position)
            views.setTextViewText(R.id.task_title, taskObj.getString("title"))
            views.setTextViewText(R.id.task_time, taskObj.getString("time"))
            
            // Allow clicking item to open app
            val fillInIntent = Intent()
            views.setOnClickFillInIntent(R.id.schedule_item_root, fillInIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
