package uk.bw86.nscgschedule.widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver that handles scheduled widget updates.
 * This receiver is triggered by AlarmManager to update widgets at specific times.
 */
class WidgetUpdateReceiver : BroadcastReceiver() {
    
    companion object {
        const val ACTION_UPDATE_WIDGETS = "uk.bw86.nscgschedule.UPDATE_WIDGETS"
        const val ACTION_UPDATE_LESSON_WIDGETS = "uk.bw86.nscgschedule.UPDATE_LESSON_WIDGETS"
        const val ACTION_UPDATE_EXAM_WIDGETS = "uk.bw86.nscgschedule.UPDATE_EXAM_WIDGETS"
        private const val TAG = "WidgetUpdateReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")
        
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        when (intent.action) {
            ACTION_UPDATE_WIDGETS -> {
                updateAllWidgets(context, appWidgetManager)
                // Reschedule for next day's midnight
                WidgetUpdateScheduler.scheduleWidgetUpdates(context)
            }
            ACTION_UPDATE_LESSON_WIDGETS -> {
                updateLessonWidgets(context, appWidgetManager)
                // Reschedule lesson updates (they're one-time alarms now)
                WidgetUpdateScheduler.scheduleWidgetUpdates(context)
            }
            ACTION_UPDATE_EXAM_WIDGETS -> {
                updateExamWidgets(context, appWidgetManager)
                // Reschedule exam updates (they're one-time alarms now)
                WidgetUpdateScheduler.scheduleWidgetUpdates(context)
            }
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED -> {
                // System time changed, update all widgets and reschedule
                updateAllWidgets(context, appWidgetManager)
                WidgetUpdateScheduler.scheduleWidgetUpdates(context)
            }
        }
    }
    
    private fun updateAllWidgets(context: Context, appWidgetManager: AppWidgetManager) {
        updateLessonWidgets(context, appWidgetManager)
        updateExamWidgets(context, appWidgetManager)
        updateUnifiedWidgets(context, appWidgetManager)
    }
    
    private fun updateLessonWidgets(context: Context, appWidgetManager: AppWidgetManager) {
        updateWidget(context, appWidgetManager, NextLessonCompactWidget::class.java)
        updateWidget(context, appWidgetManager, NextLessonCardWidget::class.java)
        updateWidget(context, appWidgetManager, TodayScheduleDetailedWidget::class.java)
    }
    
    private fun updateExamWidgets(context: Context, appWidgetManager: AppWidgetManager) {
        updateWidget(context, appWidgetManager, NextExamCompactWidget::class.java)
        updateWidget(context, appWidgetManager, NextExamCardWidget::class.java)
        updateWidget(context, appWidgetManager, ExamCountdownWidget::class.java)
        updateWidget(context, appWidgetManager, ExamDetailsWidget::class.java)
    }
    
    private fun updateUnifiedWidgets(context: Context, appWidgetManager: AppWidgetManager) {
        updateWidget(context, appWidgetManager, UnifiedCompactWidget::class.java)
        updateWidget(context, appWidgetManager, UnifiedFullWidget::class.java)
    }
    
    private fun <T> updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetClass: Class<T>) {
        val componentName = ComponentName(context, widgetClass)
        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
        
        if (widgetIds.isNotEmpty()) {
            Log.d(TAG, "Updating ${widgetIds.size} ${widgetClass.simpleName} widgets")
            val intent = Intent(context, widgetClass)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            context.sendBroadcast(intent)
        }
    }
}
