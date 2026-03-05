package com.example.timelog

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodoRemoteViewsFactory(this.applicationContext)
    }
}

class TodoRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var todos = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val todosJsonStr = widgetData.getString("todos_data", null)
        try {
            if (todosJsonStr != null) {
                todos = JSONArray(todosJsonStr)
            } else {
                todos = JSONArray()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            todos = JSONArray()
        }
    }

    override fun onDestroy() {}
    override fun getCount(): Int = todos.length()
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_todo_item)
        try {
            val todoObj = todos.getJSONObject(position)
            views.setTextViewText(R.id.todo_item_text, todoObj.getString("text"))
            val isDone = todoObj.getBoolean("isDone")
            if (isDone) {
                views.setImageViewResource(R.id.todo_icon, android.R.drawable.checkbox_on_background)
            } else {
                views.setImageViewResource(R.id.todo_icon, android.R.drawable.checkbox_off_background)
            }
            
            val fillInIntent = Intent()
            views.setOnClickFillInIntent(R.id.todo_item_root, fillInIntent)
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
