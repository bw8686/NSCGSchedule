import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:nscgschedule/models/timetable_models.dart';
import 'package:nscgschedule/models/exam_models.dart';
import 'package:nscgschedule/settings.dart';
import 'package:nscgschedule/watch_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NSCGRequests {
  final Dio _dio = Dio();
  static final instance = NSCGRequests();
  StreamController<bool> updateController = StreamController<bool>.broadcast();
  StreamController<bool> debugModeController =
      StreamController<bool>.broadcast();
  StreamController<bool> loggedinController =
      StreamController<bool>.broadcast();

  NSCGRequests() {
    _dio.options.baseUrl = 'https://my.nulc.ac.uk';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Configure SSL certificate handling for self-signed or problematic certificates
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            // Only bypass SSL verification for my.nulc.ac.uk
            return host == 'my.nulc.ac.uk';
          };
      return client;
    };
  }

  // Merge room numbers from an old timetable into a freshly fetched timetable.
  // Rule: only use the old timetable's room when the freshly fetched lesson's
  // room is empty (ignoring whitespace) and the old room is non-empty.
  Timetable _mergeRoomNumbers(Timetable oldT, Timetable newT) {
    debugPrint(
      'Requests: merging room numbers: oldDays=${oldT.days.length}, newDays=${newT.days.length}',
    );

    final mergedDays = newT.days.map((newDay) {
      final oldDay = oldT.days.firstWhere(
        (d) => d.day.toLowerCase().contains(
          newDay.day.toLowerCase().split(' ').first,
        ),
        orElse: () => DaySchedule(day: newDay.day, lessons: []),
      );

      debugPrint(
        'Requests: merging day "${newDay.day}": new=${newDay.lessons.length}, old=${oldDay.lessons.length}',
      );

      final mergedLessons = newDay.lessons.map((newLesson) {
        // Find matching lesson in old day by normalized name/start/end
        Lesson? match;
        try {
          match = oldDay.lessons.firstWhere((ol) {
            final oldName = ol.name.trim().toLowerCase();
            final newName = newLesson.name.trim().toLowerCase();
            final oldStart = ol.startTime.replaceAll(' ', '').toLowerCase();
            final newStart = newLesson.startTime
                .replaceAll(' ', '')
                .toLowerCase();
            final oldEnd = ol.endTime.replaceAll(' ', '').toLowerCase();
            final newEnd = newLesson.endTime.replaceAll(' ', '').toLowerCase();
            return oldName == newName &&
                oldStart == newStart &&
                oldEnd == newEnd;
          });
        } catch (e) {
          match = null;
        }

        final newRoom = newLesson.room.trim();
        final oldRoom = match != null ? match.room.trim() : '';
        String room;
        if (newRoom.isEmpty && oldRoom.isNotEmpty) {
          room = oldRoom;
          debugPrint(
            'Requests: using old room for "${newLesson.name}": "$room"',
          );
        } else {
          room = newLesson.room;
        }

        return Lesson(
          teachers: newLesson.teachers,
          course: newLesson.course,
          group: newLesson.group,
          name: newLesson.name,
          startTime: newLesson.startTime,
          endTime: newLesson.endTime,
          room: room,
        );
      }).toList();

      return DaySchedule(day: newDay.day, lessons: mergedLessons);
    }).toList();

    debugPrint('Requests: merging complete');
    return Timetable(days: mergedDays);
  }

  Future<bool> debugMode(bool value) async {
    await settings.setBool('debugMode', value);
    debugModeController.add(value);
    return value;
  }

  Future<Timetable?> getTimeTable() async {
    try {
      final cookiesString = await settings.getKey('cookies');
      if (cookiesString.isEmpty) {
        return null;
      }

      // Parse the cookies string and format it for the Cookie header
      final cookiePairs = <String>[];
      final cookieMatches = RegExp(
        r'name: ([^,]+),.*?value: ([^,}]+)',
      ).allMatches(cookiesString);

      for (final match in cookieMatches) {
        if (match.groupCount >= 2) {
          final name = match.group(1)?.trim();
          final value = match.group(2)?.trim();
          if (name != null && value != null) {
            cookiePairs.add('$name=$value');
          }
        }
      }

      final cookieHeader = cookiePairs.join('; ');

      final response = await _dio.get<String>(
        '/studentTT/',
        options: Options(
          headers: {'Cookie': cookieHeader, 'Accept': 'text/html'},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.realUri.toString().contains('studentTT/')) {
        // Parse freshly fetched timetable
        Timetable newTimetable = Timetable.fromHtml(response.data!);

        // Attempt to load previously stored timetable so we can carry over room
        // numbers (including any user edits) where the freshly fetched item
        // has an empty room value.
        try {
          final stored = await settings.getMap('timetable');
          if (stored.isNotEmpty) {
            try {
              final oldTimetable = Timetable.fromJson(stored);
              final merged = _mergeRoomNumbers(oldTimetable, newTimetable);
              await settings.setMap('timetable', merged.toJson());
              await settings.setKey(
                'timetableUpdated',
                DateTime.now().toIso8601String(),
              );
              // Sync with WearOS watch
              WatchService.instance.syncTimetable();
              WatchService.instance.updateContext();
              debugPrint('getTimeTable: persisted merged timetable');
              return merged;
            } catch (e) {
              debugPrint('getTimeTable: failed to merge timetables: $e');
              // Fall back to saving the freshly parsed timetable
              await settings.setMap('timetable', newTimetable.toJson());
              await settings.setKey(
                'timetableUpdated',
                DateTime.now().toIso8601String(),
              );
              WatchService.instance.syncTimetable();
              WatchService.instance.updateContext();
              return newTimetable;
            }
          } else {
            // No stored timetable, persist the freshly fetched one
            await settings.setMap('timetable', newTimetable.toJson());
            await settings.setKey(
              'timetableUpdated',
              DateTime.now().toIso8601String(),
            );
            WatchService.instance.syncTimetable();
            WatchService.instance.updateContext();
            debugPrint('getTimeTable: persisted new timetable');
            return newTimetable;
          }
        } catch (e) {
          debugPrint('getTimeTable: error reading stored timetable: $e');
          await settings.setMap('timetable', newTimetable.toJson());
          await settings.setKey(
            'timetableUpdated',
            DateTime.now().toIso8601String(),
          );
          WatchService.instance.syncTimetable();
          WatchService.instance.updateContext();
          return newTimetable;
        }
      } else {
        settings.setBool('loggedin', false);
        loggedinController.add(false);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<ExamTimetable?> getExamTimetable() async {
    try {
      final cookiesString = await settings.getKey('cookies');
      if (cookiesString.isEmpty) {
        return null;
      }

      // Parse the cookies string and format it for the Cookie header
      final cookiePairs = <String>[];
      final cookieMatches = RegExp(
        r'name: ([^,]+),.*?value: ([^,}]+)',
      ).allMatches(cookiesString);

      for (final match in cookieMatches) {
        if (match.groupCount >= 2) {
          final name = match.group(1)?.trim();
          final value = match.group(2)?.trim();
          if (name != null && value != null) {
            cookiePairs.add('$name=$value');
          }
        }
      }

      final cookieHeader = cookiePairs.join('; ');

      final response = await _dio.get<String>(
        '/exams/',
        options: Options(
          headers: {'Cookie': cookieHeader, 'Accept': 'text/html'},
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        ExamTimetable examTimetable = ExamTimetable.fromHtml(response.data!);
        settings.setMap('examTimetable', examTimetable.toJson());
        settings.setKey(
          'examTimetableUpdated',
          DateTime.now().toIso8601String(),
        );
        // Sync with WearOS watch
        WatchService.instance.syncExamTimetable();
        WatchService.instance.updateContext();
        return examTimetable;
      } else {
        settings.setBool('loggedin', false);
        loggedinController.add(false);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateApp() async {
    try {
      final dio = Dio();
      dio.options.baseUrl = 'https://raw.githubusercontent.com';
      final response = await dio.get(
        '/bw8686/nscgschedule/refs/heads/main/update.json',
      );
      final packageInfo = await PackageInfo.fromPlatform();
      final deData = jsonDecode(response.data);
      if (deData['version'] != packageInfo.version) {
        updateController.add(true);
      } else {
        updateController.add(false);
      }
      return deData;
    } catch (e) {
      return {};
    }
  }
}
