part of dslink.protocol;

abstract class Forwarder {
  void forward(String path, ResponseSender send, Map request);
  bool shouldForward(String path);
  String rewrite(String path);
}

class DSProtocol {
  static Future<DSNode> resolvePath(String path, DSNode rootNode) {
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
  
  static void handleRequest(ResponseSender send, PathResolver resolvePath, SubscriberGetter getSubscriber, Forwarder forwarder, json) {
    for (var req in json["requests"]) {
      int id = req["reqId"];
      String method = req["method"] != null ? req["method"] : "";
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
            send(req);
            break;
        }
      } on MessageException catch (e) {
        req["error"] = e.message;
        send(req);
      }

      if (m != null) {
        m.resolvePath = resolvePath;
        m.getSubscriber = getSubscriber;
        m.forwarder = forwarder;
        try {
          m.handle(req, send);
        } catch (e) {
          var response = new Map.from(req);
          response["error"] = e.toString();
          send(response);
        }
      }
    }
  }
}
