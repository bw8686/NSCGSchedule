# Widget Update Scheduling Implementation

## Overview
Implemented an automatic widget update scheduling system that refreshes widgets at appropriate times based on the timetable and exam schedule. This works independently of notification settings, so widgets update even if notifications are disabled.

## Architecture

### 1. **WidgetUpdateReceiver.kt**
A BroadcastReceiver that handles scheduled widget updates.
- **Actions**:
  - `UPDATE_WIDGETS`: Update all widgets
  - `UPDATE_LESSON_WIDGETS`: Update only lesson widgets
  - `UPDATE_EXAM_WIDGETS`: Update only exam widgets
- **System Events**: Also responds to system time/timezone changes

### 2. **WidgetUpdateScheduler.kt**
Manages AlarmManager scheduling for widget updates.
- **Lesson Updates**: Schedules weekly repeating alarms at lesson start/end times
- **Exam Updates**: Schedules one-time alarms for exam times and midnight before exam days
- **Daily Update**: Schedules midnight updates to refresh all widgets daily
- **Request Codes**:
  - 10000-10999: Lesson update alarms
  - 20000-20999: Exam update alarms
  - 30000: Daily midnight update

### 3. **WidgetService.dart** (Updated)
Added `scheduleWidgetUpdates()` method that calls the native Android scheduler whenever timetable data is synced.

### 4. **MainActivity.kt** (Updated)
Added `scheduleWidgetUpdates` method handler to trigger the scheduling from Flutter.

### 5. **AndroidManifest.xml** (Updated)
Registered WidgetUpdateReceiver with intent filters for custom actions and system events.

## How It Works

### Scheduling Flow
1. When timetable or exam data is synced from Flutter:
   ```dart
   await WidgetService.instance.syncTimetableToWidget();
   await WidgetService.instance.syncExamTimetableToWidget();
   ```

2. This automatically calls `scheduleWidgetUpdates()` which:
   - Cancels all existing alarms (to avoid duplicates)
   - Reads timetable from SharedPreferences
   - Creates AlarmManager alarms for each lesson start/end time (weekly repeating)
   - Creates alarms for each exam start/end time (one-time)
   - Creates midnight alarms for exam days (to update countdown from "1d" to "0d")
   - Creates daily midnight alarm for general refresh

3. When an alarm fires:
   - WidgetUpdateReceiver receives the broadcast
   - Determines which widgets to update based on action
   - Sends UPDATE intent to specific widget providers

### Update Triggers

#### Lesson Widgets Update:
- At lesson start time (e.g., 09:00)
- At lesson end time (e.g., 10:30)
- Weekly repeating pattern
- Midnight daily refresh

#### Exam Widgets Update:
- At exam start time
- At exam end time
- At midnight on exam day (to show "0 days")
- Midnight daily refresh

#### All Widgets Update:
- System time/timezone changes
- Daily at midnight
- Manual updates from app

## Benefits

1. **Independent of Notifications**: Widgets update even if user disables notifications
2. **Battery Efficient**: Uses AlarmManager with exact timing only when needed
3. **Accurate Timing**: Updates at exact lesson/exam times
4. **Handles Time Changes**: Automatically updates when system time changes
5. **Daily Refresh**: Ensures widgets stay current with midnight updates

## Usage

### From Flutter Code
```dart
// Schedule updates automatically when syncing data
await WidgetService.instance.syncTimetableToWidget();
await WidgetService.instance.syncExamTimetableToWidget();

// Or manually schedule updates
await WidgetService.instance.scheduleWidgetUpdates();
```

### Existing Integration Points
The scheduling is automatically triggered when:
- User logs in and timetable is fetched
- Timetable is refreshed
- Exam timetable is updated
- Settings page calls reschedule

## Technical Details

### AlarmManager Strategy
- **Lesson times**: `setRepeating()` with INTERVAL_DAY * 7 for weekly pattern
- **Exam times**: `setExactAndAllowWhileIdle()` for one-time precise timing
- **Midnight updates**: `setRepeating()` with INTERVAL_DAY

### Request Code Ranges
Prevents conflicts by using distinct ranges:
- 10000-10999: Lesson alarms
- 20000-20999: Exam alarms  
- 30000: Daily midnight alarm

### SharedPreferences Keys
- `flutter.timetable`: JSON string of timetable data
- `flutter.examTimetable`: JSON string of exam timetable data

## Future Enhancements
- Add settings option to enable/disable widget auto-updates
- Optimize by only scheduling alarms for widgets actually added to home screen
- Add smart scheduling to update only when widget data would visibly change
- Implement exponential backoff for failed widget updates
