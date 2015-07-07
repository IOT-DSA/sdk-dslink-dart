@TestOn("vm")
library dslink.test.vm.simple;

import "dart:async";

import "package:dslink/broker.dart";
import "package:dslink/server.dart";
import "package:dslink/dslink.dart";
import "package:dslink/io.dart";
import "package:test/test.dart";

main() {
  group("Simple Links", simpleTests);
}

simpleTests() {
  DsHttpServer server;
  int port;
  setUp(() async {
    updateLogLevel("WARNING");
    port = await getRandomSocketPort();
    server = await startBrokerServer(port);
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
    }).timeout(new Duration(seconds: 5));

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    RequesterListUpdate firstParentUpdate = await requester.list("/conns/DataHost")
      .first
      .timeout(new Duration(seconds: 5));
    expect(firstParentUpdate.node.children, hasLength(1));
    expect(firstParentUpdate.node.children.keys, contains("Message"));
    RequesterListUpdate firstMessageUpdate = await requester.list("/conns/DataHost/Message")
      .first
      .timeout(new Duration(seconds: 5));
    expect(firstMessageUpdate.node.getConfig(r"$type"), equals("string"));
    var i = 0;
    ReqSubscribeListener listener;
    listener = requester.subscribe("/conns/DataHost/Message", (ValueUpdate update) async {
      if (i == 0) {
        expect(update.value, equals("Hello World"));
        host.val("/conns/DataHost/Message", "Goodbye World");
        i++;
      } else if (i == 1) {
        expect(update.value, equals("Goodbye World"));
        await listener.cancel();
      }
    });
  });
}
