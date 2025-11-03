import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nscgschedule/models/timetable_models.dart' as models;
import 'package:nscgschedule/requests.dart';
import 'package:nscgschedule/settings.dart';
import 'package:nscgschedule/notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final CookieManager _cookieManager = CookieManager.instance();
  final NSCGRequests _requests = NSCGRequests.instance;
  bool _isLoading = true;
  String _error = '';
  models.Timetable? _timetable;
  String _timetableUpdated = '';
  bool _loggedin = false;
  Timer? _timer;
  String _timeRemaining = '';
  String? _nextLessonId; // Track which lesson should show the countdown
  bool _update = false;
  PackageInfo? _packageInfo;
  final NotificationService _notificationService =
      GetIt.I<NotificationService>();
  // Set to true to enable debug mode with simulated times
  bool _debugMode = false;
  // Current debug time (only used when _debugMode is true)
  DateTime _debugNow = DateTime.now();
  StreamSubscription<void>? _resub;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
    init();
    _startTimer();
    // Listen for notification settings changes to reschedule notifications
    _resub = settings.onNotificationSettingsChanged.listen((_) {
      _scheduleNotifications();
    });

    _notificationService.onReschedule.listen((_) {
      _scheduleNotifications();
    });

    _requests.debugModeController.stream.listen((value) {
      setState(() {
        _debugMode = value;
      });
    });

    _requests.updateController.stream.listen((value) {
      setState(() {
        _update = value;
      });
    });

    _requests.loggedinController.stream.listen((value) {
      setState(() {
        _loggedin = value;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resub?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeRemaining();
        });
      }
    });
  }

  // Add this method for debug controls
  Widget _buildDebugControls() {
    if (!_debugMode) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEBUG CONTROLS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Current time: '),
              Text(DateFormat('HH:mm').format(_debugNow)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _debugNow = _debugNow.add(const Duration(minutes: 30));
                    _updateTimeRemaining();
                  });
                },
                child: const Text('+30m'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _debugNow = _debugNow.subtract(const Duration(minutes: 30));
                    _updateTimeRemaining();
                  });
                },
                child: const Text('-30m'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _debugNow = DateTime.now();
                    _updateTimeRemaining();
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateTimeRemaining() {
    if (_timetable == null) return;

    final now = _debugMode ? _debugNow : DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final weekdayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    // Find today's lessons
    final todayLessons = _timetable!.days.where((day) {
      final dayName = day.day.toLowerCase();
      return dayName.contains(weekdayNames[currentWeekday - 1]);
    }).toList();

    if (todayLessons.isEmpty || todayLessons.first.lessons.isEmpty) {
      _timeRemaining = '';
      _nextLessonId = null;
      return;
    }

    // Find the next lesson today
    for (final lesson in todayLessons.first.lessons) {
      try {
        final startTime = _parseTimeString(lesson.startTime);
        if (startTime != null) {
          final lessonTime = DateTime(
            now.year,
            now.month,
            now.day,
            startTime.hour,
            startTime.minute,
          );

          final difference = lessonTime.difference(now);
          if (difference > Duration.zero) {
            final hours = difference.inHours;
            final minutes = difference.inMinutes.remainder(60);
            _timeRemaining =
                ' (in ${hours > 0 ? '${hours}h ' : ''}${minutes}m)';
            _nextLessonId =
                '${lesson.name}-${lesson.startTime}'; // Create a unique ID for the next lesson
            return;
          }
        }
      } catch (e) {
        debugPrint('Error calculating time remaining: $e');
      }
    }

    _timeRemaining = '';
    _nextLessonId = null;
  }

  TimeOfDay? _parseTimeString(String timeString) {
    try {
      // Handle formats like "9:45AM" or "9:45 AM"
      final cleanTime = timeString.trim().toUpperCase();
      final isPM = cleanTime.contains('PM');

      // Extract just the numbers
      final timePart = cleanTime.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = timePart.split(':');

      if (parts.length >= 2) {
        var hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        // Convert to 24-hour format if needed
        if (isPM && hour < 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0; // 12 AM is 0:00 in 24-hour format
        }

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('Error parsing time "$timeString": $e');
    }
    return null;
  }

  // Helper function to deeply convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertToTypedMap(Map<dynamic, dynamic> map) {
    return Map<String, dynamic>.fromIterable(
      map.entries,
      key: (entry) => entry.key.toString(),
      value: (entry) {
        if (entry.value is Map<dynamic, dynamic>) {
          return _convertToTypedMap(entry.value);
        } else if (entry.value is List) {
          return (entry.value as List).map((item) {
            if (item is Map<dynamic, dynamic>) {
              return _convertToTypedMap(item);
            }
            return item;
          }).toList();
        }
        return entry.value;
      },
    );
  }

  Future<void> init() async {
    final debugMode = await settings.getBool('debugMode');
    setState(() {
      _debugMode = debugMode;
    });
    final timetableData = await settings.getMap('timetable');
    final timetableUpdated = await settings.getKey('timetableUpdated');
    final loggedin = await settings.getBool('loggedin');
    final update = await _requests.updateApp();
    _update = update['version'] != _packageInfo?.version;
    final packageInfo = await PackageInfo.fromPlatform();
    if (timetableData.isNotEmpty) {
      try {
        // Convert the map and all nested maps to ensure they have the correct type
        final typedData = _convertToTypedMap(timetableData);
        final timetable = models.Timetable.fromJson(typedData);
        if (mounted) {
          setState(() {
            _packageInfo = packageInfo;
            _timetable = timetable;
            _timetableUpdated = timetableUpdated;
            _error = '';
            _loggedin = loggedin;
            _isLoading = false;
          });
          _scheduleNotifications();
          _loadTimetable();
        }
      } catch (e, stacktrace) {
        debugPrint('Error loading timetable: $e');
        debugPrint('Stacktrace: $stacktrace');
        await settings.setMap('timetable', {});
      }
    }
  }

  Future<void> _loadTimetable() async {
    if (!mounted) return;
    if (_error.isNotEmpty) {
      setState(() {
        _error = '';
      });
    }

    try {
      final timetable = await _requests.getTimeTable();
      final timetableUpdated = await settings.getKey('timetableUpdated');
      final loggedin = await settings.getBool('loggedin');

      if (timetable != null) {
        if (mounted) {
          setState(() {
            _timetable = timetable;
            _timetableUpdated = timetableUpdated;
            _loggedin = loggedin;
          });
        }
        _scheduleNotifications();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load timetable: ${e.toString()}';
          _isLoading = true;
        });
      }
    }
  }

  Future<void> _reloadTimetable() async {
    if (_loggedin) {
      await _loadTimetable();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Required'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height to prevent infinite constraints
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://my.nulc.ac.uk'),
              ),
              onLoadStop: (controller, url) async {
                if (url.toString().startsWith('https://my.nulc.ac.uk')) {
                  settings.setKey(
                    'cookies',
                    (await _cookieManager.getCookies(
                      url: WebUri('https://my.nulc.ac.uk'),
                    )).toString(),
                  );
                  settings.setBool('loggedin', true);
                  setState(() {
                    _loggedin = true;
                  });
                  _cookieManager.deleteAllCookies();
                  _loadTimetable();
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx);
                  }
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return timestamp; // Return original string if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Exam Timetable',
            onPressed: () {
              context.push('/exams');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _reloadTimetable,
          ),
          IconButton(
            icon: Icon(_update ? Icons.settings_suggest : Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _timetable == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTimetable,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_timetable == null) {
      return const Center(child: Text('No timetable data available'));
    }

    if (_timetable!.days.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _reloadTimetable();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: const Center(
              child: Text('No schedule available for this period'),
            ),
          ),
        ),
      );
    }

    // Find the index of the current day or the next available day
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    int initialIndex = 0;
    bool found = false;

    // Try to find today or the next available day
    for (int i = 0; i < 7; i++) {
      final checkWeekday =
          (currentWeekday - 1 + i) % 7; // Start from today, go forward
      final dayName = weekdayNames[checkWeekday];

      // Find the first matching day in our timetable
      for (int j = 0; j < _timetable!.days.length; j++) {
        if (_timetable!.days[j].day.toLowerCase().contains(
          dayName.toLowerCase(),
        )) {
          initialIndex = j;
          found = true;
          break;
        }
      }

      if (found) break;

      // If we've checked all days of the week, just use the first day
      if (i == 6) {
        initialIndex = 0;
      }
    }

    return DefaultTabController(
      initialIndex: initialIndex,
      length: _timetable!.days.length,
      child: Column(
        children: [
          if (_debugMode) _buildDebugControls(),
          TabBar(
            isScrollable: true,
            tabs: _timetable!.days.map((day) => Tab(text: day.day)).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: _timetable!.days.map((day) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await _reloadTimetable();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: day.lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = day.lessons[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            lesson.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${lesson.startTime} - ${lesson.endTime}${_nextLessonId == '${lesson.name}-${lesson.startTime}' ? _timeRemaining : ''}',
                              ),
                              Text('Room: ${lesson.room}'),
                              Text('Teachers: ${lesson.teachers.join(", ")}'),
                              Text(
                                'Course: ${lesson.course} (${lesson.group})',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (_timetableUpdated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Last updated: ${_formatTimestamp(_timetableUpdated)}  ${_loggedin ? '(Logged in)' : '(Not logged in)'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _scheduleNotifications() async {
    try {
      final notificationsEnabled = await settings.getNotificationsEnabled();
      if (!notificationsEnabled) {
        await _notificationService.cancelAllNotifications();
        return;
      }

      await _notificationService.cancelAllNotifications();

      if (_timetable == null) return;

      final notifyOnStart = await settings.getNotifyOnStartTime();
      final beforeEnabled = await settings.getNotifyMinutesBeforeEnabled();
      final minutesBefore = await settings.getNotifyMinutesBefore();

      final now = DateTime.now();
      int notificationId = 0;

      final weekdayMap = {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };

      for (final day in _timetable!.days) {
        final dayName = day.day.toLowerCase().split(' ').first;
        final targetWeekday = weekdayMap[dayName];
        if (targetWeekday == null) continue;

        for (final lesson in day.lessons) {
          final startTime = _parseTimeString(lesson.startTime);
          if (startTime != null) {
            var lessonDate = DateTime(now.year, now.month, now.day);
            while (lessonDate.weekday != targetWeekday) {
              lessonDate = lessonDate.add(const Duration(days: 1));
            }

            var lessonDateTime = DateTime(
              lessonDate.year,
              lessonDate.month,
              lessonDate.day,
              startTime.hour,
              startTime.minute,
            );

            if (lessonDateTime.isBefore(now)) {
              lessonDateTime = lessonDateTime.add(const Duration(days: 7));
            }

            if (notifyOnStart) {
              await _notificationService.scheduleNotification(
                notificationId++,
                lesson.name,
                'Starts now in room ${lesson.room}',
                lessonDateTime,
                repeatWeekly: true,
                type: NotificationType.lessonStart,
              );
            }

            if (beforeEnabled && minutesBefore > 0) {
              final beforeTime = lessonDateTime.subtract(
                Duration(minutes: minutesBefore),
              );
              if (beforeTime.isAfter(now)) {
                await _notificationService.scheduleNotification(
                  notificationId++,
                  lesson.name,
                  'Starts in $minutesBefore minutes in room ${lesson.room}',
                  beforeTime,
                  repeatWeekly: true,
                  type: NotificationType.minutesBefore,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }
}
