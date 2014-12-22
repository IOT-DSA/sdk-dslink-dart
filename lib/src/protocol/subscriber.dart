part of dslink.protocol;

typedef void RemoteSubscriberSender(DSNode node);

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
      valueChanged(null, node, node.value);
    }
  }

  @override
  void unsubscribed(DSNode node) {
    nodes.remove(node);
  }
  
  Multimap<DSNode, Value> _values = new Multimap<DSNode, Value>();
  
  void tick() {
    var currentMs = currentMillis();
    var m = _values.toMap();
    var updates = [];
    for (var node in m.keys) {
      var interval = node.getUpdateInterval();
      var rollup = node.getUpdateRollup();
      if ((currentMs - _lastMs) >= interval.millis) {
        var value = rollup.combine(m[node].toList());
        updates.add(DSEncoder.encodeValue(node, value)..addAll({
          "path": node.path
        }));
        _values.removeAll(node);
      }
    }
    
    send({
      "method": "UpdateSubscription",
      "reqId": updateId,
      "values": updates
    });
    
    _lastMs = currentMs;
  }
  
  int _lastMs = 0;

  @override
  void valueChanged(Value lastValue, DSNode node, Value value) {
    if (node.shouldUpdate(lastValue, value)) {
      _values.add(node, value);
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