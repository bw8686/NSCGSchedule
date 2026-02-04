package uk.bw86.nscgschedule.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import uk.bw86.nscgschedule.R
import uk.bw86.nscgschedule.MainActivity

/**
 * STYLE 10: Unified Compact Widget (2x2)
 * Shows next lesson AND next exam in a compact format
 */
class UnifiedCompactWidget : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_unified_compact)
            
            // Lesson section
            val nextLesson = WidgetDataHelper.getNextLesson(context)
            val currentLesson = WidgetDataHelper.getCurrentLesson(context)
            val lessonToShow = currentLesson ?: nextLesson
            
            if (lessonToShow != null) {
                views.setTextViewText(R.id.lesson_name, lessonToShow.name)
                val room = if (lessonToShow.room.isNotEmpty()) lessonToShow.room else "TBA"
                views.setTextViewText(R.id.lesson_time, "${lessonToShow.startTime} • ${room}")
            } else {
                // Determine specific empty state for lessons
                when {
                    !WidgetDataHelper.hasTimetable(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No timetable")
                        views.setTextViewText(R.id.lesson_time, "⚙️ Setup")
                    }
                    !WidgetDataHelper.hasLessonsToday(context) -> {
                        views.setTextViewText(R.id.lesson_name, "No lessons today")
                        views.setTextViewText(R.id.lesson_time, "🎉 Free day")
                    }
                    else -> {
                        views.setTextViewText(R.id.lesson_name, "All done")
                        views.setTextViewText(R.id.lesson_time, "✓ Complete")
                    }
                }
            }
            
            // Exam section
            val nextExam = WidgetDataHelper.getNextExam(context)
            
            if (nextExam != null) {
                views.setTextViewText(R.id.exam_subject, nextExam.subjectDescription)
                val daysUntil = WidgetDataHelper.getDaysUntilExam(context, nextExam)
                val dateText = when {
                    daysUntil == 0 -> "TODAY"
                    daysUntil == 1 -> "Tomorrow"
                    else -> "${daysUntil}d"
                }
                views.setTextViewText(R.id.exam_date, dateText)
            } else {
                // Determine specific empty state for exams
                when {
                    !WidgetDataHelper.hasExams(context) -> {
                        views.setTextViewText(R.id.exam_subject, "No exams")
                        views.setTextViewText(R.id.exam_date, "⚙️ Setup")
                    }
                    else -> {
                        views.setTextViewText(R.id.exam_subject, "All done")
                        views.setTextViewText(R.id.exam_date, "✓")
                    }
                }
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 12: Unified Full Widget (4x3)
 * Complete overview with multiple lessons and exams
 */
class UnifiedFullWidget : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_unified_full)
            
            // Get widget cell dimensions
            val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            val cellWidth = WidgetDataHelper.getWidgetCellWidth(minWidth)
            
            // Show 2-3 lessons max based on width (min 2, max 3)
            val maxLessons = when {
                cellWidth <= 2 -> 2
                else -> 3
            }
            
            // Lessons section
            val lessons = WidgetDataHelper.getUpcomingLessonsToday(context, maxLessons)
            
            val lessonSlots = listOf(
                Triple(R.id.lesson1_container, R.id.lesson1_name, R.id.lesson1_info),
                Triple(R.id.lesson2_container, R.id.lesson2_name, R.id.lesson2_info),
                Triple(R.id.lesson3_container, R.id.lesson3_name, R.id.lesson3_info)
            )
            
            lessonSlots.forEachIndexed { index, (containerId, nameId, infoId) ->
                if (index < lessons.size) {
                    val lesson = lessons[index]
                    views.setViewVisibility(containerId, android.view.View.VISIBLE)
                    views.setTextViewText(nameId, lesson.name)
                    views.setTextViewText(infoId, "${lesson.startTime} • ${if (lesson.room.isNotEmpty()) lesson.room else "TBA"}")
                } else {
                    views.setViewVisibility(containerId, android.view.View.GONE)
                }
            }
            
            if (lessons.isEmpty()) {
                views.setViewVisibility(R.id.lessons_empty, android.view.View.VISIBLE)
                val emptyText = when {
                    !WidgetDataHelper.hasTimetable(context) -> "⚙️ No timetable"
                    !WidgetDataHelper.hasLessonsToday(context) -> if (WidgetDataHelper.isWeekend(context)) "🎉 Weekend!" else "🎉 No lessons today"
                    else -> "✓ All done for today"
                }
                views.setTextViewText(R.id.lessons_empty, emptyText)
            } else {
                views.setViewVisibility(R.id.lessons_empty, android.view.View.GONE)
            }
            
            // Exams section (show 3)
            val exams = WidgetDataHelper.getUpcomingExams(context, 3)
            
            val examSlots = listOf(
                Triple(R.id.exam1_container, R.id.exam1_subject, R.id.exam1_info),
                Triple(R.id.exam2_container, R.id.exam2_subject, R.id.exam2_info),
                Triple(R.id.exam3_container, R.id.exam3_subject, R.id.exam3_info)
            )
            
            examSlots.forEachIndexed { index, (containerId, subjectId, infoId) ->
                if (index < exams.size) {
                    val exam = exams[index]
                    views.setViewVisibility(containerId, android.view.View.VISIBLE)
                    views.setTextViewText(subjectId, exam.subjectDescription)
                    val daysUntil = WidgetDataHelper.getDaysUntilExam(context, exam)
                    val daysText = when {
                        daysUntil == 0 -> "TODAY"
                        daysUntil == 1 -> "Tomorrow"
                        daysUntil < 7 -> "${daysUntil} days"
                        else -> WidgetDataHelper.formatExamDateShort(exam.date)
                    }
                    views.setTextViewText(infoId, "$daysText • ${exam.startTime}")
                } else {
                    views.setViewVisibility(containerId, android.view.View.GONE)
                }
            }
            
            if (exams.isEmpty()) {
                views.setViewVisibility(R.id.exams_empty, android.view.View.VISIBLE)
                val emptyText = when {
                    !WidgetDataHelper.hasExams(context) -> "⚙️ No exams set up"
                    else -> "✓ No upcoming exams"
                }
                views.setTextViewText(R.id.exams_empty, emptyText)
            } else {
                views.setViewVisibility(R.id.exams_empty, android.view.View.GONE)
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

