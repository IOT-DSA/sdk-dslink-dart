library dslink.utils;

import "dart:async";
import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';

import "package:logging/logging.dart";

part "src/utils/better_iterator.dart";
part "src/utils/base64.dart";
part "src/utils/timer.dart";
part "src/utils/stream_controller.dart";
part "src/utils/json.dart";

const String DSA_VERSION = '1.0.1';

Logger _logger;

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

void updateLogLevel(String name) {
  name = name.trim().toUpperCase();

  Map<String, Level> levels = {};
  for (var l in Level.LEVELS) {
    levels[l.name] = l;
  }

  var l = levels[name];

  if (l != null) {
    logger.level = l;
  }
}
