/// Common Utilities for DSA Components
library dslink.utils;

import "dart:async";
import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';

import "dart:math";

import "package:logging/logging.dart";

part "src/utils/better_iterator.dart";
part "src/utils/base64.dart";
part "src/utils/timer.dart";
part "src/utils/stream_controller.dart";
part "src/utils/json.dart";
part "src/utils/dslink_json.dart";
part "src/utils/list.dart";

/// The DSA Version
const String DSA_VERSION = '1.0.3';

Logger _logger;

bool _DEBUG_MODE;

/// Gets if we are in checked mode.
bool get DEBUG_MODE {
  if (_DEBUG_MODE != null) {
    return _DEBUG_MODE;
  }

  try {
    assert(false);
    _DEBUG_MODE = false;
  } catch (e) {
    _DEBUG_MODE = true;
  }
  return _DEBUG_MODE;
}

/// Fetches the logger instance.
Logger get logger {
  if (_logger != null) {
    return _logger;
  }

  hierarchicalLoggingEnabled = true;
  _logger = new Logger("DSA");

  _logger.onRecord.listen((record) {
    print("[DSA][${record.level.name}] ${record.message}");
    if (record.error != null) {
      print(record.error);
    }

    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
  });

  return _logger;
}

/// Updates the log level to the level specified [name].
void updateLogLevel(String name) {
  name = name.trim().toUpperCase();

  if (name == "debug") {
    name = "ALL";
  }

  Map<String, Level> levels = {};
  for (var l in Level.LEVELS) {
    levels[l.name] = l;
  }

  var l = levels[name];

  if (l != null) {
    logger.level = l;
  }
}

class Interval {
  static final Interval ONE_MILLISECOND = new Interval.forMilliseconds(1);
  static final Interval TWO_MILLISECONDS = new Interval.forMilliseconds(2);
  static final Interval FOUR_MILLISECONDS = new Interval.forMilliseconds(4);
  static final Interval EIGHT_MILLISECONDS = new Interval.forMilliseconds(8);
  static final Interval SIXTEEN_MILLISECONDS = new Interval.forMilliseconds(16);
  static final Interval THIRTY_MILLISECONDS = new Interval.forMilliseconds(30);
  static final Interval FIFTY_MILLISECONDS = new Interval.forMilliseconds(50);
  static final Interval ONE_HUNDRED_MILLISECONDS =
      new Interval.forMilliseconds(100);
  static final Interval TWO_HUNDRED_MILLISECONDS =
      new Interval.forMilliseconds(200);
  static final Interval THREE_HUNDRED_MILLISECONDS =
      new Interval.forMilliseconds(300);
  static final Interval QUARTER_SECOND = new Interval.forMilliseconds(250);
  static final Interval HALF_SECOND = new Interval.forMilliseconds(500);
  static final Interval ONE_SECOND = new Interval.forSeconds(1);
  static final Interval TWO_SECONDS = new Interval.forSeconds(2);
  static final Interval THREE_SECONDS = new Interval.forSeconds(3);
  static final Interval FOUR_SECONDS = new Interval.forSeconds(4);
  static final Interval FIVE_SECONDS = new Interval.forSeconds(5);
  static final Interval ONE_MINUTE = new Interval.forMinutes(1);

  final Duration duration;

  const Interval(this.duration);

  Interval.forMilliseconds(int ms) : this(new Duration(milliseconds: ms));
  Interval.forSeconds(int seconds) : this(new Duration(seconds: seconds));
  Interval.forMinutes(int minutes) : this(new Duration(minutes: minutes));
  Interval.forHours(int hours) : this(new Duration(hours: hours));

  int get inMilliseconds => duration.inMilliseconds;
}

/// Schedule Tasks
class Scheduler {
  static Timer get currentTimer => Zone.current["dslink.scheduler.timer"];

  static void cancelCurrentTimer() {
    currentTimer.cancel();
  }

  static Timer every(interval, action()) {
    Duration duration;

    if (interval is Duration) {
      duration = interval;
    } else if (interval is int) {
      duration = new Duration(milliseconds: interval);
    } else if (interval is Interval) {
      duration = interval.duration;
    } else {
      throw new Exception("Invalid Interval: ${interval}");
    }

    return new Timer.periodic(duration, (timer) async {
      await runZoned(action, zoneValues: {"dslink.scheduler.timer": timer});
    });
  }

  static Future repeat(int times, action()) async {
    for (var i = 1; i <= times; i++) {
      await action();
    }
  }

  static Future tick(int times, Interval interval, action()) async {
    for (var i = 1; i <= times; i++) {
      await new Future.delayed(
          new Duration(milliseconds: interval.inMilliseconds));
      await action();
    }
  }

  static void runLater(action()) {
    Timer.run(action);
  }

  static Future later(action()) {
    return new Future(action);
  }

  static Future after(Duration duration, action()) {
    return new Future.delayed(duration, action);
  }

  static Timer runAfter(Duration duration, action()) {
    return new Timer(duration, action);
  }
}

String buildEnumType(Iterable<String> values) => "enum[${values.join(',')}]";

List<String> parseEnumType(String type) {
  if (!type.startsWith("enum[") || !type.endsWith("]")) {
    throw new FormatException("Invalid Enum Type");
  }
  return type
      .substring(4, type.length - 1)
      .split(",")
      .map((it) => it.trim())
      .toList();
}

List<Map<String, dynamic>> buildActionIO(Map<String, String> types) {
  return types.keys.map((it) => {"name": it, "type": types[it]}).toList();
}

Random _random = new Random();

String generateBasicId({int length: 30}) {
  var r = new Random(_random.nextInt(5000));
  var buffer = new StringBuffer();
  for (int i = 1; i <= length; i++) {
    var n = r.nextInt(50);
    if (n >= 0 && n <= 32) {
      String letter = alphabet[r.nextInt(alphabet.length)];
      buffer.write(r.nextBool() ? letter.toLowerCase() : letter);
    } else if (n > 32 && n <= 43) {
      buffer.write(numbers[r.nextInt(numbers.length)]);
    } else if (n > 43) {
      buffer.write(specials[r.nextInt(specials.length)]);
    }
  }
  return buffer.toString();
}

String generateToken({int length: 50}) {
  var r = new Random(_random.nextInt(5000));
  var buffer = new StringBuffer();
  for (int i = 1; i <= length; i++) {
    if (r.nextBool()) {
      String letter = alphabet[r.nextInt(alphabet.length)];
      buffer.write(r.nextBool() ? letter.toLowerCase() : letter);
    } else {
      buffer.write(numbers[r.nextInt(numbers.length)]);
    }
  }
  return buffer.toString();
}

const List<String> alphabet = const [
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z"
];

const List<int> numbers = const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

const List<String> specials = const ["@", "=", "_", "+", "-", "!", "."];
