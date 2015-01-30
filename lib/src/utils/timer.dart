part of dslink.utils;

class DsTimer {
  static int millisecondsSinceEpoch() {
    return new DateTime.now().millisecondsSinceEpoch;
  }
  
  static Future waitAndRun(Duration time, action()) {
    return new Future.delayed(time, action);
  }
  
  // TODO does it need to use another hashset for quick search?
  static List<Function> _callbacks = [];
  //static Map<Function, int> _timerCallbacks = new Map<Function, int>();

  static void _startTimer() {
    Timer.run(_dsLoop);
    _pending = true;
  }

  static void callLater(Function callback) {
    if (!_pending) {
      _startTimer();
    }
    _callbacks.add(callback);
  }

  /// multiple calls to callLaterOnce will only run function once
  static void callLaterOnce(Function callback) {
    if (!_callbacks.contains(callback)) {
      if (!_pending) {
        _startTimer();
      }
      _callbacks.add(callback);
    }
  }
  /// call the function and remove it from the pending list
  static void callNow(Function callback) {
    if (_callbacks.contains(callback)) {
      _callbacks.remove(callback);
    }
    callback();
  }
//  static void callOnceAfter(Function callback, int ms) {
//    if (!_callbacks.contains(callback)) {
//      if (!_pending) {
//        _startTimer();
//      }
//      _callbacks.add(callback);
//    }
//  }
  static void cancel(Function callback) {
    if (_callbacks.contains(callback)) {
      _callbacks.remove(callback);
    }
  }
  static bool _pending = false;
  static bool _looping = false;
  static bool _mergeCycle = false;
  static void _dsLoop() {
    _pending = false;
    _looping = true;

    List<Function> runnings = _callbacks;

    _callbacks = [];

    runnings.forEach((Function f) {
      f();
    });

    _looping = false;
    if (_mergeCycle) {
      _mergeCycle = false;
      _dsLoop();
    }
  }

  // don't wait for the timer, run it now
  static void runNow() {
    if (_looping) {
      _mergeCycle = true;
    } else {
      _dsLoop();
    }
  }
}
