import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nscgschedule/widget_service.dart';

class DebugService {
  static final DebugService instance = DebugService._internal();

  DebugService._internal();

  final ValueStreamController<bool> _enabledController =
      ValueStreamController<bool>(false);
  final ValueStreamController<DateTime> _nowController =
      ValueStreamController<DateTime>(DateTime.now());

  Timer? _ticker;

  // Expose simple getters
  bool get enabled => _enabledController.value;
  DateTime get now => _nowController.value;

  // ValueListenable-like access
  ValueStreamController<bool> get enabledController => _enabledController;
  ValueStreamController<DateTime> get nowController => _nowController;

  void setEnabled(bool v) {
    _enabledController.value = v;
    if (v) {
      _startTicker();
    } else {
      _stopTicker();
    }
    _saveToPrefs();
    _refreshWidgets();
  }

  void setNow(DateTime dt) {
    _nowController.value = dt;
    _saveToPrefs();
    _refreshWidgets();
  }

  void advance(Duration d) {
    _nowController.value = _nowController.value.add(d);
    _saveToPrefs();
    _refreshWidgets();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _nowController.value = _nowController.value.add(
        const Duration(seconds: 1),
      );
      // Update widgets every minute
      if (_nowController.value.second == 0) {
        _refreshWidgets();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Save debug state to SharedPreferences for widgets to access
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_enabled', _enabledController.value);
    await prefs.setInt(
      'debug_time_millis',
      _nowController.value.millisecondsSinceEpoch,
    );
    // Store the real time when debug time was set so widgets can calculate elapsed time
    await prefs.setInt(
      'debug_set_real_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Refresh widgets to reflect debug time changes
  void _refreshWidgets() {
    WidgetService.instance.updateAllWidgets();
  }

  /// Load debug state from SharedPreferences
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('debug_enabled') ?? false;
      final timeMillis = prefs.getInt('debug_time_millis');

      _enabledController.value = enabled;
      if (timeMillis != null) {
        _nowController.value = DateTime.fromMillisecondsSinceEpoch(timeMillis);
      }

      if (enabled) {
        _startTicker();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void dispose() {
    _stopTicker();
  }
}

/// Minimal value holder that mirrors ValueNotifier but exposes `value`
class ValueStreamController<T> {
  T _value;
  final StreamController<T> _controller;
  ValueStreamController(this._value)
    : _controller = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    try {
      _controller.add(v);
    } catch (_) {}
  }

  Stream<T> get stream => _controller.stream;
  void dispose() => _controller.close();
}
