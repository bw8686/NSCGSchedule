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

/**
 * STYLE 5: Next Exam Compact Widget (2x1)
 * Minimal card showing just the next upcoming exam
 */
class NextExamCompactWidget : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_next_exam_compact)
            
            val nextExam = WidgetDataHelper.getNextExam(context)
            
            if (nextExam != null) {
                views.setTextViewText(R.id.exam_subject, nextExam.subjectDescription)
                views.setTextViewText(R.id.exam_date, WidgetDataHelper.formatExamDateShort(nextExam.date))
                views.setTextViewText(R.id.exam_time, nextExam.startTime)
                
                val daysUntil = WidgetDataHelper.getDaysUntilExam(context, nextExam)
                val displayText = if (daysUntil > 0) {
                    "${daysUntil}d"
                } else {
                    nextExam.startTime
                }
                
                views.setTextViewText(R.id.days_until, displayText)
            } else {
                // Determine specific empty state
                when {
                    !WidgetDataHelper.hasExams(context) -> {
                        views.setTextViewText(R.id.exam_subject, "No exams set up")
                        views.setTextViewText(R.id.exam_date, "Tap to add exams")
                        views.setTextViewText(R.id.exam_time, "")
                        views.setTextViewText(R.id.days_until, "⚙️")
                    }
                    else -> {
                        views.setTextViewText(R.id.exam_subject, "No upcoming exams")
                        views.setTextViewText(R.id.exam_date, "All done!")
                        views.setTextViewText(R.id.exam_time, "")
                        views.setTextViewText(R.id.days_until, "✓")
                    }
                }
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 6: Next Exam Card Widget (2x2)
 * Larger card with more exam details
 */
class NextExamCardWidget : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_next_exam_card)
            
            val nextExam = WidgetDataHelper.getNextExam(context)
            
            if (nextExam != null) {
                views.setTextViewText(R.id.exam_subject, nextExam.subjectDescription)
                views.setTextViewText(R.id.exam_paper, nextExam.paper)
                views.setTextViewText(R.id.exam_date, WidgetDataHelper.formatExamDate(nextExam.date))
                views.setTextViewText(R.id.exam_time, "${nextExam.startTime} - ${nextExam.finishTime}")
                val roomText = if (nextExam.preRoom.isNotEmpty()) {
                    "Pre: ${nextExam.preRoom} → ${nextExam.examRoom}"
                } else {
                    "Room: ${nextExam.examRoom}"
                }
                views.setTextViewText(R.id.exam_room, roomText)
                views.setTextViewText(R.id.exam_seat, if (nextExam.seatNumber.isNotEmpty()) "Seat: ${nextExam.seatNumber}" else "")
                
                val daysUntil = WidgetDataHelper.getDaysUntilExam(context, nextExam)
                val displayText = if (daysUntil > 0) {
                    "in ${daysUntil}d"
                } else {
                    nextExam.startTime
                }
                
                views.setTextViewText(R.id.days_until, displayText)
            } else {
                // Determine specific empty state
                when {
                    !WidgetDataHelper.hasExams(context) -> {
                        views.setTextViewText(R.id.exam_subject, "No exams set up")
                        views.setTextViewText(R.id.exam_paper, "Get started")
                        views.setTextViewText(R.id.exam_date, "")
                        views.setTextViewText(R.id.exam_time, "")
                        views.setTextViewText(R.id.exam_room, "Tap to add your exams")
                        views.setTextViewText(R.id.exam_seat, "")
                        views.setTextViewText(R.id.days_until, "⚙️")
                    }
                    else -> {
                        views.setTextViewText(R.id.exam_subject, "No upcoming exams")
                        views.setTextViewText(R.id.exam_paper, "Completed")
                        views.setTextViewText(R.id.exam_date, "")
                        views.setTextViewText(R.id.exam_time, "")
                        views.setTextViewText(R.id.exam_room, "All done!")
                        views.setTextViewText(R.id.exam_seat, "")
                        views.setTextViewText(R.id.days_until, "✓")
                    }
                }
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 8: Exam Countdown Widget (2x2)
 * Focused countdown display for next exam
 */
class ExamCountdownWidget : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_exam_countdown)
            
            val nextExam = WidgetDataHelper.getNextExam(context)
            
            if (nextExam != null) {
                views.setTextViewText(R.id.exam_subject, nextExam.subjectDescription)
                
                val daysUntil = WidgetDataHelper.getDaysUntilExam(context, nextExam)
                
                views.setTextViewText(R.id.days_number, daysUntil.toString())
                views.setTextViewText(R.id.days_label, if (daysUntil == 1) "day" else "days")
                views.setTextViewText(R.id.exam_date, WidgetDataHelper.formatExamDate(nextExam.date))
                views.setTextViewText(R.id.exam_time, "${nextExam.startTime} - ${nextExam.finishTime}")
            } else {
                // Determine specific empty state
                when {
                    !WidgetDataHelper.hasExams(context) -> {
                        views.setTextViewText(R.id.exam_subject, "No exams set up")
                        views.setTextViewText(R.id.days_number, "⚙️")
                        views.setTextViewText(R.id.days_label, "")
                        views.setTextViewText(R.id.exam_date, "Tap to add exams")
                        views.setTextViewText(R.id.exam_time, "")
                    }
                    else -> {
                        views.setTextViewText(R.id.exam_subject, "No upcoming exams")
                        views.setTextViewText(R.id.days_number, "✓")
                        views.setTextViewText(R.id.days_label, "")
                        views.setTextViewText(R.id.exam_date, "All done!")
                        views.setTextViewText(R.id.exam_time, "")
                    }
                }
            }
            
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

