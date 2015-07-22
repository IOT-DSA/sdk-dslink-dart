@TestOn("vm")
@Timeout(const Duration(seconds: 10))
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
        autoInitialize: false,
        loadNodesJson: false,
        savePrivateKey: false
    );

    _links.add(link);

    link.init();
    link.connect();
    return link;
  }

  test("connect to the broker", () async {
    await createLink("ConnectsToServer").timeout(new Duration(seconds: 5));
  });

  test("provide single level nodes to the broker", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Message": {
        r"$type": "string",
        "?value": "Hello World"
      }
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();
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

  test("support invoking a simple action with 0 parameters and 1 result", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Get": {
        r"$is": "get",
        r"$invokable": "read",
        r"$result": "values",
        r"$columns": [
          {
            "name": "message",
            "type": "string"
          }
        ]
      }
    }, profiles: {
      "get": (String path, SimpleNodeProvider provider) => new SimpleActionNode(path, (Map<String, dynamic> params) {
        return {
          "message": "Hello World"
        };
      }, provider)
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();
    var result = await requester.invoke("/conns/DataHost/Get", {}).first;
    expect(result.updates, hasLength(1));
    expect(result.updates.first, equals({
      "message": "Hello World"
    }));
  });

  test("support invoking a simple table action with 0 parameters and 1 column", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Get": {
        r"$is": "get",
        r"$invokable": "read",
        r"$result": "table",
        r"$columns": [
          {
            "name": "message",
            "type": "string"
          }
        ]
      }
    }, profiles: {
      "get": (String path, SimpleNodeProvider provider) => new SimpleActionNode(path, (Map<String, dynamic> params) {
        return [
          {
            "message": "Hello World"
          },
          {
            "message": "Goodbye World"
          }
        ];
      }, provider)
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();
    var result = await requester.invoke("/conns/DataHost/Get", {}).first;
    expect(result.updates, hasLength(2));
    expect(result.updates, equals([
      {
        "message": "Hello World"
      },
      {
        "message": "Goodbye World"
      }
    ]));
  });

  test("support invoking a table action with 1 parameter and 2 columns", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Get": {
        r"$is": "get",
        r"$invokable": "read",
        r"$result": "table",
        r"$params": [
          {
            "name": "input",
            "type": "string"
          }
        ],
        r"$columns": [
          {
            "name": "uppercase",
            "type": "string"
          },
          {
            "name": "lowercase",
            "type": "string"
          }
        ]
      }
    }, profiles: {
      "get": (String path, SimpleNodeProvider provider) => new SimpleActionNode(path, (Map<String, dynamic> params) {
        expect(params, hasLength(1));

        var input = params["input"];

        expect(input, new isInstanceOf<String>());
        expect(input, equals("Hello World"));

        return [
          {
            "uppercase": input.toUpperCase(),
            "lowercase": input.toLowerCase()
          }
        ];
      }, provider)
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();
    var result = await requester.invoke("/conns/DataHost/Get", {
      "input": "Hello World"
    }).first;
    expect(result.updates, hasLength(1));
    expect(result.updates, equals([
      {
        "uppercase": "HELLO WORLD",
        "lowercase": "hello world"
      }
    ]));
  });

  test("support invoking an action to receive binary data", () async {
    LinkProvider host = await createLink("DataHost", nodes: {
      "Get": {
        r"$is": "get",
        r"$invokable": "read",
        r"$result": "values",
        r"$params": [
          {
            "name": "input",
            "type": "string"
          }
        ],
        r"$columns": [
          {
            "name": "data",
            "type": "binary"
          }
        ]
      }
    }, profiles: {
      "get": (String path, SimpleNodeProvider provider) => new SimpleActionNode(path, (Map<String, dynamic> params) {
        expect(params, hasLength(1));

        var input = params["input"];

        expect(input, new isInstanceOf<String>());
        expect(input, equals("Hello World"));

        var data = ByteDataUtil.fromList(UTF8.encode(input));

        return [
          {
            "data": data
          }
        ];
      }, provider)
    });

    var client = await createLink("DataClient", isRequester: true, isResponder: false);
    var requester = await client.onRequesterReady;
    await gap();
    var result = await requester.invoke("/conns/DataHost/Get", {
      "input": "Hello World"
    }).first;
    expect(result.updates, hasLength(1));
    var firstUpdate = result.updates.first;

    expect(firstUpdate, new isInstanceOf<Map>());
    expect(firstUpdate, hasLength(1));
    expect(firstUpdate, contains("data"));
    var data = firstUpdate["data"];

    expect(data, new isInstanceOf<ByteData>());
    var decoded = UTF8.decode(ByteDataUtil.toUint8List(data));
    expect(decoded, equals("Hello World"));
  });
}
