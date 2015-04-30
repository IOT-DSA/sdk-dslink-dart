part of dslink.common;

class ValueUpdate {
  static final String TIME_ZONE = () {
    int timeZoneOffset = (new DateTime.now()).timeZoneOffset.inMinutes;
    String s = '+';
    if (timeZoneOffset < 0) {
      timeZoneOffset = -timeZoneOffset;
      s = '-';
    }
    int hh = timeZoneOffset ~/ 60;
    int mm = timeZoneOffset % 60;
    return "$s${hh<10?'0':''}$hh:${mm<10?'0':''}$mm";
  }();

  static String getTs() {
    return '${(new DateTime.now()).toIso8601String()}$TIME_ZONE';
  }

  Object value;
  String ts;
  String status;
  int count;
  num sum = 0,
      min,
      max;

  ValueUpdate(this.value, {this.ts, Map meta, this.status, this.count: 1,
    this.sum: double.NAN, this.min: double.NAN, this.max: double.NAN}) {
    if (ts == null) {
      ts = getTs();
    }

    if (meta != null) {
      if (meta['count'] is int) {
        count = meta['count'];
      } else if (value == null) {
        count = 0;
      }
      if (meta['status'] is String) {
        status = meta['status'];
      }
      if (meta['sum'] is num) {
        sum = meta['sum'];
      }
      if (meta['max'] is num) {
        max = meta['max'];
      }
      if (meta['min'] is num) {
        min = meta['min'];
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
    if (!oldUpdate.sum.isNaN) {
      sum += oldUpdate.sum;
    }
    if (!newUpdate.sum.isNaN) {
      sum += newUpdate.sum;
    }
    min = oldUpdate.min;
    if (min.isNaN || newUpdate.min < min) {
      min = newUpdate.min;
    }
    max = oldUpdate.min;
    if (max.isNaN || newUpdate.max > max) {
      max = newUpdate.max;
    }
  }
}
