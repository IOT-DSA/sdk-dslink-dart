part of dslink.link;

class DSLink {
  final DSNode rootNode = new BaseNode("Root");
  
  final String name;
  
  List<Map<String, dynamic>> _sendQueue = [];
  
  WebSocket _socket;
  Timer _timer;
  
  bool debug = false;
  
  DSLink(this.name);
  
  Future connect(String host) {
    var url = "ws://" + host + "/wstunnel?${name}";
    return WebSocket.connect(url).then((socket) {
      _socket = socket;
      socket.pingInterval = new Duration(seconds: 10);
      
      socket.listen((data) {
        if (data is String) {
          if (debug) {
            print("RECEIVED: ${data}");
          }
          handleMessage(data);
        }
      });
      
      _timer = new Timer.periodic(new Duration(milliseconds: 100), (timer) {
        if (_sendQueue.isEmpty) {
          return;
        }
        
        var subs = _sendQueue.map((it) => it["subscription"]).toSet();
        
        for (var sub in subs) {
          var responses = _sendQueue.where((it) => it["subscription"] == sub).toList();
          _sendQueue.removeWhere((it) => responses.contains(it));
          
          var out = JSON.encode({
            "subscription": sub,
            "responses": responses.map((it) => it["response"]).toList()
          });
          
          if (debug) {
            print("SENT: ${out}");
          }
          
          _socket.add(out);
        }
      });
    });
  }
  
  List<String> _subscriptionNames = [];
  
  void handleMessage(String input) {
    var json = JSON.decode(input);
    
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
        m.handle(req, (response) {
          response.remove("subscription");
          _sendQueue.add({
            "subscription": json["subscription"],
            "response": response
          });
        });
      }
    }
  }
  
  DSNode createRootNode(String name) {
    var node = new BaseNode(name);
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
        throw new Exception("No Such Node");
      }
    }
    
    return node;
  }
}
