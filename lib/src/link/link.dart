part of dslink._link;

abstract class SideProvider {
  DSLinkBase link;
  
  void send(String data);
  Future connect(String url);
  Future disconnect();
}

class DSLinkBase {
  final DSNode rootNode = new BaseNode("Root");
  final String name;
  final SideProvider side;
  
  List<Map<String, dynamic>> _sendQueue = [];
  Timer _timer;
  
  Map<String, int> _lastPing;
  Map<String, RemoteSubscriber> _subscribers = {};
  
  bool debug;
  
  DSLinkBase(this.name, this.side, {this.debug: false}) {
    side.link = this;
  }
  
  Future connect(String host) {
    _lastPing = {};
    var url = "ws://" + host + "/wstunnel?${name}";
    return side.connect(url).then((socket) {
      _timer = new Timer.periodic(new Duration(milliseconds: 100), (timer) {
        for (var sub in _lastPing.keys) {
          var lastPing = _lastPing[sub];
          var diff = new DateTime.now().millisecondsSinceEpoch - lastPing;
          if (diff >= 10000) {
            if (debug) print("TIMEOUT: ${sub}");
            _sendQueue.removeWhere((it) => it["subscription"] == sub);
            if (_subscribers.containsKey(sub)) {
              var rsub = _subscribers[sub];
              for (var node in rsub.nodes) {
                node.unsubscribe(rsub);
              }
              _subscribers.remove(sub);
            }
          }
        }
        
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
          
          side.send(out);
        }
      });
    });
  }
  
  List<String> _subscriptionNames = [];
  
  void handleMessage(String input) {
    var json = JSON.decode(input);
    
    if (json["subscription"] != null && json["requests"] == null || json["requests"].isEmpty) {
      _lastPing[json["subscription"]] = new DateTime.now().millisecondsSinceEpoch;
      return;
    }
    
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
        throw new Exception("No Such Node");
      }
    }
    
    return node;
  }
  
  Future disconnect() => side.disconnect();
}
