part of dslink.api;

abstract class Trend {
  Interval get interval;
  TimeRange get timeRange;
  ValueType get type;
  bool hasNext();
  Value next();
}

class ValueTrend extends Trend {
  final Interval interval;
  final TimeRange timeRange;
  final ValueType type;
  
  List<Value> _values;
  List<Value> get values => _values;
  
  ValueTrend(TimeRange timeRange, this.type, List<Value> inputs, {Interval interval}) :
    this.interval = interval != null ? interval : interval = Interval.NONE,
    this.timeRange = timeRange
  {
    _values = _findActuals(inputs);
  }
  
  @override
  bool hasNext() {
    _current = _next();
    return _current != null;
  }
  
  Value _current;
  
  Value _next() {
    if (_iterator == null) {
      reset();
    }
    
    int timestamp;
    Value ret;
    while (_iterator.moveNext()) {
      ret = _iterator.current;
      timestamp = ret.timestamp.millisecondsSinceEpoch;
      
      if ((_lastTimestamp < 0) && (timestamp < _lastTimestamp)) {
        continue;
      }
      _lastTimestamp = timestamp;
      return ret;
    }
    return null;
  }
  
  int _lastTimestamp = -1;
  
  List<Value> _findActuals(List<Value> inputs) {
    var vals = inputs.where((value) {
      var t = value.timestamp;
      return t.isAfter(timeRange.from) ||
             t.isAtSameMomentAs(t) &&
             t.isBefore(timeRange.from) ||
             t.isAtSameMomentAs(timeRange.to);
    }).toList();
    vals.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return vals;
  }
  
  Iterator _iterator;
  
  @override
  Value next() {
    return _current;
  }
  
  void reset() {
    _iterator = values.iterator;
  }
}

class Interval {
  static const Interval ONE_SECOND = const Interval._(1000);
  static const Interval ONE_HOUR = const Interval._(3600000);
  static const Interval NONE = const Interval._(0);
  static const Interval ONE_INTERVAL = const Interval._(-1);
  
  final int millis;
  
  const Interval._(this.millis);
  
  static Interval determineBest(int start, int end) {
    var diff = end - start;
    if (diff > ONE_HOUR.millis) {
      return ONE_SECOND;
    }
    return NONE;
  }
  
  static Interval forName(String name) {
    switch (name) {
      case "default":
        return NONE;
      default:
        return NONE;
    }
  }
  
  int count(int start, int end) {
    var delta = end - start;
    if (this == NONE) {
      return 0;
    } else if (this == ONE_INTERVAL) {
      return 1;
    } else {
      return delta ~/ millis;
    }
  }
  
  int next(int ts) {
    return ts + millis;
  }
}

class TimeRange {
  final DateTime from;
  final DateTime to;
  
  TimeRange(this.from, this.to);
}