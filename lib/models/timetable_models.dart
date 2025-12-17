import 'package:html/parser.dart' show parse;

class Timetable {
  final List<DaySchedule> days;

  const Timetable({required this.days});

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      days: (json['days'] as List)
          .map(
            (dayJson) => DaySchedule.fromJson(dayJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'days': days.map((day) => day.toJson()).toList()};
  }

  factory Timetable.fromHtml(String html) {
    final document = parse(html);

    // Map of left position (in inches) -> weekday name
    final dayPositions = <double, String>{
      0.5: 'Monday',
      3.0: 'Tuesday',
      5.5: 'Wednesday',
      8.0: 'Thursday',
      10.5: 'Friday',
    };

    String? weekdayForLeft(double left) {
      for (final entry in dayPositions.entries) {
        if ((entry.key - left).abs() < 0.2) return entry.value;
      }
      return null;
    }

    final daysMap = <String, List<Lesson>>{};

    final items = document.querySelectorAll('div.ttItem');
    for (final item in items) {
      final classes = item.className;
      if (classes.contains('ttItemTimes') || classes.contains('ttItemDays')) {
        continue;
      }

      final style = item.attributes['style'] ?? '';
      final leftMatch = RegExp(
        r'left:\s*([0-9]*\.?[0-9]+)in',
      ).firstMatch(style);
      if (leftMatch == null) continue;
      final left = double.tryParse(leftMatch.group(1) ?? '');
      if (left == null) continue;

      final weekday = weekdayForLeft(left);
      if (weekday == null) continue;

      final inner = item.innerHtml.replaceAll(
        RegExp(r'<br\s*/?>', caseSensitive: false),
        '\n',
      );
      final text = parse(inner).body?.text ?? inner;
      final lines = text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final name = lines[0];

      String courseCode = '';
      String group = '';
      List<String> teachers = [];

      if (lines.length >= 2) {
        // Fallback parsing: expect "CODE GROUP Teachers..." on the second line
        final parts = lines[1].split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          courseCode = parts[0];
          if (parts.length >= 2) group = parts[1];
          if (parts.length > 2) {
            teachers = parts
                .sublist(2)
                .join(' ')
                .split(RegExp(r',\s*| and '))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }

      String startTime = '';
      String endTime = '';
      if (lines.length >= 3) {
        final timeLine = lines[2].replaceAll('\u00a0', ' ');
        final tmatch = RegExp(
          r'(\d{1,2}:\d{2}\s*(?:AM|PM)?)\s*[–-]\s*(\d{1,2}:\d{2}\s*(?:AM|PM)?)',
          caseSensitive: false,
        ).firstMatch(timeLine);
        if (tmatch != null) {
          startTime = tmatch.group(1)?.trim() ?? '';
          endTime = tmatch.group(2)?.trim() ?? '';
        }
      }

      final room = '';

      final lesson = Lesson(
        teachers: teachers,
        course: courseCode,
        group: group,
        name: name,
        startTime: startTime,
        endTime: endTime,
        room: room,
      );

      daysMap.putIfAbsent(weekday, () => []).add(lesson);
    }

    final order = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final days = <DaySchedule>[];
    for (final dayName in order) {
      if (daysMap.containsKey(dayName)) {
        days.add(DaySchedule(day: dayName, lessons: daysMap[dayName]!));
      }
    }

    return Timetable(days: days);
  }
}

class DaySchedule {
  final String day;
  final List<Lesson> lessons;

  const DaySchedule({required this.day, required this.lessons});

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      day: json['day'] as String,
      lessons: (json['lessons'] as List)
          .map(
            (lessonJson) => Lesson.fromJson(lessonJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
    };
  }

  @override
  String toString() => 'DaySchedule($day, ${lessons.length} lessons)';
}

class Lesson {
  final List<String> teachers;
  final String course;
  final String group;
  final String name;
  final String startTime;
  final String endTime;
  final String room;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      teachers: List<String>.from(json['teachers'] as List),
      course: json['course'] as String,
      group: json['group'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      room: json['room'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teachers': teachers,
      'course': course,
      'group': group,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
    };
  }

  const Lesson({
    required this.teachers,
    required this.course,
    required this.group,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  @override
  String toString() {
    return 'Lesson($name, $startTime-$endTime, $room, ${teachers.join(', ')})';
  }
}
