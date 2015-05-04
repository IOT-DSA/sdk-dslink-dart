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
  return _logger = new Logger("DSA");
}
