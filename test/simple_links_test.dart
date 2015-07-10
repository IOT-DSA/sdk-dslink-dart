@TestOn("vm")
@Timeout(const Duration(seconds: 10))
library dslink.test.vm.links.simple;

import "dart:async";

import "package:dslink/broker.dart";
import "package:dslink/server.dart";
import "package:dslink/dslink.dart";
import "package:dslink/io.dart";
import "package:test/test.dart";

import "common.dart";

main() {
  group("Simple Links", simpleLinksTests);
}

simpleLinksTests() {
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
        autoInitialize: false
    );

    _links.add(link);

    link.init();
    link.connect();
    return link;
  }

  test("connects to the broker", () async {
    await createLink("ConnectsToServer").timeout(new Duration(seconds: 5));
  });

  test("provides nodes to the broker", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Message": {
        r"$type": "string",
        "?value": "Hello World"
      }
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    var firstParentUpdate = await firstListUpdate(requester, "/conns/DataHost");
    expect(firstParentUpdate.node.children, hasLength(1));
    expect(firstParentUpdate.node.children.keys, contains("Message"));
    var firstMessageUpdate = await firstListUpdate(requester, "/conns/DataHost/Message");
    expect(firstMessageUpdate.node.getConfig(r"$type"), equals("string"));
    await expectNodeValue(requester, "/conns/DataHost/Message", "Hello World");
    host.val("/Message", "Goodbye World");
    await gap();
    await expectNodeValue(requester, "/conns/DataHost/Message", "Goodbye World");
  });
}
