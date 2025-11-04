import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nscgschedule/models/exam_models.dart';
import 'package:nscgschedule/requests.dart';
import 'package:nscgschedule/settings.dart';

class ExamTimetableScreen extends StatefulWidget {
  const ExamTimetableScreen({super.key});

  @override
  State<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends State<ExamTimetableScreen> {
  final CookieManager _cookieManager = CookieManager.instance();
  final NSCGRequests _requests = NSCGRequests.instance;
  bool _isLoading = true;
  String _error = '';
  ExamTimetable? _examTimetable;
  String _examTimetableUpdated = '';
  bool _loggedin = false;
  StreamSubscription<void>? _resub;

  @override
  void initState() {
    super.initState();
    init(); // Load from local storage first
    _loadExamTimetable(); // Then try to update from server

    _resub = _requests.loggedinController.stream.listen((value) {
      setState(() {
        _loggedin = value;
      });
    });
  }

  @override
  void dispose() {
    _resub?.cancel();
    super.dispose();
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
    final examTimetableData = await settings.getMap('examTimetable');
    final examTimetableUpdated = await settings.getKey('examTimetableUpdated');
    final loggedin = await settings.getBool('loggedin');

    if (examTimetableData.isNotEmpty) {
      try {
        // Convert the map and all nested maps to ensure they have the correct type
        final typedData = _convertToTypedMap(examTimetableData);
        final examTimetable = ExamTimetable.fromJson(typedData);
        if (mounted) {
          setState(() {
            _examTimetable = examTimetable;
            _examTimetableUpdated = examTimetableUpdated;
            _error = '';
            _loggedin = loggedin;
            _isLoading = false;
          });
        }
      } catch (e, stacktrace) {
        debugPrint('Error loading exam timetable: $e');
        debugPrint('Stacktrace: $stacktrace');
        await settings.setMap('examTimetable', {});
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadExamTimetable() async {
    if (!mounted) return;
    if (_error.isNotEmpty) {
      setState(() {
        _error = '';
      });
    }

    try {
      final examTimetable = await _requests.getExamTimetable();
      if (examTimetable != null) {
        final examTimetableUpdated = await settings.getKey(
          'examTimetableUpdated',
        );
        final loggedin = await settings.getBool('loggedin');

        if (mounted) {
          setState(() {
            _examTimetable = examTimetable;
            _examTimetableUpdated = examTimetableUpdated;
            _loggedin = loggedin;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching exam timetable: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadExamTimetable() async {
    if (_loggedin) {
      setState(() {
        _isLoading = true;
      });
      await _loadExamTimetable();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Required'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://my.nulc.ac.uk'),
              ),
              onLoadStop: (controller, url) async {
                if (!url.toString().contains('authToken')) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cannot Login'),
                      content: const Text(
                        'This error is commonly caused by being connected to college wifi which prevents this page from redirecting to the login screen.',
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
                ;
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
                  _loadExamTimetable();
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
      return timestamp;
    }
  }

  String _formatExamDate(String date) {
    try {
      // Parse date format: "04-11-2025"
      final parts = date.split('-');
      if (parts.length == 3) {
        final dateTime = DateTime(
          int.parse(parts[2]), // year
          int.parse(parts[1]), // month
          int.parse(parts[0]), // day
        );
        return DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
      }
    } catch (e) {
      return date;
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _reloadExamTimetable,
          ),
          if (_examTimetable?.studentInfo != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                context.push('/exams/details');
              },
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _examTimetable == null) {
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
              onPressed: _reloadExamTimetable,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_examTimetable == null) {
      return const Center(child: Text('No exam timetable data available'));
    }

    if (!_examTimetable!.hasExams) {
      return RefreshIndicator(
        onRefresh: () async {
          await _reloadExamTimetable();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No exams found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('You currently have no scheduled exams.'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_examTimetable!.warningMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _examTimetable!.warningMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _reloadExamTimetable();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _examTimetable!.exams.length,
              itemBuilder: (context, index) {
                final exam = _examTimetable!.exams[index];

                // Group header for date if this is a new date
                bool showDateHeader =
                    index == 0 ||
                    _examTimetable!.exams[index - 1].date != exam.date;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      if (index != 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          _formatExamDate(exam.date),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                    Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              exam.startTime,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        title: Text(
                          exam.subjectDescription,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${exam.boardCode} - ${exam.paper}'),
                            Text('${exam.startTime} - ${exam.finishTime}'),
                            Text('Room: ${exam.examRoom}'),
                            Text('Seat: ${exam.seatNumber}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showExamDetails(context, exam);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (_examTimetableUpdated.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Last updated: ${_formatTimestamp(_examTimetableUpdated)}  ${_loggedin ? '(Logged in)' : '(Not logged in)'}',
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
    );
  }

  void _showExamDetails(BuildContext context, Exam exam) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      exam.subjectDescription,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow(context, 'Date', _formatExamDate(exam.date)),
              _buildDetailRow(context, 'Start Time', exam.startTime),
              _buildDetailRow(context, 'Finish Time', exam.finishTime),
              _buildDetailRow(context, 'Board Code', exam.boardCode),
              _buildDetailRow(context, 'Paper', exam.paper),
              const SizedBox(height: 16),
              Text(
                'Location',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(context, 'Pre Room', exam.preRoom),
              _buildDetailRow(context, 'Exam Room', exam.examRoom),
              _buildDetailRow(context, 'Seat Number', exam.seatNumber),
              if (exam.additional.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      exam.additional,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
