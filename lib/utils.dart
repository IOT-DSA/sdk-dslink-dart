library dslink.utils;

import "dart:async";
import 'dart:typed_data';
import 'dart:collection';
import 'dart:convert';

part "src/utils/better_iterator.dart";
part "src/utils/base64.dart";
part "src/utils/timer.dart";
part "src/utils/stream_controller.dart";
part "src/utils/json.dart";

const int _LOG_NONE = 0;
//const int _LOG_FATAL = 1;
const int _LOG_ERROR = 10;
const int _LOG_WARNING = 30;
const int _LOG_INFO = 40;
const int _LOG_DEBUG = 50;

int _LOG_LEVEL = _LOG_DEBUG;

const Map<String, int> _debugLevelMap = const {
  'none': _LOG_NONE,
  //'fatal': _LOG_FATAL,
  'error': _LOG_ERROR,
  'warn': _LOG_WARNING,
  'warning': _LOG_WARNING,
  'info': _LOG_INFO,
  'debug': _LOG_DEBUG,
};

void updateLogLevel(String str) {
  if (_debugLevelMap.containsKey(str)) {
    _LOG_LEVEL = _debugLevelMap[str];
  }
}

void printLog(Object str) {
  if (_LOG_LEVEL >= _LOG_INFO) {
    print(str);
  }
}

void printWarning(Object str) {
  if (_LOG_LEVEL >= _LOG_WARNING) {
    print(str);
  }
}
void printError(Object str) {
  if (_LOG_LEVEL >= _LOG_ERROR) {
    print(str);
  }
}
void printDebug(Object str) {
  if (_LOG_LEVEL >= _LOG_DEBUG) {
    print(str);
  }
}
