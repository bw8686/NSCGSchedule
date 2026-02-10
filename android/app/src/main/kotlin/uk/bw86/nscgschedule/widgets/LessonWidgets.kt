package uk.bw86.nscgschedule.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import uk.bw86.nscgschedule.R
import uk.bw86.nscgschedule.MainActivity
import java.util.Calendar

/**
 * STYLE 1: Compact Next Lesson Widget (2x1)
 * Minimal card showing just the next upcoming lesson
 */
class NextLessonCompactWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // First widget of this type added, schedule updates
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Last widget of this type removed, check if any widgets remain
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_lesson_compact)
            
            val currentItem = WidgetDataHelper.getCurrentScheduleItem(context)
            val nextItem = WidgetDataHelper.getNextScheduleItem(context)
            
            val itemToShow = currentItem ?: nextItem
            
            if (itemToShow != null) {
                when (itemToShow) {
                    is WidgetDataHelper.ScheduleItem.Lesson -> {
                        val lesson = itemToShow.data
                        views.setTextViewText(R.id.lesson_name, lesson.name)
                        views.setTextViewText(R.id.lesson_time, "${lesson.startTime} - ${lesson.endTime}")
                        views.setTextViewText(R.id.lesson_room, if (lesson.room.isNotEmpty()) lesson.room else "TBA")
                        
                        // Show start time or "NOW"
                        val statusText = if (currentItem != null) "NOW" else lesson.startTime
                        views.setTextViewText(R.id.lesson_status, statusText)
                    }
                    is WidgetDataHelper.ScheduleItem.Exam -> {
                        val exam = itemToShow.data
                        views.setTextViewText(R.id.lesson_name, "📝 ${exam.subjectDescription}")
                        views.setTextViewText(R.id.lesson_time, "${exam.startTime} - ${exam.finishTime}")
                        val roomText = if (exam.examRoom.isNotEmpty()) {
                            WidgetDataHelper.formatExamRoom(exam.examRoom, exam.preRoom)
                        } else {
                            "TBA"
                        }
                        views.setTextViewText(R.id.lesson_room, roomText)
                        
                        // Show start time or "NOW"
                        val statusText = if (currentItem != null) "NOW" else exam.startTime
                        views.setTextViewText(R.id.lesson_status, statusText)
                    }
                }
            } else {
                // Determine specific empty state
                when {
                    !WidgetDataHelper.hasTimetable(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No timetable")
                        views.setTextViewText(R.id.lesson_time, "Set up your schedule")
                        views.setTextViewText(R.id.lesson_room, "—")
                        views.setTextViewText(R.id.lesson_status, "⚙️")
                    }
                    !WidgetDataHelper.hasLessonsToday(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No lessons today")
                        views.setTextViewText(R.id.lesson_time, if (WidgetDataHelper.isWeekend(context)) "Weekend" else "Free day")
                        views.setTextViewText(R.id.lesson_room, "—")
                        views.setTextViewText(R.id.lesson_status, "🎉")
                    }
                    else -> {
                        views.setTextViewText(R.id.lesson_name, "All done for today")
                        views.setTextViewText(R.id.lesson_time, "No more lessons")
                        views.setTextViewText(R.id.lesson_room, "—")
                        views.setTextViewText(R.id.lesson_status, "✓")
                    }
                }
            }
            
            // Open app on click
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 2: Next Lesson Card Widget (2x2)
 * Larger card with more details about the next lesson
 */
class NextLessonCardWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_next_lesson_card)
            
            val currentItem = WidgetDataHelper.getCurrentScheduleItem(context)
            val nextItem = WidgetDataHelper.getNextScheduleItem(context)
            
            val itemToShow = currentItem ?: nextItem
            
            if (itemToShow != null) {
                when (itemToShow) {
                    is WidgetDataHelper.ScheduleItem.Lesson -> {
                        val lesson = itemToShow.data
                        views.setTextViewText(R.id.lesson_name, lesson.name)
                        views.setTextViewText(R.id.lesson_course, lesson.course)
                        views.setTextViewText(R.id.lesson_time, "${lesson.startTime} - ${lesson.endTime}")
                        views.setTextViewText(R.id.lesson_room, if (lesson.room.isNotEmpty()) "Room: ${lesson.room}" else "Room: TBA")
                        views.setTextViewText(R.id.lesson_teacher, lesson.teachers.firstOrNull() ?: "")
                        
                        val status = if (currentItem != null) "Now" else "Up Next"
                        views.setTextViewText(R.id.lesson_status, status)
                        
                        // Show start time
                        views.setTextViewText(R.id.time_until, lesson.startTime)
                    }
                    is WidgetDataHelper.ScheduleItem.Exam -> {
                        val exam = itemToShow.data
                        views.setTextViewText(R.id.lesson_name, "📝 ${exam.subjectDescription}")
                        views.setTextViewText(R.id.lesson_course, "Exam")
                        views.setTextViewText(R.id.lesson_time, "${exam.startTime} - ${exam.finishTime}")
                        val roomText = if (exam.examRoom.isNotEmpty()) {
                            WidgetDataHelper.formatExamRoom(exam.examRoom, exam.preRoom, exam.seatNumber)
                        } else {
                            "Room: TBA"
                        }
                        views.setTextViewText(R.id.lesson_room, roomText)
                        views.setTextViewText(R.id.lesson_teacher, "")
                        
                        val status = if (currentItem != null) "Now" else "Up Next"
                        views.setTextViewText(R.id.lesson_status, status)
                        
                        // Show start time
                        views.setTextViewText(R.id.time_until, exam.startTime)
                    }
                }
            } else {
                // Determine specific empty state
                when {
                    !WidgetDataHelper.hasTimetable(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No timetable set up")
                        views.setTextViewText(R.id.lesson_course, "Get started")
                        views.setTextViewText(R.id.lesson_time, "")
                        views.setTextViewText(R.id.lesson_room, "Tap to set up your schedule")
                        views.setTextViewText(R.id.lesson_teacher, "")
                        views.setTextViewText(R.id.lesson_status, "Setup")
                        views.setTextViewText(R.id.time_until, "⚙️")
                    }
                    !WidgetDataHelper.hasLessonsToday(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No lessons today")
                        views.setTextViewText(R.id.lesson_course, if (WidgetDataHelper.isWeekend(context)) "Weekend" else "Free day")
                        views.setTextViewText(R.id.lesson_time, "")
                        views.setTextViewText(R.id.lesson_room, "Enjoy your free time!")
                        views.setTextViewText(R.id.lesson_teacher, "")
                        views.setTextViewText(R.id.lesson_status, "Free Day")
                        views.setTextViewText(R.id.time_until, "🎉")
                    }
                    else -> {
                        views.setTextViewText(R.id.lesson_name, "All done for today")
                        views.setTextViewText(R.id.lesson_course, "Completed")
                        views.setTextViewText(R.id.lesson_time, "")
                        views.setTextViewText(R.id.lesson_room, "No more lessons remaining")
                        views.setTextViewText(R.id.lesson_teacher, "")
                        views.setTextViewText(R.id.lesson_status, "All Done")
                        views.setTextViewText(R.id.time_until, "✓")
                    }
                }
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 4: Today's Schedule Detailed Widget (4x3)
 * Shows lessons with more details including room and teacher
 * Dynamically adjusts item count based on widget size
 */
class TodayScheduleDetailedWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateWidget(context, appWidgetManager, appWidgetId, options)
        }
    }
    
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        updateWidget(context, appWidgetManager, appWidgetId, newOptions)
    }
    
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUpdateScheduler.scheduleWidgetUpdates(context)
    }
    
    companion object {
        private fun createLessonIntent(context: Context, dayName: String, lessonIndex: Int, requestCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("nscgschedule://timetable?day=$dayName&lesson=$lessonIndex")
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, options: Bundle? = null) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_schedule_detailed)
            
            // Get widget cell dimensions (only care about height for this widget)
            val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
            val cellHeight = WidgetDataHelper.getWidgetCellHeight(minHeight)
            
            // Determine max items based only on height
            val maxItems = when (cellHeight) {
                1 -> 3       // 1 row: 3 items
                2 -> 5       // 2 rows: 5 items
                else -> 8    // 3+ rows: 8 items
            }
            
            android.util.Log.d("LessonWidget", "Widget height: ${minHeight}dp = ${cellHeight} rows, showing max $maxItems lessons")
            
            val scheduleItems = WidgetDataHelper.getUpcomingMergedScheduleToday(context, maxItems)
            val dayName = WidgetDataHelper.getCurrentDayNamePublic(context)
            
            views.setTextViewText(R.id.widget_title, "Today's Schedule")
            views.setTextViewText(R.id.lesson_count, WidgetDataHelper.getUpcomingMergedScheduleToday(context, 10).size.toString())
            
            val lessonSlots = listOf(
                listOf(R.id.lesson1_container, R.id.lesson1_name, R.id.lesson1_time, R.id.lesson1_room, R.id.lesson1_teacher),
                listOf(R.id.lesson2_container, R.id.lesson2_name, R.id.lesson2_time, R.id.lesson2_room, R.id.lesson2_teacher),
                listOf(R.id.lesson3_container, R.id.lesson3_name, R.id.lesson3_time, R.id.lesson3_room, R.id.lesson3_teacher),
                listOf(R.id.lesson4_container, R.id.lesson4_name, R.id.lesson4_time, R.id.lesson4_room, R.id.lesson4_teacher),
                listOf(R.id.lesson5_container, R.id.lesson5_name, R.id.lesson5_time, R.id.lesson5_room, R.id.lesson5_teacher),
                listOf(R.id.lesson6_container, R.id.lesson6_name, R.id.lesson6_time, R.id.lesson6_room, R.id.lesson6_teacher),
                listOf(R.id.lesson7_container, R.id.lesson7_name, R.id.lesson7_time, R.id.lesson7_room, R.id.lesson7_teacher),
                listOf(R.id.lesson8_container, R.id.lesson8_name, R.id.lesson8_time, R.id.lesson8_room, R.id.lesson8_teacher)
            )
            
            // Get all today's lessons to find the actual index in the full list (for deep linking)
            val allLessons = WidgetDataHelper.getTodayLessons(context)
            
            lessonSlots.forEachIndexed { index, ids ->
                if (index < scheduleItems.size) {
                    val item = scheduleItems[index]
                    
                    when (item) {
                        is WidgetDataHelper.ScheduleItem.Lesson -> {
                            val lesson = item.data
                            // Find the actual index in the full day's lessons
                            val actualIndex = allLessons.indexOf(lesson)
                            
                            views.setViewVisibility(ids[0], android.view.View.VISIBLE)
                            views.setTextViewText(ids[1], lesson.name)
                            views.setTextViewText(ids[2], lesson.startTime)
                            views.setTextViewText(ids[3], if (lesson.room.isNotEmpty()) lesson.room else "TBA")
                            views.setTextViewText(ids[4], lesson.teachers.firstOrNull() ?: "")
                            
                            // Set click handler for this lesson card
                            val pendingIntent = createLessonIntent(context, dayName, actualIndex, appWidgetId * 100 + index)
                            views.setOnClickPendingIntent(ids[0], pendingIntent)
                        }
                        is WidgetDataHelper.ScheduleItem.Exam -> {
                            val exam = item.data
                            
                            views.setViewVisibility(ids[0], android.view.View.VISIBLE)
                            views.setTextViewText(ids[1], "📝 ${exam.subjectDescription}")
                            views.setTextViewText(ids[2], exam.startTime)
                            
                            // Room field: show arrow format if preroom is valid
                            val roomText = if (exam.examRoom.isNotEmpty()) {
                                val hasValidPreRoom = exam.preRoom.isNotBlank() && exam.preRoom.split(" ").size < 6
                                if (hasValidPreRoom) {
                                    "Pre: ${exam.preRoom} → ${WidgetDataHelper.extractRoomCode(exam.examRoom)}"
                                } else {
                                    WidgetDataHelper.extractRoomCode(exam.examRoom)
                                }
                            } else {
                                "TBA"
                            }
                            views.setTextViewText(ids[3], roomText)
                            
                            // Detail field: always show seat if available
                            val detailText = if (exam.seatNumber.isNotEmpty()) {
                                "Seat ${exam.seatNumber}"
                            } else {
                                ""
                            }
                            views.setTextViewText(ids[4], detailText)
                            
                            // Open main app on exam card click
                            val intent = Intent(context, uk.bw86.nscgschedule.MainActivity::class.java)
                            val pendingIntent = PendingIntent.getActivity(context, appWidgetId * 100 + index, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            views.setOnClickPendingIntent(ids[0], pendingIntent)
                        }
                    }
                } else {
                    views.setViewVisibility(ids[0], android.view.View.GONE)
                }
            }
            
            if (scheduleItems.isEmpty()) {
                views.setViewVisibility(R.id.empty_message, android.view.View.VISIBLE)
                val hasTimetable = WidgetDataHelper.hasTimetable(context)
                val hasLessonsToday = WidgetDataHelper.hasLessonsToday(context)
                android.util.Log.d("TodayScheduleDetailedWidget", "Empty state: hasTimetable=$hasTimetable, hasLessonsToday=$hasLessonsToday")
                val emptyMessage = when {
                    !hasTimetable -> "⚙️ No timetable set up\nTap to get started"
                    !hasLessonsToday -> if (WidgetDataHelper.isWeekend(context)) "🎉 Weekend! No lessons" else "🎉 No lessons today\nFree day!"
                    else -> "✓ All done for today\nNo more lessons remaining"
                }
                views.setTextViewText(R.id.empty_message, emptyMessage)
            } else {
                views.setViewVisibility(R.id.empty_message, android.view.View.GONE)
            }
            
            // Main widget click goes to timetable
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("nscgschedule://timetable")
                setPackage(context.packageName)
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
