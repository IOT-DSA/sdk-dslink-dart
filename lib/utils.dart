library dslink.utils;

import "dart:async";
import 'dart:typed_data';

part "src/utils/better_iterator.dart";
part "src/utils/base64.dart";
part "src/utils/timer.dart";



Future waitAndRun(Duration time, action()) {
  return new Future.delayed(time, action);
}