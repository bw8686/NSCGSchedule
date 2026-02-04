package uk.bw86.nscgschedule.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * Schedules widget updates at specific times based on the timetable.
 * This ensures widgets update when lessons start/end without relying on notifications being enabled.
 */
class WidgetUpdateScheduler {
    
    companion object {
        private const val TAG = "WidgetUpdateScheduler"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val TIMETABLE_KEY = "flutter.timetable"
        private const val EXAM_TIMETABLE_KEY = "flutter.examTimetable"
        
        fun scheduleWidgetUpdates(context: Context) {
            Log.d(TAG, "Scheduling widget updates")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Check if any widgets are active
            if (!hasActiveWidgets(context)) {
                Log.d(TAG, "No active widgets found, canceling all scheduled updates")
                cancelScheduledUpdates(context, alarmManager)
                return
            }
            
            Log.d(TAG, "Active widgets found, scheduling updates")
            
            // Cancel all existing alarms
            cancelScheduledUpdates(context, alarmManager)
            
            // Schedule updates based on timetable
            scheduleLessonUpdates(context, alarmManager)
            
            // Schedule updates based on exam timetable
            scheduleExamUpdates(context, alarmManager)
            
            // Schedule daily midnight update
            scheduleMidnightUpdate(context, alarmManager)
        }
        
        private fun hasActiveWidgets(context: Context): Boolean {
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(context)
            
            // Check all widget types
            val widgetClasses = listOf(
                NextLessonCompactWidget::class.java,
                NextLessonCardWidget::class.java,
                TodayScheduleDetailedWidget::class.java,
                NextExamCompactWidget::class.java,
                NextExamCardWidget::class.java,
                ExamCountdownWidget::class.java,
                ExamDetailsWidget::class.java,
                UnifiedCompactWidget::class.java,
                UnifiedFullWidget::class.java
            )
            
            for (widgetClass in widgetClasses) {
                val componentName = android.content.ComponentName(context, widgetClass)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                if (widgetIds.isNotEmpty()) {
                    Log.d(TAG, "Found ${widgetIds.size} active ${widgetClass.simpleName} widget(s)")
                    return true
                }
            }
            
            return false
        }
        
        private fun cancelScheduledUpdates(context: Context, alarmManager: AlarmManager) {
            // Cancel lesson update alarms (request codes 10000-19999)
            for (i in 10000..10100) {
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = WidgetUpdateReceiver.ACTION_UPDATE_LESSON_WIDGETS
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    i,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            }
            
            // Cancel exam update alarms (request codes 20000-20999)
            for (i in 20000..20100) {
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = WidgetUpdateReceiver.ACTION_UPDATE_EXAM_WIDGETS
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    i,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            }
            
            // Cancel midnight update alarm
            val midnightIntent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                action = WidgetUpdateReceiver.ACTION_UPDATE_WIDGETS
            }
            val midnightPendingIntent = PendingIntent.getBroadcast(
                context,
                30000,
                midnightIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(midnightPendingIntent)
        }
        
        private fun scheduleLessonUpdates(context: Context, alarmManager: AlarmManager) {
            val timetable = getTimetableFromPrefs(context) ?: return
            
            // Check if debug mode is enabled
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val debugEnabled = prefs.getBoolean("flutter.debug_enabled", false)
            val debugTimeMillis = prefs.getLong("flutter.debug_time_millis", 0L)
            val debugSetRealTime = prefs.getLong("flutter.debug_set_real_time", 0L)
            
            val now = if (debugEnabled && debugTimeMillis > 0) {
                // Calculate current debug time based on elapsed real time
                val elapsedRealMillis = System.currentTimeMillis() - debugSetRealTime
                Calendar.getInstance().apply {
                    timeInMillis = debugTimeMillis + elapsedRealMillis
                }
            } else {
                Calendar.getInstance()
            }
            
            var requestCode = 10000
            
            val weekdayMap = mapOf(
                "monday" to Calendar.MONDAY,
                "tuesday" to Calendar.TUESDAY,
                "wednesday" to Calendar.WEDNESDAY,
                "thursday" to Calendar.THURSDAY,
                "friday" to Calendar.FRIDAY,
                "saturday" to Calendar.SATURDAY,
                "sunday" to Calendar.SUNDAY
            )
            
            val days = timetable.optJSONArray("days") ?: return
            
            for (i in 0 until days.length()) {
                val day = days.getJSONObject(i)
                val dayName = day.optString("day", "").lowercase().split(" ").firstOrNull() ?: continue
                val targetWeekday = weekdayMap[dayName] ?: continue
                
                val lessons = day.optJSONArray("lessons") ?: continue
                
                for (j in 0 until lessons.length()) {
                    val lesson = lessons.getJSONObject(j)
                    val startTime = lesson.optString("startTime", "")
                    val endTime = lesson.optString("endTime", "")
                    
                    if (startTime.isNotEmpty()) {
                        scheduleWeeklyAlarm(
                            context,
                            alarmManager,
                            targetWeekday,
                            startTime,
                            requestCode++,
                            WidgetUpdateReceiver.ACTION_UPDATE_LESSON_WIDGETS,
                            debugEnabled,
                            now
                        )
                    }
                    
                    if (endTime.isNotEmpty()) {
                        scheduleWeeklyAlarm(
                            context,
                            alarmManager,
                            targetWeekday,
                            endTime,
                            requestCode++,
                            WidgetUpdateReceiver.ACTION_UPDATE_LESSON_WIDGETS,
                            debugEnabled,
                            now
                        )
                    }
                    
                    if (requestCode >= 11000) {
                        Log.w(TAG, "Too many lesson times, stopping at request code $requestCode")
                        return
                    }
                }
            }
            
            Log.d(TAG, "Scheduled ${requestCode - 10000} lesson widget update alarms")
        }
        
        private fun scheduleExamUpdates(context: Context, alarmManager: AlarmManager) {
            val examTimetable = getExamTimetableFromPrefs(context) ?: return
            
            val now = Calendar.getInstance()
            var requestCode = 20000
            
            val exams = examTimetable.optJSONArray("exams") ?: return
            
            for (i in 0 until exams.length()) {
                val exam = exams.getJSONObject(i)
                val date = exam.optString("date", "")
                val startTime = exam.optString("startTime", "")
                val finishTime = exam.optString("finishTime", "")
                
                if (date.isEmpty() || startTime.isEmpty()) continue
                
                val dateParts = date.split(Regex("[-/]"))
                if (dateParts.size != 3) continue
                
                val day = dateParts[0].toIntOrNull() ?: continue
                val month = dateParts[1].toIntOrNull() ?: continue
                val year = dateParts[2].toIntOrNull() ?: continue
                
                // Schedule update at exam start time
                scheduleOneTimeAlarm(
                    context,
                    alarmManager,
                    year,
                    month,
                    day,
                    startTime,
                    requestCode++,
                    WidgetUpdateReceiver.ACTION_UPDATE_EXAM_WIDGETS
                )
                
                // Schedule update at exam end time
                if (finishTime.isNotEmpty()) {
                    scheduleOneTimeAlarm(
                        context,
                        alarmManager,
                        year,
                        month,
                        day,
                        finishTime,
                        requestCode++,
                        WidgetUpdateReceiver.ACTION_UPDATE_EXAM_WIDGETS
                    )
                }
                
                // Schedule update at midnight on exam day (to show "0 days")
                scheduleMidnightAlarmForDate(
                    context,
                    alarmManager,
                    year,
                    month,
                    day,
                    requestCode++,
                    WidgetUpdateReceiver.ACTION_UPDATE_EXAM_WIDGETS
                )
                
                if (requestCode >= 21000) {
                    Log.w(TAG, "Too many exam times, stopping at request code $requestCode")
                    return
                }
            }
            
            Log.d(TAG, "Scheduled ${requestCode - 20000} exam widget update alarms")
        }
        
        private fun scheduleMidnightUpdate(context: Context, alarmManager: AlarmManager) {
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                action = WidgetUpdateReceiver.ACTION_UPDATE_WIDGETS
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                30000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                midnight.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pendingIntent
            )
            
            Log.d(TAG, "Scheduled daily midnight update")
        }
        
