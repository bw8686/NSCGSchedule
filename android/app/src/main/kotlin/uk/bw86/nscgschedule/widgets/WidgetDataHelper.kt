package uk.bw86.nscgschedule.widgets

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

data class LessonData(
    val name: String,
    val course: String,
    val startTime: String,
    val endTime: String,
    val room: String,
    val teachers: List<String>,
    val group: String
)

data class ExamData(
    val date: String,
    val startTime: String,
    val finishTime: String,
    val subjectDescription: String,
    val examRoom: String,
    val seatNumber: String,
    val paper: String,
    val boardCode: String,
    val preRoom: String
)

data class DaySchedule(
    val day: String,
    val lessons: List<LessonData>
)

object WidgetDataHelper {
    sealed class ScheduleItem {
        data class Lesson(val data: LessonData) : ScheduleItem()
        data class Exam(val data: ExamData, val isToday: Boolean) : ScheduleItem()
    }
    
    private const val PREFS_NAME = "FlutterSharedPreferences"
    
    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    /**
     * Get current time, respecting debug mode if enabled
     */
    internal fun getCurrentTime(context: Context): Calendar {
        val prefs = getPrefs(context)
        val debugEnabled = prefs.getBoolean("flutter.debug_enabled", false)
        
        return if (debugEnabled) {
            val debugTimeMillis = prefs.getLong("flutter.debug_time_millis", System.currentTimeMillis())
            // Debug time is the base time when it was set
            // Calculate how much real time has passed since then and add it to debug time
            val debugSetTime = prefs.getLong("flutter.debug_set_real_time", System.currentTimeMillis())
            val realTimePassed = System.currentTimeMillis() - debugSetTime
            val currentDebugTime = debugTimeMillis + realTimePassed
            
            Calendar.getInstance().apply {
                timeInMillis = currentDebugTime
            }
        } else {
            Calendar.getInstance()
        }
    }
    
