part of dslink.link_base;

class RemoteSubscriber extends Subscriber {
  List<DSNode> nodes = [];
  int _updateId = 0;
  int get updateId => _updateId = _updateId - 1;
  final ResponseSender send;
  final DSLinkBase link;

  RemoteSubscriber(this.link, this.send, String name) : super(name);

  @override
  void subscribed(DSNode node) {
    nodes.add(node);
    if (node.hasValue) {
      valueChanged(null, node, node.value);
    }
  }

  @override
  void unsubscribed(DSNode node) {
    nodes.remove(node);
  }
  
  Multimap<DSNode, Value> _values = new Multimap<DSNode, Value>();
  
  void tick() {
    var m = _values.toMap();
    var updates = [];
    var toRemove = [];
    for (var node in m.keys) {
      var interval = node.getUpdateInterval();
      var rollup = node.getUpdateRollup();
      var lastUpdate = _lastUpdateTimes[node];
      if (lastUpdate == null) lastUpdate = 0;
      if (currentMillis() - lastUpdate >= interval.millis) {
        var value = rollup.combine(m[node].toList());
        updates.add(DSEncoder.encodeValue(node, value)..addAll({
          "path": node.path
        }));
        _lastUpdateTimes[node] = currentMillis();
        toRemove.add(node);
      }
    }
    
    for (var node in toRemove) {
      _values.removeAll(node);
    }
    
    if (updates.isNotEmpty) {
      send({
        "method": "UpdateSubscription",
        "reqId": updateId,
        "values": updates
      });
    }
  }
  
  Map<DSNode, int> _lastUpdateTimes = {};

  @override
  void valueChanged(Value lastValue, DSNode node, Value value) {
    if (node.shouldUpdate(lastValue, value)) {
      if (node.getUpdateInterval().isNone()) {
        var data = {
          "subscription": name,
          "responses": [
            {
              "method": "UpdateSubscription",
              "reqId": updateId,
              "values": [
                DSEncoder.encodeValue(node, value)..addAll({
                  "path": node.path
                })
              ]
            }
          ]
        };
        
        link._socket.send(JSON.encode(data));
      } else {
        _values.add(node, value);
      }
    }
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