library dslink.test.common;

import "dart:async";

import "package:test/test.dart";

import "package:dslink/common.dart";
import "package:dslink/requester.dart";

Future<ValueUpdate> firstValueUpdate(Requester requester, String path) async {
  ReqSubscribeListener listener;
  Completer completer = new Completer();
  listener = requester.subscribe(path, (ValueUpdate update) {
    completer.complete(update);
    if (listener != null) {
      listener.cancel();
    }
  });
  return completer.future;
}

Future<RequesterListUpdate> firstListUpdate(Requester requester, String path) async {
  Completer completer = new Completer();
  StreamSubscription sub;
  sub = requester.list(path).listen((e) {
    completer.complete(e);
    if (sub != null) {
      sub.cancel();
    }
  });
  return completer.future;
}

Future gap() async {
  await new Future.delayed(const Duration(milliseconds: 300));
}

Future expectNodeValue(Requester requester, String path, dynamic value) async {
  var update = await firstValueUpdate(requester, path);
  expect(update.value, equals(value));
}
