library dslink.test.common;

import "dart:async";

import "package:test/test.dart";

import "package:dslink/dslink.dart";

Future<ValueUpdate> firstValueUpdate(Requester requester, String path) async {
  return await requester.getNodeValue(path);
}

Future gap() async {
  await new Future.delayed(const Duration(milliseconds: 300));
}

expectNodeValue(from, String path, dynamic value) {
  if (from is Requester) {
    return new Future(() async {
      var update = await firstValueUpdate(from, path);
      expect(update.value, equals(value));
    });
  } else if (from is SimpleNodeProvider) {
    expect(from.getNode(path).lastValueUpdate.value, equals(value));
  } else {
    throw new Exception("What is the from input? I don't understand.");
  }
}

SimpleNodeProvider createSimpleNodeProvider({Map nodes, Map profiles}) {
  return new SimpleNodeProvider(nodes, profiles);
}