    fun getTimetable(context: Context): List<DaySchedule> {
        val prefs = getPrefs(context)
        val timetableJson = prefs.getString("flutter.timetable", null) ?: return emptyList()
        
        return try {
            val json = JSONObject(timetableJson)
            val daysArray = json.getJSONArray("days")
            val days = mutableListOf<DaySchedule>()
            
            for (i in 0 until daysArray.length()) {
                val dayObj = daysArray.getJSONObject(i)
                val dayName = dayObj.getString("day")
                val lessonsArray = dayObj.getJSONArray("lessons")
                val lessons = mutableListOf<LessonData>()
                
                for (j in 0 until lessonsArray.length()) {
                    val lessonObj = lessonsArray.getJSONObject(j)
                    val teachersArray = lessonObj.getJSONArray("teachers")
                    val teachers = mutableListOf<String>()
                    for (k in 0 until teachersArray.length()) {
                        teachers.add(teachersArray.getString(k))
                    }
                    
                    lessons.add(LessonData(
                        name = lessonObj.getString("name"),
                        course = lessonObj.getString("course"),
                        startTime = lessonObj.getString("startTime"),
                        endTime = lessonObj.getString("endTime"),
                        room = lessonObj.getString("room"),
                        teachers = teachers,
                        group = lessonObj.getString("group")
                    ))
                }
                
                days.add(DaySchedule(dayName, lessons))
            }
            
            days
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    fun getExams(context: Context): List<ExamData> {
        val prefs = getPrefs(context)
        val examJson = prefs.getString("flutter.examTimetable", null) ?: return emptyList()
        
        return try {
            val json = JSONObject(examJson)
            if (!json.getBoolean("hasExams")) return emptyList()
            
            val examsArray = json.getJSONArray("exams")
            val exams = mutableListOf<ExamData>()
            
            for (i in 0 until examsArray.length()) {
                val examObj = examsArray.getJSONObject(i)
                exams.add(ExamData(
                    date = examObj.getString("date"),
                    startTime = examObj.getString("startTime"),
                    finishTime = examObj.getString("finishTime"),
                    subjectDescription = examObj.getString("subjectDescription"),
                    examRoom = examObj.getString("examRoom"),
                    seatNumber = examObj.getString("seatNumber"),
                    paper = examObj.getString("paper"),
                    boardCode = examObj.getString("boardCode"),
                    preRoom = examObj.getString("preRoom")
                ))
            }
            
            exams
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    fun getTodayLessons(context: Context): List<LessonData> {
        val timetable = getTimetable(context)
        val todayName = getCurrentDayName(context)
        return timetable.find { it.day.equals(todayName, ignoreCase = true) }?.lessons ?: emptyList()
    }
    
    fun getTomorrowLessons(context: Context): List<LessonData> {
        val timetable = getTimetable(context)
        val tomorrowName = getTomorrowDayName(context)
        return timetable.find { it.day.equals(tomorrowName, ignoreCase = true) }?.lessons ?: emptyList()
    }
    
    /**
     * Check if user has any timetable set up at all
     */
    fun hasTimetable(context: Context): Boolean {
        val prefs = getPrefs(context)
        val timetableJson = prefs.getString("flutter.timetable", null)
        return !timetableJson.isNullOrEmpty() && getTimetable(context).isNotEmpty()
    }
    
    /**
     * Check if user has any exams set up at all
     */
    fun hasExams(context: Context): Boolean {
        return getExams(context).isNotEmpty()
    }
    
    /**
     * Check if there are any lessons scheduled for today
     */
    fun hasLessonsToday(context: Context): Boolean {
        return getTodayLessons(context).isNotEmpty()
    }
    
    /**
     * Check if there are any remaining lessons today (not yet finished)
     */
    fun hasRemainingLessonsToday(context: Context): Boolean {
        val lessons = getTodayLessons(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return lessons.any { lesson ->
            parseTimeToMinutes(lesson.endTime) > currentMinutes
        }
    }
    
    /**
     * Check if there are any upcoming exams (today or future)
     */
    fun hasUpcomingExams(context: Context): Boolean {
        return getUpcomingExams(context, 1).isNotEmpty()
    }
    
    /**
     * Check if there are any exams today
     */
    fun hasExamsToday(context: Context): Boolean {
        val exams = getExams(context)
        val today = getCurrentTime(context)
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)
        
        return exams.any { exam ->
            val examDate = parseExamDate(exam.date)
            examDate != null && isSameDay(examDate, today.time)
        }
    }
    
    fun getUpcomingExams(context: Context, limit: Int = 5): List<ExamData> {
        val exams = getExams(context)
        val today = getCurrentTime(context)
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)
        
        return exams.filter { exam ->
            val examDate = parseExamDate(exam.date)
            examDate != null && !examDate.before(today.time)
        }.sortedBy { parseExamDate(it.date) }.take(limit)
    }
    
    fun getNextExam(context: Context): ExamData? {
        return getUpcomingExams(context, 1).firstOrNull()
    }
    
    fun getCurrentLesson(context: Context): LessonData? {
        val lessons = getTodayLessons(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return lessons.find { lesson ->
            val startMinutes = parseTimeToMinutes(lesson.startTime)
            val endMinutes = parseTimeToMinutes(lesson.endTime)
            currentMinutes in startMinutes until endMinutes
        }
    }
    
    fun getNextLesson(context: Context): LessonData? {
        val lessons = getTodayLessons(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return lessons.filter { lesson ->
            parseTimeToMinutes(lesson.startTime) > currentMinutes
        }.minByOrNull { parseTimeToMinutes(it.startTime) }
    }
    
    /**
     * Get merged schedule items (lessons and exams) for today with intersection handling
     * If a lesson intersects with an exam:
     * - If exam is longer than lesson: remove the lesson entirely
     * - If exam is shorter: adjust lesson start time to when exam ends
     */
    fun getTodayMergedSchedule(context: Context): List<ScheduleItem> {
        val lessons = getTodayLessons(context).toMutableList()
        val exams = getExams(context)
        val now = getCurrentTime(context)
        val result = mutableListOf<ScheduleItem>()
        
        // Get today's date for comparison
        val today = getCurrentTime(context)
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)
        
        // Filter exams for today
        val todayExams = exams.filter { exam ->
            val examDate = parseExamDate(exam.date)
            examDate != null && isSameDay(examDate, today.time)
        }
        
        // Process lesson-exam intersections
        val adjustedLessons = mutableListOf<LessonData>()
        
        for (lesson in lessons) {
            val lessonStart = parseTimeToMinutes(lesson.startTime)
            val lessonEnd = parseTimeToMinutes(lesson.endTime)
            var lessonToAdd: LessonData? = lesson
            
            for (exam in todayExams) {
                val examStart = parseTimeToMinutes(exam.startTime)
                val examEnd = parseTimeToMinutes(exam.finishTime)
                
                // Check if lesson and exam intersect
                val intersects = !(lessonEnd <= examStart || lessonStart >= examEnd)
                
                if (intersects) {
                    val lessonDuration = lessonEnd - lessonStart
                    val examDuration = examEnd - examStart
                    
                    if (examDuration >= lessonDuration) {
                        // Exam is longer than or equal to lesson - remove lesson entirely
                        lessonToAdd = null
                        break
                    } else {
                        // Exam is shorter - adjust lesson start time to when exam ends
                        if (examEnd < lessonEnd) {
                            val hoursAdj = examEnd / 60
                            val minutesAdj = examEnd % 60
                            val newStartTime = String.format("%02d:%02d", hoursAdj, minutesAdj)
                            lessonToAdd = LessonData(
                                name = lesson.name,
                                course = lesson.course,
                                startTime = newStartTime,
                                endTime = lesson.endTime,
                                room = lesson.room,
                                teachers = lesson.teachers,
                                group = lesson.group
                            )
                        } else {
                            // Exam covers entire lesson time - remove lesson
                            lessonToAdd = null
                            break
                        }
                    }
                }
            }
            
            if (lessonToAdd != null) {
                adjustedLessons.add(lessonToAdd)
            }
        }
        
        // Add all adjusted lessons
        adjustedLessons.forEach { lesson ->
            result.add(ScheduleItem.Lesson(lesson))
        }
        
        // Add all today's exams
        todayExams.forEach { exam ->
            result.add(ScheduleItem.Exam(exam, true))
        }
        
        // Sort by start time
        result.sortBy { item ->
            when (item) {
                is ScheduleItem.Lesson -> parseTimeToMinutes(item.data.startTime)
                is ScheduleItem.Exam -> parseTimeToMinutes(item.data.startTime)
            }
        }
        
        return result
    }
    
    /**
     * Get next item from merged schedule (could be lesson or exam)
     */
    fun getNextScheduleItem(context: Context): ScheduleItem? {
        val merged = getTodayMergedSchedule(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return merged.firstOrNull { item ->
            val startMinutes = when (item) {
                is ScheduleItem.Lesson -> parseTimeToMinutes(item.data.startTime)
                is ScheduleItem.Exam -> parseTimeToMinutes(item.data.startTime)
            }
            startMinutes > currentMinutes
        }
    }
    
    /**
     * Get current item from merged schedule (lesson or exam happening now)
     */
    fun getCurrentScheduleItem(context: Context): ScheduleItem? {
        val merged = getTodayMergedSchedule(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return merged.firstOrNull { item ->
            val startMinutes: Int
            val endMinutes: Int
            
            when (item) {
                is ScheduleItem.Lesson -> {
                    startMinutes = parseTimeToMinutes(item.data.startTime)
                    endMinutes = parseTimeToMinutes(item.data.endTime)
                }
                is ScheduleItem.Exam -> {
                    startMinutes = parseTimeToMinutes(item.data.startTime)
                    endMinutes = parseTimeToMinutes(item.data.finishTime)
                }
            }
            
            currentMinutes in startMinutes until endMinutes
        }
    }
    
    private fun isSameDay(date1: Date, date2: Date): Boolean {
        val cal1 = Calendar.getInstance().apply { time = date1 }
        val cal2 = Calendar.getInstance().apply { time = date2 }
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
                cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }
    
    fun getUpcomingLessonsToday(context: Context, limit: Int = 5): List<LessonData> {
        val lessons = getTodayLessons(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        // Include lessons that are currently happening (end time > now) or haven't started yet
        return lessons.filter { lesson ->
            val endMinutes = parseTimeToMinutes(lesson.endTime)
            endMinutes > currentMinutes // Show if not yet finished
        }.take(limit)
    }
    
    /**
     * Get upcoming merged schedule items (lessons and exams) for today
     */
    fun getUpcomingMergedScheduleToday(context: Context, limit: Int = 5): List<ScheduleItem> {
        val merged = getTodayMergedSchedule(context)
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        
        return merged.filter { item ->
            val endMinutes = when (item) {
                is ScheduleItem.Lesson -> parseTimeToMinutes(item.data.endTime)
                is ScheduleItem.Exam -> parseTimeToMinutes(item.data.finishTime)
            }
            endMinutes > currentMinutes
        }.take(limit)
    }
    
    fun getDaysUntilExam(context: Context, exam: ExamData): Int {
        val examDate = parseExamDate(exam.date) ?: return -1
        val today = getCurrentTime(context)
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)
        
        val diff = examDate.time - today.timeInMillis
        return (diff / (24 * 60 * 60 * 1000)).toInt()
    }
    
    fun formatExamDate(dateStr: String): String {
        val date = parseExamDate(dateStr) ?: return dateStr
        val format = SimpleDateFormat("EEE, MMM d", Locale.getDefault())
        return format.format(date)
    }
    
    fun formatExamDateShort(dateStr: String): String {
        val date = parseExamDate(dateStr) ?: return dateStr
        val format = SimpleDateFormat("MMM d", Locale.getDefault())
        return format.format(date)
    }
    
    private fun parseExamDate(dateStr: String): Date? {
        return try {
            val parts = dateStr.split("-")
            if (parts.size == 3) {
                val cal = Calendar.getInstance()
                cal.set(parts[2].toInt(), parts[1].toInt() - 1, parts[0].toInt(), 0, 0, 0)
                cal.set(Calendar.MILLISECOND, 0)
                cal.time
            } else null
        } catch (e: Exception) {
            null
        }
    }
    
    internal fun parseTimeToMinutes(time: String): Int {
        return try {
            val parts = time.split(":")
            parts[0].toInt() * 60 + parts[1].toInt()
        } catch (e: Exception) {
            0
        }
    }
    
    private fun getCurrentDayName(context: Context): String {
        val cal = getCurrentTime(context)
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "Monday"
            Calendar.TUESDAY -> "Tuesday"
            Calendar.WEDNESDAY -> "Wednesday"
            Calendar.THURSDAY -> "Thursday"
            Calendar.FRIDAY -> "Friday"
            Calendar.SATURDAY -> "Saturday"
            Calendar.SUNDAY -> "Sunday"
            else -> ""
        }
    }
    
    private fun getTomorrowDayName(context: Context): String {
        val cal = getCurrentTime(context)
        cal.add(Calendar.DAY_OF_WEEK, 1)
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "Monday"
            Calendar.TUESDAY -> "Tuesday"
            Calendar.WEDNESDAY -> "Wednesday"
            Calendar.THURSDAY -> "Thursday"
            Calendar.FRIDAY -> "Friday"
            Calendar.SATURDAY -> "Saturday"
            Calendar.SUNDAY -> "Sunday"
            else -> ""
        }
    }
    
    fun getFormattedTimeUntilLesson(context: Context, lesson: LessonData): String {
        val now = getCurrentTime(context)
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val startMinutes = parseTimeToMinutes(lesson.startTime)
        val diff = startMinutes - currentMinutes
        
        return when {
            diff < 0 -> "Now"
            diff == 0 -> "Now"
            diff < 60 -> "${diff}m"
            else -> "${diff / 60}h"
        }
    }
    
    /**
     * Format days until exam in single unit (days, hours, or minutes)
     */
    fun getFormattedDaysUntilExam(context: Context, exam: ExamData): String {
        val daysUntil = getDaysUntilExam(context, exam)
        
        return when {
            daysUntil == 0 -> {
                // Same day - show hours or "TODAY"
                val now = getCurrentTime(context)
                val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
                val startMinutes = parseTimeToMinutes(exam.startTime)
                val diffMinutes = startMinutes - currentMinutes
                
                when {
                    diffMinutes <= 0 -> "NOW"
                    diffMinutes < 60 -> "${diffMinutes}m"
                    else -> "${diffMinutes / 60}h"
                }
            }
            daysUntil == 1 -> "1d"
            daysUntil < 7 -> "${daysUntil}d"
            daysUntil < 30 -> "${daysUntil / 7}w"
            else -> "${daysUntil / 30}mo"
        }
    }
    
    fun isWeekend(context: Context): Boolean {
        val cal = getCurrentTime(context)
        val day = cal.get(Calendar.DAY_OF_WEEK)
        return day == Calendar.SATURDAY || day == Calendar.SUNDAY
    }
    
    /**
     * Get the day of week name
     */
    fun getCurrentDayNamePublic(context: Context): String = getCurrentDayName(context)
    
    /**
     * Calculate approximate widget cell size from dp dimensions
     * Formula: (dp + 30) / 70 per Android widget sizing guidelines
     */
    fun getWidgetCellWidth(widthDp: Int): Int {
        return ((widthDp + 30) / 70).coerceAtLeast(1)
    }
    
    fun getWidgetCellHeight(heightDp: Int): Int {
        return ((heightDp + 30) / 70).coerceAtLeast(1)
    }
}
