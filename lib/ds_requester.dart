library dslink.requester;
import 'ds_common.dart';
import 'dart:async';

part "src/requester/requester.dart";
part "src/requester/request.dart";

typedef void DsValueUpdater(String ts, Object value, {Map meta, DsError error});