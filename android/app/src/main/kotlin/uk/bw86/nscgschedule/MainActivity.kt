package uk.bw86.nscgschedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import com.google.android.gms.wearable.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import uk.bw86.nscgschedule.widgets.*

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "uk.bw86.nscgschedule/widgets"
    private val WATCH_CHANNEL = "uk.bw86.nscgschedule/watch"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var dataClient: DataClient
    private lateinit var nodeClient: NodeClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dataClient = Wearable.getDataClient(this)
        nodeClient = Wearable.getNodeClient(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget MethodChannel (existing behavior)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
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
                else -> result.notImplemented()
            }
        }

        // Watch MethodChannel (send JSON to connected Wear devices)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isConnected" -> {
                    scope.launch {
                        try {
                            val nodes = nodeClient.connectedNodes.await()
                            result.success(nodes.isNotEmpty())
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "sendData" -> {
                    scope.launch {
                        try {
                            val path = call.argument<String>("path") ?: "/watch_data"
                            val jsonData = call.argument<String>("data") ?: ""

                            val request = PutDataMapRequest.create(path).apply {
                                dataMap.putString("json", jsonData)
                                dataMap.putLong("timestamp", System.currentTimeMillis())
                            }.asPutDataRequest().setUrgent()

                            dataClient.putDataItem(request).await()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
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
