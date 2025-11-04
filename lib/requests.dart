import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:nscgschedule/models/timetable_models.dart';
import 'package:nscgschedule/models/exam_models.dart';
import 'package:nscgschedule/settings.dart';
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
        Timetable timetable = Timetable.fromHtml(response.data!);
        settings.setMap('timetable', timetable.toJson());
        settings.setKey('timetableUpdated', DateTime.now().toIso8601String());
        return timetable;
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
