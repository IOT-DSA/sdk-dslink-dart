@TestOn("vm")
@Timeout(const Duration(seconds: 60))
library dslink.test.vm.links.large;

import "dart:async";

import "package:dsbroker/broker.dart";
import "package:dslink/dslink.dart";
import "package:dslink/io.dart";
import "package:test/test.dart";

import "common.dart";

main() {
  group("Large Links", largeLinksTest);
}

largeLinksTest() {
  DsHttpServer server;
  int port;
  setUp(() async {
    updateLogLevel("WARN");
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

  Future<LinkProvider> createLink(
    String name, {
      List<String> args,
      bool isRequester: false,
      bool isResponder: true,
      Map<String, dynamic> nodes,
      Map<String, NodeFactory> profiles
    }) async {
    var margs = <String>[
      "--broker=http://127.0.0.1:${port}/conn"
    ];

    if (args != null)  {
      margs.addAll(args);
    }

    var link = new LinkProvider(
      margs,
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
      "number": {
        r"$type": "number",
        "?value": 1
      }
    });

    var client = await createLink(
      "DataClient",
      isRequester: true,
      isResponder: false
    );
    var requester = await client.onRequesterReady;
    await gap();

    var sent = [];
    var received = [];
    var sub = requester.subscribe("/downstream/DataHost/number", (ValueUpdate update) {
      received.add(update.value);
    }, 1);

    await gap();

    for (var i = 1; i <= 5000; i++) {
      host.val("/number", i);
      sent.add(i);
      await new Future.delayed(const Duration(milliseconds: 1));
    }

    await gap();
    sub.cancel();

    expect(received, equals(sent));
  });
}
