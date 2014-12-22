part of dslink.protocol;

typedef void ResponseSender(Map response);
typedef Future<DSNode> PathResolver(String path);
typedef Subscriber SubscriberGetter(ResponseSender send, String name);

abstract class Method {
  PathResolver resolvePath;
  Forwarder forwarder;
  SubscriberGetter getSubscriber;

  handle(Map request, ResponseSender send);
}

class GetNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    Future future;
    if (request["node"] is DSNode) {
      future = new Future.value(request["node"]);
    } else {

      if (forwarder.shouldForward(request["path"])) {
        request["path"] = forwarder.rewrite(request["path"]);
        forwarder.forward(request["path"], send, request);
        return;
      }

      future = resolvePath(request["path"]);
    }

    future.then((node) {
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
    });
  }

  static const int MAX = 50;
}

class GetValueMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var res = new Map.from(request);
    if (forwarder.shouldForward(request["path"])) {
      request["path"] = forwarder.rewrite(request["path"]);
      forwarder.forward(request["path"], send, request);
      return;
    }
    resolvePath(request["path"]).then((node) {
      res["method"] = "GetValue";
      res.addAll(DSEncoder.encodeValue(node, node.value));
      send(res);
    });
  }
}

class SubscribeNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    if (forwarder.shouldForward(request["path"])) {
      request["path"] = forwarder.rewrite(request["path"]);
      forwarder.forward(request["path"], send, request);
      return;
    }
    resolvePath(request["path"]).then((node) {
      var sub = getSubscriber(send, request["subscription"] != null ? request["subscription"] : "_NodeList_");
      node.subscribe(sub);
    });
  }
}

class UnsubscribeNodeListMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    if (forwarder.shouldForward(request["path"])) {
      request["path"] = forwarder.rewrite(request["path"]);
      forwarder.forward(request["path"], send, request);
      return;
    }
    resolvePath(request["path"]).then((node) {
      var sub = getSubscriber(send, request["subscription"] != null ? request["subscription"] : "_NodeList_");
      node.unsubscribe(sub);
    });
  }
}

class GetValueHistoryMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    if (forwarder.shouldForward(request["path"])) {
      request["path"] = forwarder.rewrite(request["path"]);
      forwarder.forward(request["path"], send, request);
      return;
    }
    resolvePath(request["path"]).then((node) {
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
    });
  }

  static const int MAX = 100;
}

class SubscribeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var future = new Future.value();
    for (var path in request["paths"]) {
      if (forwarder.shouldForward(path)) {
        path = forwarder.rewrite(path);
        var req = new Map.from(request);
        req["paths"] = [path];
        forwarder.forward(path, send, req);
        continue;
      }
      
      future = future.then((_) {
        return resolvePath(path);
      }).then((node) {
        var sub = getSubscriber(send, request["name"]);
        node.subscribe(sub);
      }).catchError((e) {
        // Ignore Error
        return;
      });
    }
  }
}

class UnsubscribeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var future = new Future.value();
    for (var path in request["paths"]) {
      if (forwarder.shouldForward(path)) {
        path = forwarder.rewrite(path);
        var req = new Map.from(request);
        req["paths"] = [path];
        forwarder.forward(path, send, req);
        continue;
      }
      
      future = future.then((_) {
        return resolvePath(path);
      }).then((node) {
        var all = node.subscribers.where((it) => it.name == request['name']).toList();
        for (var it in all) {
          node.unsubscribe(it);
        }
      }).catchError((e) {
        // Ignore Error
        return;
      });;
    }
  }
}

class InvokeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var path = request["path"];
    
    if (forwarder.shouldForward(path)) {
      request["path"] = forwarder.rewrite(request["path"]);
      forwarder.forward(request["path"], send, request);
    }
    
    resolvePath(path).then((node) {
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
    });
  }

  static const int MAX = 100;
}

class GetNodeMethod extends Method {
  @override
  handle(Map request, ResponseSender send) {
    var res = new Map.from(request);
    resolvePath(request["path"]).then((node) {
      var nodeMap = res["node"] = {};
      DSEncoder.encodeNode(node);
      nodeMap["path"] = node.path;
      send(nodeMap);
    });
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
