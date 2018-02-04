part of dslink.common;

typedef T ValueUpdateCallback<T>(ValueUpdate update);
typedef T ValueCallback<T>(value);

/// Represents an update to a value subscription.
class ValueUpdate {
  /// DSA formatted timezone.
  static final String TIME_ZONE = () {
    int timeZoneOffset = (new DateTime.now()).timeZoneOffset.inMinutes;
    String s = "+";
    if (timeZoneOffset < 0) {
      timeZoneOffset = -timeZoneOffset;
      s = "-";
    }
    int hh = timeZoneOffset ~/ 60;
    int mm = timeZoneOffset % 60;
    return "$s${hh < 10 ? '0' : ''}$hh:${mm < 10 ? "0" : ''}$mm";
  }();

  static String _lastTsStr;
  static int _lastTs = 0;
  /// Generates a timestamp in the proper DSA format.
  static String getTs() {
    DateTime d = new DateTime.now();
    if (d.millisecondsSinceEpoch == _lastTs) {
      return _lastTsStr;
    }
    _lastTs = d.millisecondsSinceEpoch;
    _lastTsStr = "${d.toIso8601String()}$TIME_ZONE";
    return _lastTsStr;
  }

  /// The id of the ack we are waiting for.
  int waitingAck = -1;

  /// The value for this update.
  Object value;

  /// A [String] representation of the timestamp for this value.
  String ts;

  DateTime _timestamp;

  /// Gets a [DateTime] representation of the timestamp for this value.
  DateTime get timestamp {
    if (_timestamp == null) {
      _timestamp = DateTime.parse(ts);
    }
    return _timestamp;
  }

  /// The current status of this value.
  String status;

  /// How many updates have happened since the last response.
  int count;

  /// The sum value if one or more numeric values has been skipped.
  num sum;

  /// The minimum value if one or more numeric values has been skipped.
  num min;

  /// The maximum value if one or more numeric values has been skipped.
  num max;

  /// The timestamp for when this value update was created.
  DateTime created;

  ValueUpdate(this.value,
      {this.ts,
      Map meta,
      this.status,
      this.count: 1,
      this.sum: double.NAN,
      this.min: double.NAN,
      this.max: double.NAN}) {
    if (ts == null) {
      ts = getTs();
    }

    created = new DateTime.now();

    if (meta != null) {
      if (meta["count"] is int) {
        count = meta["count"];
      } else if (value == null) {
        count = 0;
      }

      if (meta["status"] is String) {
        status = meta["status"];
      }

      if (meta["sum"] is num) {
        sum = meta["sum"];
      }

      if (meta["max"] is num) {
        max = meta["max"];
      }

      if (meta["min"] is num) {
        min = meta["min"];
      }
    }

    if (value is num && count == 1) {
      if (sum != sum) sum = value;
      if (max != max) max = value;
      if (min != min) min = value;
    }
  }

  ValueUpdate.merge(ValueUpdate oldUpdate, ValueUpdate newUpdate) {
    value = newUpdate.value;
    ts = newUpdate.ts;
    status = newUpdate.status;
    count = oldUpdate.count + newUpdate.count;
    sum = oldUpdate.sum;
    if (!newUpdate.sum.isNaN) {
      if (sum == sum) {
        sum = newUpdate.sum;
      } else {
        sum += newUpdate.sum;
      }
    }
    min = oldUpdate.min;
    if (min.isNaN || newUpdate.min < min) {
      min = newUpdate.min;
    }
    max = oldUpdate.min;
    if (max.isNaN || newUpdate.max > max) {
      max = newUpdate.max;
    }

    created = newUpdate.created;
  }

  Duration _latency;

  /// Calculates the latency
  Duration get latency {
    if (_latency == null) {
      _latency = created.difference(timestamp);
    }
    return _latency;
  }

  /// merge the new update into existing instance
  void mergeAdd(ValueUpdate newUpdate) {
    value = newUpdate.value;
    ts = newUpdate.ts;
    status = newUpdate.status;
    count += newUpdate.count;

    if (!newUpdate.sum.isNaN) {
      if (sum == sum) {
        sum += newUpdate.sum;
      } else {
        sum = newUpdate.sum;
      }
    }
    if (min != min || newUpdate.min < min) {
      min = newUpdate.min;
    }
    if (max != max || newUpdate.max > max) {
      max = newUpdate.max;
    }
  }

  bool equals(ValueUpdate other) {
    if (value is Map) {
      // assume Map is same if it's generated at same timestamp
      if (other.value is! Map) {
        return false;
      }
    } else if (value is List) {
      // assume List is same if it's generated at same timestamp
      if (other.value is! List) {
        return false;
      }
    } else if (value != other.value) {
      return false;
    }

    if (other.ts != ts || other.count != count) {
      return false;
    }

    if (count == 1) {
      return true;
    }
    return other.sum == sum && other.min == min && other.max == max;
  }

  /// Generates a map representation of this value update.
  Map toMap() {
    Map m = {"ts": ts, "value": value};
    if (count == 0) {
      m["count"] = 0;
    } else if (count > 1) {
      m["count"] = count;
      if (sum.isFinite) {
        m["sum"] = sum;
      }
      if (max.isFinite) {
        m["max"] = max;
      }
      if (min.isFinite) {
        m["min"] = min;
      }
    }
    return m;
  }

  /// could be the value or the key stored by ValueStorage
  Object storedData;

  bool _cloned = false;
  ValueUpdate cloneForAckQueue(){
    if (!_cloned) {
      _cloned = true;
      return this;
    }

    return new ValueUpdate(
      value,
      ts: ts,
      status: status,
      count: count,
      sum: sum,
      min: min,
      max: max
    );
  }
}
