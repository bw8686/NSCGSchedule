package uk.bw86.nscgschedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import uk.bw86.nscgschedule.widgets.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "uk.bw86.nscgschedule/widgets"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAllWidgets" -> {
                    updateAllWidgets()
                    result.success(true)
                }
                "updateLessonWidgets" -> {
                    updateLessonWidgets()
                    result.success(true)
                }
                "updateExamWidgets" -> {
                    updateExamWidgets()
                    result.success(true)
                }
                "updateUnifiedWidgets" -> {
                    updateUnifiedWidgets()
                    result.success(true)
                }
                "scheduleWidgetUpdates" -> {
                    WidgetUpdateScheduler.scheduleWidgetUpdates(applicationContext)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun updateAllWidgets() {
        updateLessonWidgets()
        updateExamWidgets()
        updateUnifiedWidgets()
    }
    
    private fun updateLessonWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        
        // Update all lesson widget types
        updateWidgetProvider(appWidgetManager, NextLessonCompactWidget::class.java)
        updateWidgetProvider(appWidgetManager, NextLessonCardWidget::class.java)
        updateWidgetProvider(appWidgetManager, TodayScheduleDetailedWidget::class.java)
    }
    
    private fun updateExamWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        
        // Update all exam widget types
        updateWidgetProvider(appWidgetManager, NextExamCompactWidget::class.java)
        updateWidgetProvider(appWidgetManager, NextExamCardWidget::class.java)
        updateWidgetProvider(appWidgetManager, ExamCountdownWidget::class.java)
        updateWidgetProvider(appWidgetManager, ExamDetailsWidget::class.java)
    }
    
    private fun updateUnifiedWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        
        // Update all unified widget types
        updateWidgetProvider(appWidgetManager, UnifiedCompactWidget::class.java)
        updateWidgetProvider(appWidgetManager, UnifiedFullWidget::class.java)
    }
    
    private fun <T> updateWidgetProvider(appWidgetManager: AppWidgetManager, providerClass: Class<T>) {
        val componentName = ComponentName(applicationContext, providerClass)
        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                
        if (widgetIds.isNotEmpty()) {
            // Send broadcast to trigger widget update
            val intent = Intent(applicationContext, providerClass)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            sendBroadcast(intent)
            
            // Also directly notify AppWidgetManager
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetIds, android.R.id.list)
        }
    }
}
