import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nscgschedule/settings.dart';

/// Service to sync timetable and exam data to SharedPreferences
/// so that Android home screen widgets can access it.
class WidgetService {
  static final WidgetService instance = WidgetService._();
  WidgetService._();

  static const _channel = MethodChannel('uk.bw86.nscgschedule/widgets');

  /// Sync timetable data to SharedPreferences for widget access
  Future<void> syncTimetableToWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timetableData = await settings.getMap('timetable');

      if (timetableData.isNotEmpty) {
        await prefs.setString('timetable', jsonEncode(timetableData));
        // Trigger widget update on Android
        if (Platform.isAndroid) {
          await _updateLessonWidgets();
          await _updateUnifiedWidgets();
          await scheduleWidgetUpdates();
        }
      }
    } catch (e) {
      // Silently fail - widgets will show empty state
    }
  }

  /// Sync exam timetable data to SharedPreferences for widget access
  Future<void> syncExamTimetableToWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examData = await settings.getMap('examTimetable');

      if (examData.isNotEmpty) {
        await prefs.setString('examTimetable', jsonEncode(examData));
        // Trigger widget update on Android
        if (Platform.isAndroid) {
          await _updateExamWidgets();
          await _updateUnifiedWidgets();
          await scheduleWidgetUpdates();
        }
      }
    } catch (e) {
      // Silently fail - widgets will show empty state
    }
  }

  /// Sync both timetable and exam data
  Future<void> syncAllToWidget() async {
    await syncTimetableToWidget();
    await syncExamTimetableToWidget();
  }

  /// Clear widget data (e.g., on logout)
  Future<void> clearWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('timetable');
      await prefs.remove('examTimetable');
      // Update widgets to show empty state
      if (Platform.isAndroid) {
        await updateAllWidgets();
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Update all Android widgets
  Future<void> updateAllWidgets() async {
    await _channel.invokeMethod('updateAllWidgets');
  }

  /// Update lesson widgets
  Future<void> _updateLessonWidgets() async {
    try {
      await _channel.invokeMethod('updateLessonWidgets');
    } catch (e) {
      // Method channel not available
    }
  }

  /// Update exam widgets
  Future<void> _updateExamWidgets() async {
    try {
      await _channel.invokeMethod('updateExamWidgets');
    } catch (e) {
      // Method channel not available
    }
  }

  /// Update unified widgets
  Future<void> _updateUnifiedWidgets() async {
    try {
      await _channel.invokeMethod('updateUnifiedWidgets');
    } catch (e) {
      // Method channel not available
    }
  }

  /// Schedule widget updates at specific times based on timetable
  /// This ensures widgets update when lessons start/end even if notifications are disabled
  Future<void> scheduleWidgetUpdates() async {
    try {
      await _channel.invokeMethod('scheduleWidgetUpdates');
    } catch (e) {
      // Method channel not available or scheduling failed
    }
  }
}
