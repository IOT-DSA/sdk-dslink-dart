part of dslink.protocol;

typedef void ResponseSender(Map response);

abstract class Method {
  DSLinkBase link;

  handle(Map request, ResponseSender send);
}

class GetNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    DSNode node;
    if (request["node"] is DSNode) {
      node = request["node"];
    } else {
      node = link.resolvePath(request["path"]);
    }
    List<DSNode> children = node.children.values.toList();

    if (children.length <= MAX) {
      var response = new Map.from(request);
      var nodes = [];
      for (var item in children) {
        var nodeMap = DSEncoder.encodeNode(item);
        nodeMap["path"] = item.path;
        nodes.add(nodeMap);
      }
      response["nodes"] = nodes;
      send(response);
    }

    BetterIterator iterator = new BetterIterator(children);
    Map response;
    int grandTotal = 0;
    int fromIdx = 0;

    while (iterator.hasNext()) {
      response = new Map.from(request);
      var partial = response["partial"] = {};

      partial["from"] = fromIdx;
      partial["field"] = "nodes";

      var items = partial["items"] = [];

      int count = 0;
      DSNode kid;
      Map nodeMap;

      while (iterator.hasNext()) {
        grandTotal++;
        if (++count > MAX) {
          break;
        }

        kid = iterator.next();

        nodeMap = DSEncoder.encodeNode(kid);
        nodeMap["path"] = kid.path;
        items.add(nodeMap);
        fromIdx++;
      }

      if (!iterator.hasNext()) {
        partial["total"] = -1;
      } else {
        partial["total"] = fromIdx + MAX;
      }

      send(response);
    }
  }

  static const int MAX = 50;
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

class SubscribeNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var node = link.resolvePath(request["path"]);
    var sub = link.getSubscriber(send, request["subscription"] != null ? request["subscription"] : "_NodeList_");
    node.subscribe(sub);
  }
}

class UnsubscribeNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var node = link.resolvePath(request["path"]);
    var sub = link.getSubscriber(send, request["subscription"] != null ? request["subscription"] : "_NodeList_");
    node.unsubscribe(sub);
  }
}

class GetValueHistoryMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var node = link.resolvePath(request["path"]);
    TimeRange timeRange;
    Interval interval;

    {
      var tr = request["timeRange"];
      var split = tr.split("/") as List<String>;
      var from = DateTime.parse(split[0]);
      var to = DateTime.parse(split[1]);
      timeRange = new TimeRange(from, to);
    }

    {
      var inter = request["interval"];
      interval = Interval.forName(inter);
    }

    var rollupType = request["rollup"] != null ? RollupType.forName(request["rollup"]) : null;

    runZoned(() {
      new Future.value(node.getValueHistory()).then((trend) {
        if (trend != null) {
          if (trend is! Trend) {
            throw new Exception("This is not a trend.");
          }
          int index = 0;
          bool more = true;
          while (more) {
            var res = new Map.from(request);
            more = DSEncoder.encodeValueHistory(request["reqId"], request["path"], trend, index, MAX, res);
            send(res);
            index += MAX;
          }
        }
      });
    }, zoneValues: {
      DSContext.ID_INTERVAL: interval,
      DSContext.ID_TIME_RANGE: timeRange,
      DSContext.ID_ROLLUP_TYPE: rollupType
    });
  }

  static const int MAX = 100;
}

class SubscribeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    for (var path in request["paths"]) {
      var node = link.resolvePath(path);
      var sub = link.getSubscriber(send, request["name"]);
      node.subscribe(sub);
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
    var path = request["path"];
    var node = link.resolvePath(path);
    var action = request["action"];
    var params = <String, Value>{};
    var p = request["parameters"] as Map;
    for (var key in p.keys) {
      params[key] = Value.of(p[key]);
    }
    var result = new Future.value(node.invoke(action, params));
    result.then((results) {
      if (results is Map) {
        var res = new Map.from(request);
        send(res..addAll({
          "results": results
        }));
      } else if (results == null) {
        send(request);
      } else if (results is Table) {
        Table table = results;
        String tableName = table is SingleRowTable && table.hasName ? table.tableName : "table";

        var response = new Map.from(request);
        var r = response["results"] = {};
        var resp = r[tableName] = {};
        var columns = resp["columns"] = [];
        int columnCount = table.columnCount;

        for (var i = 0; i < columnCount; i++) {
          var m = {};
          columns.add(m);
          m["name"] = table.getColumnName(i);
          m.addAll(DSEncoder.encodeFacets(table.getColumnType(i)));
        }

        int index = 0;
        bool more = true;

        while (more) {
          if (response == null) response = new Map.from(request);
          more = DSEncoder.encodeTable(response, tableName, table, index, MAX);
          send(response);
          response = null;
          index += MAX;
        }
      } else {
        throw new Exception("Invalid Action Return Type");
      }
    });
  }

  static const int MAX = 100;
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
    if (node.hasValue) {
      valueChanged(node, node.value);
    }
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
      "values": values
    });
  }
  
  @override
  void treeChanged(DSNode node) {
    var s = send;
    new GetNodeListMethod().handle({
      "method": "GetNodeList",
      "node": node,
      "reqId": updateId
    }, (response) {
      var actual = new Map.from(response);
      actual["updateId"] = actual["reqId"];
      actual.remove("node");
      actual["path"] = node.path;
      actual.remove("reqId");
      actual["method"] = "UpdateNodeList";
      s(actual);
    });
  }
}

class GetNodeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var res = new Map.from(request);
    var node = link.resolvePath(request["path"]);
    var nodeMap = res["node"] = {};
    DSEncoder.encodeNode(node);
    nodeMap["path"] = node.path;
    send(nodeMap);
  }
}

class MapEntry<K, V> {
  K key;
  V value;

  static List<MapEntry> forMap(Map input) {
    var entries = [];
    for (var k in input.keys) {
      entries.add(new MapEntry()
          ..key = k
          ..value = input[k]);
    }
    return entries;
  }
}
