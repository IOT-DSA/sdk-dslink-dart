part of dslink.utils;


class TimerFunctions extends LinkedListEntry{
  final int ts;
  List<Function> _functions = new List<Function>();
  TimerFunctions(this.ts);
  
  void add(Function foo){
    if (!_functions.contains(foo)){
      _functions.add(foo);
    }
  }
  void remove(Function foo) {
    _functions.remove(foo);
  }
}

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
  /// call the function and remove it from the pending listh
  static void callNow(Function callback) {
    if (_callbacks.contains(callback)) {
      _callbacks.remove(callback);
    }
    callback();
  }

  static void cancel(Function callback) {
    if (_callbacks.contains(callback)) {
      _callbacks.remove(callback);
    }
  }
  
  
  static LinkedList<TimerFunctions> _pendingTimer = new LinkedList<TimerFunctions>();
  static Map<int, TimerFunctions> _pendingTimerMap = new Map<int, TimerFunctions>();
  static Map<Function, TimerFunctions> _functionsMap = new Map<Function, TimerFunctions>();
  static TimerFunctions _getTimerFunctions(int time){
    if (_pendingTimerMap.containsKey(time)){
      return _pendingTimerMap[time];
    }
    TimerFunctions tf = new TimerFunctions(time);
    _pendingTimerMap[time] = tf;
    TimerFunctions it;
    if (_pendingTimer.isNotEmpty){
      it = _pendingTimer.first;
    } 
    while (it != null) {
      if (it.ts > time) {
        it.insertBefore(tf);
        break;
      } else if (it.next != _pendingTimer){
        it = it.next;
      } else {
        it = null;
      }
    }
    if (it == null) {
      _pendingTimer.add(tf);
    }
    if (!_pending) {
      _startTimer();
    }
    return tf;
  }
  static TimerFunctions _removeTimerFunctions(int time) {
    if (_pendingTimer.isNotEmpty && _pendingTimer.first.ts <= time){
      TimerFunctions rslt = _pendingTimer.first;
      _pendingTimerMap.remove(rslt.ts);
      rslt.unlink();
      for (Function fun in rslt._functions){
        _functionsMap.remove(fun);
        fun();
      }
      return rslt;
    }
    return null;
  }
  
  static int _lastTimeRun = -1;
  /// do nothng if the callback is already in the list and will get called after 0 ~ N ms
  static void timerOnceBefore(Function callback, int ms) {
    int desiredTime = (((new DateTime.now()).millisecondsSinceEpoch + ms)/50).ceil();
    if (_functionsMap.containsKey(callback)) {
      TimerFunctions existTf = _functionsMap[callback];
      if (existTf.ts <= desiredTime) {
        return;
      } else {
        existTf.remove(callback);
      }
    }
    if (desiredTime <= _lastTimeRun){
      callLaterOnce(callback);
      return;
    }
    TimerFunctions tf = _getTimerFunctions(desiredTime);
    tf.add(callback);
    _functionsMap[callback] = tf;
  }
  /// do nothng if the callback is already in the list and will get called after N or more ms
  static void timerOnceAfter(Function callback, int ms) {
    int desiredTime = (((new DateTime.now()).millisecondsSinceEpoch + ms)/50).ceil();
    if (_functionsMap.containsKey(callback)) {
      TimerFunctions existTf = _functionsMap[callback];
      if (existTf.ts >= desiredTime) {
        return;
      } else {
        existTf.remove(callback);
      }
    }
    if (desiredTime <= _lastTimeRun){
      callLaterOnce(callback);
      return;
    }
    TimerFunctions tf = _getTimerFunctions(desiredTime);
    tf.add(callback);
    _functionsMap[callback] = tf;
  }
  
  /// do nothng if the callback is already in the list and will get called after M to N ms
  static void timerOnceBetween(Function callback, int after, int before) {
    int desiredTime0 = (((new DateTime.now()).millisecondsSinceEpoch + after)/50).ceil();
    int desiredTime1 = (((new DateTime.now()).millisecondsSinceEpoch + before)/50).ceil();
    if (_functionsMap.containsKey(callback)) {
      TimerFunctions existTf = _functionsMap[callback];
      if (existTf.ts >= desiredTime0 && existTf.ts <= desiredTime1) {
        return;
      } else {
        existTf.remove(callback);
      }
    }
    if (desiredTime1 <= _lastTimeRun){
      callLaterOnce(callback);
      return;
    }
    TimerFunctions tf = _getTimerFunctions(desiredTime1);
    tf.add(callback);
    _functionsMap[callback] = tf;
  }
  
  static void timerCancel(Function callback) {
    if (_functionsMap.containsKey(callback)) {
      // TODO what if timerCancel is called from another timer of group?
      TimerFunctions existTf = _functionsMap[callback];
      existTf.remove(callback);
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
    
    _lastTimeRun = ((new DateTime.now()).millisecondsSinceEpoch/50).floor();
    while(_removeTimerFunctions(_lastTimeRun) != null){
      // empty loop
    }
    
    _looping = false;
    if (_mergeCycle) {
      _mergeCycle = false;
      _dsLoop();
    }
    
    if (_pendingTimer.isNotEmpty) {
      if (!_pending) {
        _startTimer();
      }
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
