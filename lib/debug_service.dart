import 'dart:async';

class DebugService {
  static final DebugService instance = DebugService._internal();

  DebugService._internal();

  final ValueStreamController<bool> _enabledController =
      ValueStreamController<bool>(false);
  final ValueStreamController<DateTime> _nowController =
      ValueStreamController<DateTime>(DateTime.now());

  // Expose simple getters
  bool get enabled => _enabledController.value;
  DateTime get now => _nowController.value;

  // ValueListenable-like access
  ValueStreamController<bool> get enabledController => _enabledController;
  ValueStreamController<DateTime> get nowController => _nowController;

  void setEnabled(bool v) {
    _enabledController.value = v;
  }

  void setNow(DateTime dt) {
    _nowController.value = dt;
  }

  void advance(Duration d) {
    _nowController.value = _nowController.value.add(d);
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