        private fun scheduleWeeklyAlarm(
            context: Context,
            alarmManager: AlarmManager,
            weekday: Int,
            time: String,
            requestCode: Int,
            action: String,
            debugMode: Boolean = false,
            debugNow: Calendar = Calendar.getInstance()
        ) {
            val timeParts = time.split(":")
            if (timeParts.size != 2) return
            
            val hour = timeParts[0].toIntOrNull() ?: return
            val minute = timeParts[1].toIntOrNull() ?: return
            
            if (debugMode) {
                // In debug mode, calculate how long until this lesson time in debug time
                val targetDebugTime = debugNow.clone() as Calendar
                targetDebugTime.set(Calendar.DAY_OF_WEEK, weekday)
                targetDebugTime.set(Calendar.HOUR_OF_DAY, hour)
                targetDebugTime.set(Calendar.MINUTE, minute)
                targetDebugTime.set(Calendar.SECOND, 0)
                targetDebugTime.set(Calendar.MILLISECOND, 0)
                
                // If the time has passed this week in debug time, schedule for next week
                if (targetDebugTime.before(debugNow)) {
                    targetDebugTime.add(Calendar.WEEK_OF_YEAR, 1)
                }
                
                // Calculate milliseconds until this lesson in debug time
                val debugMillisUntil = targetDebugTime.timeInMillis - debugNow.timeInMillis
                
                // Set alarm to fire in real time after the same duration
                val realTriggerTime = System.currentTimeMillis() + debugMillisUntil
                
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    this.action = action
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                // Use inexactRepeating with weekly interval for better battery life
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    realTriggerTime,
                    AlarmManager.INTERVAL_DAY * 7,
                    pendingIntent
                )
                
                Log.d(TAG, "Debug mode: Scheduled alarm for $time on weekday $weekday at real time ${java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date(realTriggerTime))}")
            } else {
                // Normal mode: schedule based on actual calendar time
                val calendar = Calendar.getInstance().apply {
                    set(Calendar.DAY_OF_WEEK, weekday)
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    
                    // If the time has passed this week, schedule for next week
                    if (before(Calendar.getInstance())) {
                        add(Calendar.WEEK_OF_YEAR, 1)
                    }
                }
                
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    this.action = action
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    AlarmManager.INTERVAL_DAY * 7,
                    pendingIntent
                )
            }
        }
        
        private fun scheduleOneTimeAlarm(
            context: Context,
            alarmManager: AlarmManager,
            year: Int,
            month: Int,
            day: Int,
            time: String,
            requestCode: Int,
            action: String
        ) {
            val timeParts = time.split(":")
            if (timeParts.size != 2) return
            
            val hour = timeParts[0].toIntOrNull() ?: return
            val minute = timeParts[1].toIntOrNull() ?: return
            
            val calendar = Calendar.getInstance().apply {
                set(Calendar.YEAR, year)
                set(Calendar.MONTH, month - 1) // Calendar months are 0-based
                set(Calendar.DAY_OF_MONTH, day)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Only schedule if in the future
            if (calendar.before(Calendar.getInstance())) return
            
            val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                this.action = action
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
        
        private fun scheduleMidnightAlarmForDate(
            context: Context,
            alarmManager: AlarmManager,
            year: Int,
            month: Int,
            day: Int,
            requestCode: Int,
            action: String
        ) {
            val calendar = Calendar.getInstance().apply {
                set(Calendar.YEAR, year)
                set(Calendar.MONTH, month - 1)
                set(Calendar.DAY_OF_MONTH, day)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Only schedule if in the future
            if (calendar.before(Calendar.getInstance())) return
            
            val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                this.action = action
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
        
        private fun getTimetableFromPrefs(context: Context): JSONObject? {
            return try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val timetableStr = prefs.getString(TIMETABLE_KEY, null) ?: return null
                JSONObject(timetableStr)
            } catch (e: Exception) {
                Log.e(TAG, "Error reading timetable from preferences", e)
                null
            }
        }
        
        private fun getExamTimetableFromPrefs(context: Context): JSONObject? {
            return try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val examTimetableStr = prefs.getString(EXAM_TIMETABLE_KEY, null) ?: return null
                JSONObject(examTimetableStr)
            } catch (e: Exception) {
                Log.e(TAG, "Error reading exam timetable from preferences", e)
                null
            }
        }
    }
}