/**
 * STYLE 9: Exam Details Widget (4x3)
 * Detailed exam list with room and seat info
 * Dynamically adjusts item count based on widget size
 */
class ExamDetailsWidget : AppWidgetProvider() {
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
        private fun createExamIntent(context: Context, exam: ExamData, requestCode: Int): PendingIntent {
            // Create unique key for the exam matching the Flutter format:
            // ${exam.date}|${exam.startTime}|${exam.finishTime}|${exam.subjectDescription}|${exam.examRoom}|${exam.seatNumber}
            val examKey = "${exam.date}|${exam.startTime}|${exam.finishTime}|${exam.subjectDescription}|${exam.examRoom}|${exam.seatNumber}"
            val encodedKey = android.net.Uri.encode(examKey)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("nscgschedule://exams?open=$encodedKey")
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, options: Bundle? = null) {
            val views = RemoteViews(context.packageName, R.layout.widget_exam_details)
            
            // Get widget cell dimensions
            val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
            val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
            val cellWidth = WidgetDataHelper.getWidgetCellWidth(minWidth)
            val cellHeight = WidgetDataHelper.getWidgetCellHeight(minHeight)
            
            // Determine max items based on cell dimensions
            val maxItems = when {
                cellWidth <= 3 && cellHeight <= 2 -> 2  // 3x2 or smaller
                cellWidth <= 3 -> 3  // 3x3 or 3x4
                cellHeight <= 2 -> 3  // 4x2
                cellHeight <= 3 -> 5  // 4x3
                else -> 8  // 4x4 or larger
            }
            
            val exams = WidgetDataHelper.getUpcomingExams(context, maxItems)
            
            views.setTextViewText(R.id.widget_title, "Exam Schedule")
            views.setTextViewText(R.id.exam_count, WidgetDataHelper.getUpcomingExams(context, 10).size.toString())
            
            val examSlots = listOf(
                listOf(R.id.exam1_container, R.id.exam1_subject, R.id.exam1_date, R.id.exam1_time, R.id.exam1_room),
                listOf(R.id.exam2_container, R.id.exam2_subject, R.id.exam2_date, R.id.exam2_time, R.id.exam2_room),
                listOf(R.id.exam3_container, R.id.exam3_subject, R.id.exam3_date, R.id.exam3_time, R.id.exam3_room),
                listOf(R.id.exam4_container, R.id.exam4_subject, R.id.exam4_date, R.id.exam4_time, R.id.exam4_room),
                listOf(R.id.exam5_container, R.id.exam5_subject, R.id.exam5_date, R.id.exam5_time, R.id.exam5_room),
                listOf(R.id.exam6_container, R.id.exam6_subject, R.id.exam6_date, R.id.exam6_time, R.id.exam6_room),
                listOf(R.id.exam7_container, R.id.exam7_subject, R.id.exam7_date, R.id.exam7_time, R.id.exam7_room),
                listOf(R.id.exam8_container, R.id.exam8_subject, R.id.exam8_date, R.id.exam8_time, R.id.exam8_room)
            )
            
            examSlots.forEachIndexed { index, ids ->
                if (index < exams.size) {
                    val exam = exams[index]
                    views.setViewVisibility(ids[0], android.view.View.VISIBLE)
                    views.setTextViewText(ids[1], exam.subjectDescription)
                    views.setTextViewText(ids[2], WidgetDataHelper.formatExamDateShort(exam.date))
                    views.setTextViewText(ids[3], "${exam.startTime} - ${exam.finishTime}")
                    val roomText = buildString {
                        if (exam.preRoom.isNotEmpty()) {
                            append("Pre: ${exam.preRoom} → ")
                        }
                        append(exam.examRoom)
                        if (exam.seatNumber.isNotEmpty()) {
                            append(" • Seat ${exam.seatNumber}")
                        }
                    }
                    views.setTextViewText(ids[4], roomText)
                    
                    // Set click handler for this exam card
                    val pendingIntent = createExamIntent(context, exam, appWidgetId * 100 + index)
                    views.setOnClickPendingIntent(ids[0], pendingIntent)
                } else {
                    views.setViewVisibility(ids[0], android.view.View.GONE)
                }
            }
            
            if (exams.isEmpty()) {
                views.setViewVisibility(R.id.empty_message, android.view.View.VISIBLE)
                val emptyMessage = when {
                    !WidgetDataHelper.hasExams(context) -> "⚙️ No exams set up\nTap to add your exams"
                    else -> "✓ No upcoming exams\nAll done!"
                }
                views.setTextViewText(R.id.empty_message, emptyMessage)
            } else {
                views.setViewVisibility(R.id.empty_message, android.view.View.GONE)
            }
            
            // Main widget click goes to exams page
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("nscgschedule://exams")
                setPackage(context.packageName)
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
