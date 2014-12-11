import "dart:io";

import "package:dslink/api.dart";

void main() {
  var values = [];
  var start = new DateTime.now();
  sleep(new Duration(seconds: 2));
  for (var i = 1; i <= 10; i++) {
    values.add(Value.of(i));
    if (i == 1) {
      print("First: ${values.first}");
    }
    sleep(new Duration(milliseconds: 500));
  }
  values.shuffle();
  var end = new DateTime.now();
  var trend = new ValueTrend(new TimeRange(start, end), ValueType.STRING, values, interval: Interval.ONE_SECOND);
  print("Starting At: ${start}");
  print("Ending At: ${end}");
  while (trend.hasNext()) {
    var value = trend.next();
    print(value.toString() + " (timestamp: ${value.timestamp})");
  }
}