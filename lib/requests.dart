import 'package:dio/dio.dart';
import 'package:nscgschedule/models/timetable_models.dart';
import 'package:nscgschedule/settings.dart';

class NSCGRequests {
  final Dio _dio = Dio();

  NSCGRequests() {
    _dio.options.baseUrl = 'https://my.nulc.ac.uk';
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateApp() async {
    try {
      final response = await _dio.get<String>(
        '/studentTT/',
        options: Options(
          headers: {'Cookie': cookieHeader, 'Accept': 'text/html'},
          responseType: ResponseType.plain,
        ),
      );
      return response.data!;
    } catch (e) {
      return {};
    }
  }
}
