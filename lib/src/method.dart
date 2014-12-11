part of dslink;

typedef void ResponseSender(Map response);

abstract class Method {
  DSLink link;

  handle(Map request, ResponseSender send);
}

class GetNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var node = link.resolvePath(request["path"]);
    List<DSNode> children = node.children.values;
    var out = [];

    {
      Iterator<DSNode> iterator = children.iterator;
      while (iterator.moveNext()) {
        var map = DSEncoder.encodeNode(iterator.current);
        map["path"] = (request["path"] + "/" + Uri.encodeComponent(iterator.current.name)).replaceAll("//", "/");
        out.add(map);
      }
    }

    var partials = [];
    var buff = [];

    int total = 0;
    var from = 0;
    for (int i = 0; i < out.length; i++) {
      total++;

      buff.add(out[i]);
      
      if (((i % MAX) == 0 && i != 0) || i == out.length - 1) {
        var p = {
          "from": from,
          "field": "nodes",
          "items": buff.toList()
        };
        
        if (i == out.length - 1) {
          p["total"] = -1;
        } else {
          p["total"] = total;
        }

        partials.add(p);
        buff.clear();
        from++;
      }
    }

    for (var partial in partials) {
      var res = partials.first == partial ? new Map.from(request) : {};
      res["partial"] = partial;
      res["reqId"] = request["reqId"];
      send(res);
    }
  }

  static const int MAX = 10;
}

class GetValueMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var res = new Map.from(request);
    var node = link.resolvePath(request["path"]);
    res["method"] = "GetValue";
    res.addAll(DSEncoder.encodeValue(node));
    send(res);
  }
}

class SubscribeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    for (var path in request["paths"]) {
      var node = link.resolvePath(path);
      node.subscribe(new RemoteSubscriber(send, request["name"]));
    }
  }
}

class UnsubscribeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    for (var path in request["paths"]) {
      var node = link.resolvePath(path);
      var all = node.subscribers.where((it) => it.name == request['name']).toList();
      for (var it in all) {
        node.unsubscribe(it);
      }
    }
  }
}

class InvokeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
  }
}

class RemoteSubscriber extends Subscriber {
  List<DSNode> nodes = [];
  int _updateId = 0;
  int get updateId => _updateId = _updateId - 1;
  final ResponseSender send;
  
  RemoteSubscriber(this.send, String name) : super(name);

  @override
  void subscribed(DSNode node) {
    nodes.add(node);
    valueChanged(node, node.value);
  }
  
  @override
  void unsubscribed(DSNode node) {
    nodes.remove(node);
  }
  
  @override
  void valueChanged(DSNode node, Value value) {
    var values = [];
    for (var it in nodes) {
      values.add(DSEncoder.encodeValue(it)..addAll({
        "path": it.path
      }));
    }
    
    send({
      "method": "UpdateSubscription",
      "reqId": updateId,
      "values":  values
    });
  }
}

class DSEncoder {
  static Map encodeNode(DSNode node) {
    var map = {};
    map["name"] = node.name;
    map["hasChildren"] = node.children.isNotEmpty;
    map["hasValue"] = node.hasValue;
    map["hasHistory"] = false;
    if (node.hasValue) {
      map["type"] = node.value.type.name;
      map.addAll(encodeFacets(node.valueType));
    }
    return map;
  }
  
  static Map encodeValue(DSNode node) {
    var val = node.value;
    var map = {};
    map["value"] = val.toPrimitive();
    map["status"] = val.status;
    map["type"] = val.type.name;
    map.addAll(encodeFacets(node.valueType));
    map["lastUpdate"] = val.timestamp.toIso8601String();
    return map;
  }
  
  static Map encodeFacets(ValueType type) {
    var map = {};
    if (type.enumValues != null) {
      map["enum"] = type.enumValues.join(",");
    }
    return map;
  }
}
