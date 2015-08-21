part of dslink.broker;

class ThroughPutController {
  static ThroughPutNode messagesOutPerSecond;
  static ThroughPutNode dataOutPerSecond;
  static ThroughPutNode messagesInPerSecond;
  static ThroughPutNode dataInPerSecond;
  static void initNodes(NodeProvider provider) {
    messagesOutPerSecond = new ThroughPutNode(
        "/sys/messagesOutPerSecond", provider)..configs[r"$type"] = "number";
    messagesInPerSecond = new ThroughPutNode(
        "/sys/messagesInPerSecond", provider)..configs[r"$type"] = "number";

    dataOutPerSecond = new ThroughPutNode("/sys/dataOutPerSecond", provider)
      ..configs[r"$type"] = "number";
    dataInPerSecond = new ThroughPutNode("/sys/dataInPerSecond", provider)
      ..configs[r"$type"] = "number";
  }

  static Timer _timer;

  static void changeValue(Timer t) {
    messagesInPerSecond.updateValue(WebSocketConnection.messageIn , force: true);
    dataInPerSecond.updateValue(WebSocketConnection.dataIn , force: true);
    messagesOutPerSecond.updateValue(WebSocketConnection.messageOut , force: true);
    dataOutPerSecond.updateValue(WebSocketConnection.dataOut , force: true);

    WebSocketConnection.messageIn = 0;
    WebSocketConnection.dataIn = 0;
    WebSocketConnection.messageOut = 0;
    WebSocketConnection.dataOut = 0;
  }

  static void set throughputNeeded(bool val) {
    if (val ==  WebSocketConnection.throughputEnabled) {
      return;
    }
    if (val) {
      WebSocketConnection.throughputEnabled = true;
      if (_timer == null) {
        WebSocketConnection.messageIn = 0;
        WebSocketConnection.dataIn = 0;
        WebSocketConnection.messageOut = 0;
        WebSocketConnection.dataOut = 0;
        _timer = new Timer.periodic(new Duration(seconds:1), changeValue);
      }
    } else {
      WebSocketConnection.throughputEnabled = messagesOutPerSecond.throughputNeeded ||
          dataOutPerSecond.throughputNeeded ||
          messagesInPerSecond.throughputNeeded ||
          dataInPerSecond.throughputNeeded;
      if (!WebSocketConnection.throughputEnabled && _timer != null) {
        _timer.cancel();
        _timer = null;
      }
    }
  }
}

class ThroughPutNode extends BrokerStaticNode {
  ThroughPutNode(String path, BrokerNodeProvider provider)
      : super(path, provider);

  bool throughputNeeded = false;
  @override
  RespSubscribeListener subscribe(callback(ValueUpdate), [int qos = 0]) {
    if (!throughputNeeded) {
      throughputNeeded = true;
      ThroughPutController.throughputNeeded = true;
    }
    return super.subscribe(callback, qos);
  }
  @override
  void unsubscribe(callback(ValueUpdate update)) {
    super.unsubscribe(callback);
    if (throughputNeeded && callbacks.isEmpty) {
      throughputNeeded = false;
      ThroughPutController.throughputNeeded = false;
    }
  }
}
