part of dslink.link_base;

class DSLinkBase {
  final DSNode rootNode = new BaseNode("Root");
  final String name;
  final PlatformProvider platform;
  final int sendInterval;

  List<Map<String, dynamic>> _sendQueue = [];
  Timer _timer;

  Map<String, int> _lastPing;
  Map<String, RemoteSubscriber> _subscribers = {};

  WebSocketProvider _socket;
  WebSocketProvider _clientSocket;
  String host;
  HttpProvider _http;
  int _reqId = 0;

  bool debug;
  bool autoReconnect;

  Stream<String> _dataStream;

  DSLinkBase(this.name, this.platform, {this.debug: false, this.autoReconnect: true, this.host, this.sendInterval: 50});

  Future connect() {
    if (host == null) {
      throw new Exception("no broker host defined");
    }

    _lastPing = {};
    var url = "ws://" + host + "/wstunnel?${name.replaceAll(" ", "")}";
    _socket = platform.createWebSocket(url);

    return _socket.connect().then((_) {
      _dataStream = _socket.stream();

      _dataStream.listen((data) {
        handleMessage(data);
      }).onDone(() {
        if (autoReconnect) {
          connect();
        }
      });

      _startSendTimer();
    });
  }

  Stream<Map<String, dynamic>> sendRequest(Map<String, dynamic> request) {
    _reqId++;
    var controller = new StreamController.broadcast();
    _responseStreams[_reqId] = controller;

    return controller.stream;
  }

  List<String> _subscriptionNames = [];

  void handleMessage(String input) {
    if (debug) {
      print("RECEIVED: ${input}");
    }

    var json = JSON.decode(input);

    if (json["subscription"] != null) {
      _lastPing[json["subscription"]] = new DateTime.now().millisecondsSinceEpoch;
    }

    if (json["requests"] != null) {
      _handleRequests(json);
    }

    if (json["responses"] != null) {
      _handleResponses(json);
    }
  }

  void _handleResponses(json) {
    for (var response in json["responses"]) {
      var id = response["reqId"];

      if (_responseStreams[id] != null) {
        var controller = _responseStreams[id];
        controller.add(response);
        if (response["partial"] != null) {
          if (response["partial"]["total"] == -1) {
            controller.close();
            _responseStreams.remove(id);
          }
        } else {
          controller.close();
          _responseStreams.remove(id);
        }
      }
    }
  }

  void loadNodes(List<Map<String, dynamic>> input, {DSNode container}) {
    if (container == null) container = rootNode;
    for (var it in input) {
      var node = container.createChild(it["name"], value: it["value"], icon: it["icon"], recording: it["recording"], setter: it["setter"]);

      if (it["children"] != null) {
        loadNodes(it["children"], container: node);
      }

      if (it["initialize"] != null) {
        it["initialize"](node);
      }

      if (it["actions"] != null) {
        for (var d in it["actions"]) {
          var action = container.createAction(d["name"], params: d["params"], results: d["results"], execute: d["execute"], hasTableReturn: d["hasTableReturn"]);
        }
      }
    }
  }

  Map<int, StreamController> _responseStreams = {};
  Map<int, Map> _responseData = {};

  void _handleRequests(json) {
    for (var req in json["requests"]) {
      int id = req["reqId"];
      String method = req["method"] != null ? req["method"] : "";
      String path = req["path"];
      Method m;
      try {
        switch (method) {
          case "GetNode":
            m = new GetNodeMethod();
            break;
          case "GetNodeList":
            m = new GetNodeListMethod();
            break;
          case "GetValue":
            m = new GetValueMethod();
            break;
          case "GetValueHistory":
            m = new GetValueHistoryMethod();
            break;
          case "Invoke":
            m = new InvokeMethod();
            break;
          case "Subscribe":
            m = new SubscribeMethod();
            break;
          case "Unsubscribe":
            m = new UnsubscribeMethod();
            break;
          case "SubscribeNodeList":
            m = new SubscribeNodeListMethod();
            break;
          case "UnsubscribeNodeList":
            m = new UnsubscribeNodeListMethod();
            break;
          default:
            req["error"] = "Unknown method: ${method}";
            _sendQueue.add({
              "subscription": null,
              "response": req
            });
            break;
        }
      } on MessageException catch (e) {
        req["error"] = e.message;
        _sendQueue.add({
          "subscription": null,
          "response": req
        });
      }

      if (m != null) {
        m.resolvePath = resolvePath;
        m.getSubscriber = getSubscriber;
        try {
          m.handle(req, (response) {
            response.remove("subscription");
            _sendQueue.add({
              "subscription": json["subscription"],
              "response": response
            });
          });
        } on MessageException catch (e) {
          var response = new Map.from(req);
          response["error"] = e.message;
          req["error"] = e.message;
          _sendQueue.add({
            "subscription": null,
            "response": response
          });
        }
      }
    }
  }

  void _startSendTimer() {
    _timer = new Timer.periodic(new Duration(milliseconds: sendInterval), (timer) {
      _flushSendQueue();
    });
  }

  void _flushSendQueue() {
    var subnames = new List.from(_lastPing.keys);
    for (var sub in subnames) {
      if (sub == null) continue;
      var lastPing = _lastPing[sub];
      var diff = new DateTime.now().millisecondsSinceEpoch - lastPing;
      if (diff >= 30000) {
        if (debug) print("TIMEOUT: ${sub}");
        _sendQueue.removeWhere((it) => it["subscription"] == sub);
        if (_subscribers.containsKey(sub)) {
          var rsub = _subscribers[sub];
          var nodes = new List.from(rsub.nodes);
          for (var node in nodes) {
            node.unsubscribe(rsub);
          }
          _subscribers.remove(sub);
        }
        _lastPing.remove(sub);
      }
    }

    if (_sendQueue.isEmpty) {
      return;
    }

    var subs = _sendQueue.map((it) => it["subscription"]).toSet();

    for (var sub in subs) {
      // Take 2 responses per subscription at a time
      var datas = _sendQueue.where((it) => it["subscription"] == sub).take(2).toList();
      _sendQueue.removeWhere((it) => datas.contains(it));

      var map = {
        "responses": datas.where((it) => it["response"] != null).map((it) => it["response"]).toList()
      };

      if (sub != null) {
        map["subscription"] = sub;
      }

      var out = JSON.encode(map);

      if (debug) {
        print("SENT: ${out}");
      }

      _socket.send(out);
    }
  }

  RemoteSubscriber getSubscriber(ResponseSender send, String name) {
    if (_subscribers.containsKey(name)) {
      return _subscribers[name];
    } else {
      return _subscribers[name] = new RemoteSubscriber(send, name);
    }
  }

  DSNode createRootNode(String name) {
    var node = new BaseNode(name.replaceAll(" ", "_"));
    node.displayName = name;
    rootNode.addChild(node);
    return node;
  }

  Future<DSNode> resolvePath(String path) {
    path = path.replaceAll("+", " ");
    var node = rootNode;
    var p = "";
    var parts = path.split("/")..removeWhere((it) => it.trim().isEmpty);
    var iter = parts.iterator;

    while (iter.moveNext()) {
      var el = iter.current;

      node = node.children[el];
      p += "/${el}";

      if (node == null) {
        throw new MessageException("No Such Node");
      }
    }

    return new Future.sync(() {
      return node;
    });
  }

  Future disconnect() {
    _timer.cancel();
    _flushSendQueue();
    return new Future.delayed(new Duration(milliseconds: 300), () {
      return _socket.disconnect();
    });
  }
}
