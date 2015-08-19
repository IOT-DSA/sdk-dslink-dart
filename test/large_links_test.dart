@TestOn("vm")
@Timeout(const Duration(seconds: 30))
library dslink.test.vm.links.simple;

import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:dslink/broker.dart";
import "package:dslink/server.dart";
import "package:dslink/dslink.dart";
import "package:dslink/io.dart";
import "package:dslink/nodes.dart";
import "package:test/test.dart";

import "common.dart";

main() {
  group("Large Links", largeLinksTest);
}

largeLinksTest() {
  DsHttpServer server;
  int port;
  setUp(() async {
    updateLogLevel("WARNING");
    port = await getRandomSocketPort();
    server = await startBrokerServer(port, persist: false);
  });

  List<LinkProvider> _links = [];

  tearDown(() async {
    for (var link in _links) {
      link.close();
    }

    await server.stop();
  });

  Future<LinkProvider> createLink(String name, {
  List<String> args, bool isRequester: false,
  bool isResponder: true, Map nodes, Map profiles}) async {
    var link = new LinkProvider(
      ["--broker=http://127.0.0.1:${port}/conn"]..addAll(((args == null ? [] : args) as List<String>).toList()),
      name,
      isRequester: isRequester,
      isResponder: isResponder,
      defaultNodes: nodes,
      profiles: profiles,
      autoInitialize: false,
      loadNodesJson: false,
      savePrivateKey: false
    );

    _links.add(link);

    link.init();
    link.connect();
    return link;
  }

  test("are able to send large numbers of value updates", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Number": {
        r"$type": "number",
        "?value": 1
      }
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();

    var sent = [];
    var received = [];
    var sub = requester.subscribe("/conns/DataHost/Number", (ValueUpdate update) {
      received.add(update.value);
    });

    await gap();

    for (var i = 1; i <= 500; i++) {
      host.val("/Number", i);
      sent.add(i);
      await new Future.delayed(const Duration(milliseconds: 10));
    }

    await gap();

    sub.cancel();

    expect(received, equals(sent));
  });
}
