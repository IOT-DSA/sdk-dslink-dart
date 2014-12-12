part of dslink.api;

abstract class Trend {
  Interval get interval;
  TimeRange get timeRange;
  ValueType get type;
  bool hasNext();
  Value next();
}

class Trends {
  static Trend create(ValueType type, Iterable<Value> values) {
    var trend = new ValueTrend(DSContext.getTimeRange(), type, values);
    return tryRollup(trend, DSContext.getInterval(), DSContext.getRollupType());
  }
  
  static Trend tryRollup(Trend his, Interval interval, RollupType roll) {
    if (interval == null || interval == Interval.NONE) {
      return his;
    }
    
    var ivl = his.interval;
    
    if (ivl == interval) {
      return his;
    }
    
    if (roll == null) {
      roll = RollupType.FIRST;
    }
    
    print("Making Rollup");
    
    return new RollupTrend(roll, interval, his);
  }
}

class ValueTrend extends Trend {
  final Interval interval;
  final TimeRange timeRange;
  final ValueType type;

  List<Value> _values;
  List<Value> get values => _values;

  ValueTrend(TimeRange timeRange, this.type, Iterable<Value> inputs, {Interval interval})
      : this.interval = interval != null ? interval : interval = Interval.NONE,
        this.timeRange = timeRange {
    _values = _findActuals(inputs.toList());
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
      
      if (interval != null) {
        var difference = timestamp - _lastTimestamp;
        
        if (difference < interval.millis) {
          continue;
        }
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
      return t.isAfter(timeRange.from) || t.isAtSameMomentAs(t) && t.isBefore(timeRange.from) || t.isAtSameMomentAs(timeRange.to);
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

class RollupTrend extends Trend {
  final RollupType roll;
  final Trend trend;
  final Interval rollupInterval;
  
  RollupTrend(this.roll, this.rollupInterval, this.trend) {
    _loadCache();
  }
  
  void _loadCache() {
    while (trend.hasNext()) {
      _cache.add(trend.next());
    }
    _lastEnd = timeRange.from.millisecondsSinceEpoch;
  }
  
  @override
  bool hasNext() {
    return _lastEnd < timeRange.to.millisecondsSinceEpoch;
  }
  
  int _lastEnd;

  @override
  Interval get interval => rollupInterval;

  @override
  Value next() {
    return rollupBetween(_lastEnd, rollupInterval.next(_lastEnd));
  }
  
  Value rollupBetween(int start, int end) {
    var vals = _cache.where((it) {
      var ts = it.timestamp;
      var m = ts.millisecondsSinceEpoch;
      return m >= start || m <= end;
    }).toList();
    _lastEnd = end;
    return roll.create().combine(vals);
  }
  
  List<Value> _cache = [];
  
  Value _current;
  
  @override
  TimeRange get timeRange => trend.timeRange;

  @override
  ValueType get type => trend.type;
}

class Interval {
  static const Interval ONE_SECOND = const Interval._(1000);
  static const Interval NONE = const Interval._(0);
  static const Interval ONE_INTERVAL = const Interval._(0);
  static const Interval FIVE_SECONDS = const Interval._(5 * 1000);
  static const Interval TEN_SECONDS = const Interval._(10 * 1000);
  static const Interval FIFTEEN_SECONDS = const Interval._(15 * 1000);
  static const Interval THIRTY_SECONDS = const Interval._(30 * (60 * 1000));
  static const Interval ONE_MINUTE = const Interval._(60 * 1000);
  static const Interval FIVE_MINUTES = const Interval._(5 * (60 * 1000));
  static const Interval TEN_MINUTES = const Interval._(10 * (60 * 1000));
  static const Interval FIFTEEN_MINUTES = const Interval._(15 * (60 * 1000));
  static const Interval TWENTY_MINUTES = const Interval._(20 * (60 * 1000));
  static const Interval THIRTY_MINUTES = const Interval._(30 * (60 * 1000));
  static const Interval ONE_HOUR = const Interval._(60 * (60 * 1000));
  static const Interval TWO_HOURS = const Interval._(120 * (60 * 1000));
  static const Interval THREE_HOURS = const Interval._(180 * (60 * 1000));
  static const Interval FOUR_HOURS = const Interval._(240 * (60 * 1000));
  static const Interval SIX_HOURS = const Interval._(360 * (60 * 1000));
  static const Interval TWELVE_HOURS = const Interval._(720 * (60 * 1000));
  static const Interval ONE_DAY = const Interval._(1440 * (60 * 1000));
  static const Interval ONE_WEEK = const Interval._(10080 * (60 * 1000));
  static const Interval ONE_MONTH = const Interval._(40320 * (60 * 1000));
  static const Interval THREE_MONTHS = const Interval._(7257600000);
  static const Interval ONE_YEAR = const Interval._(29030400000);
  static const Interval FIVE_YEARS = const Interval._(145152000000);
  static const Interval ONE_DECADE = const Interval._(290304000000);
  static const Interval ONE_CENTURY = const Interval._(29030400000 * 100);

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
    if (MAPPING.containsKey(name)) {
      return MAPPING[name];
    } else {
      return NONE;
    }
  }

  static final Map<String, Interval> MAPPING = () {
    var intervals = new _IntervalMapper();
    intervals.put("default", NONE);
    intervals.put("none", NONE);
    intervals.put("oneSecond", ONE_SECOND);
    intervals.put("fiveSeconds", FIVE_SECONDS);
    intervals.put("tenSeconds", TEN_SECONDS);
    intervals.put("fifteenSeconds", FIFTEEN_SECONDS);
    intervals.put("thirtySeconds", THIRTY_SECONDS);
    intervals.put("oneMinute", ONE_MINUTE);
    intervals.put("fiveMinutes", FIVE_MINUTES);
    intervals.put("tenMinutes", TEN_MINUTES);
    intervals.put("fifteenMinutes", FIFTEEN_MINUTES);
    intervals.put("twentyMinutes", TWENTY_MINUTES);
    intervals.put("thirtyMinutes", THIRTY_MINUTES);
    intervals.put("oneHour", ONE_HOUR);
    intervals.put("twoHours", TWO_HOURS);
    intervals.put("threeHours", THREE_HOURS);
    intervals.put("fourHours", FOUR_HOURS);
    intervals.put("sixHours", SIX_HOURS);
    intervals.put("twelveHours", TWELVE_HOURS);
    intervals.put("oneDay", ONE_DAY);
    intervals.put("oneWeek", ONE_WEEK);
    intervals.put("oneMonth", ONE_MONTH);
    intervals.put("threeMonths", THREE_MONTHS);
    intervals.put("oneYear", ONE_YEAR);
    intervals.put("fiveYears", FIVE_YEARS);
    intervals.put("oneDecade", ONE_DECADE);
    intervals.put("oneCentury", ONE_CENTURY);
    intervals.put("oneInterval", ONE_INTERVAL);
    intervals.put("hour", ONE_HOUR);
    intervals.put("day", ONE_DAY);
    intervals.put("week", ONE_WEEK);
    intervals.put("month", ONE_MONTH);
    intervals.put("year", ONE_YEAR);
    return intervals.map;
  }();

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

class _IntervalMapper {
  final Map map ={};

  _IntervalMapper();

  void put(String name, Interval interval) {
    map[name] = interval;
  }
}
