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
    final days = <DaySchedule>[];
    String currentDay = '';
    List<Lesson> currentLessons = [];

    // Find all table rows
    final rows = document.querySelectorAll('table tr');

    for (final row in rows) {
      // Check if this is a day header row
      final dayHeader = row.querySelector('th[colspan="7"]');
      if (dayHeader != null) {
        // Save previous day's lessons if any
        if (currentDay.isNotEmpty && currentLessons.isNotEmpty) {
          days.add(
            DaySchedule(day: currentDay, lessons: List.from(currentLessons)),
          );
          currentLessons.clear();
        }
        currentDay = dayHeader.text.trim();
        continue;
      }

      // Process lesson rows (skip header rows)
      final cells = row.querySelectorAll('td');
      if (cells.length >= 7) {
        // Ensure we have all required columns
        final lesson = Lesson(
          teachers: cells[0].text
              .trim()
              .split(',')
              .map((e) => e.trim())
              .toList(),
          course: cells[1].text.trim(),
          group: cells[2].text.trim(),
          name: cells[3].text.trim(),
          startTime: cells[4].text.trim(),
          endTime: cells[5].text.trim(),
          room: cells[6].text.trim(),
        );
        currentLessons.add(lesson);
      }
    }

    // Add the last day's lessons if any
    if (currentDay.isNotEmpty && currentLessons.isNotEmpty) {
      days.add(
        DaySchedule(day: currentDay, lessons: List.from(currentLessons)),
      );
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
