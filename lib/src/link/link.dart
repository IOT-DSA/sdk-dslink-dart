part of dslink.link_base;

class DSLinkBase {
  final DSNode rootNode = new BaseNode("Root");
  final String name;
  final PlatformProvider platform;

  List<Map<String, dynamic>> _sendQueue = [];
  Timer _timer;

  Map<String, int> _lastPing;
  Map<String, RemoteSubscriber> _subscribers = {};

  WebSocketProvider _socket;
  WebSocketProvider _clientSocket;
  String _host;
  HttpProvider _http;
  int _reqId = 0;

  bool debug;

  DSLinkBase(this.name, this.platform, {this.debug: false});

  Future connect(String host) {
    _host = host;
    _lastPing = {};
    var url = "ws://" + host + "/wstunnel?${name.replaceAll(" ", "")}";
    _socket = platform.createWebSocket(url);
    return _socket.connect().then((_) {
      _socket.stream().listen((data) {
        handleMessage(data);
      });

      _startSendTimer();
    });

    /* .catchError((e) {
      _socket.disconnect().catchError(() {});
      _socket = null;
      
      print("ERROR: Failed to connect to WebSocket!");
      print(e);
    });  */
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
        m.link = this;
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
    _timer = new Timer.periodic(new Duration(milliseconds: 100), (timer) {
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
    });
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

  DSNode resolvePath(String path) {
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

    return node;
  }

  Future disconnect() => _socket.disconnect();
}
