part of dslink.broker;

class ServerWebSocket extends WebSocketConnection {
  ServerWebSocket(WebSocket socket,
      {bool enableTimeout: false, bool enableAck: false})
      : super(socket, enableTimeout: enableTimeout, enableAck: enableAck);
  void onPingTimer(Timer t) {
    if (WebSocketConnection.throughputEnabled &&
        (dataIn != 0 || dataOut != 0)) {
      ThroughPutController.addThroughput(
          messageIn, messageOut, dataIn, dataOut);
      messageIn = 0;
      messageOut = 0;
      dataIn = 0;
      dataOut = 0;
    }
    super.onPingTimer(t);
  }
}

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
    changeValue();
  }
  static int lastMessageIn = 0;
  static int lastDataIn = 0;
  static int lastMessageOut = 0;
  static int lastDataOut = 0;

  static int lastTs = -1;
  static Timer _timer;
  static addThroughput(int msgIn, int msgOut, int dataIn, int dataOut) {
    lastMessageIn += msgIn;
    lastDataIn += dataIn;
    lastMessageOut += msgOut;
    lastDataOut += dataOut;
    if (_timer == null) {
      _timer = new Timer(new Duration(seconds:5), changeValue);
    }
  }
  static void changeValue() {
    _timer = null;
    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    num del = ts - lastTs;
    if (del > 6000) del = 5000;
    else if (del < 1) del = 1;
    del /= 1000.0;
    messagesInPerSecond.updateValue(lastMessageIn / del, force: true);
    dataInPerSecond.updateValue(lastDataIn / del, force: true);
    messagesOutPerSecond.updateValue(lastMessageOut / del, force: true);
    dataOutPerSecond.updateValue(lastDataOut / del, force: true);

    lastMessageIn = 0;
    lastDataIn = 0;
    lastMessageOut = 0;
    lastDataOut = 0;
    lastTs = ts;
  }

  static void set throughputNeeded(bool val) {
    if (val ==  WebSocketConnection.throughputEnabled) {
      return;
    }
    if (val) {
      WebSocketConnection.throughputEnabled = true;
    } else {
      WebSocketConnection.throughputEnabled = messagesOutPerSecond.throughputNeeded ||
          dataOutPerSecond.throughputNeeded ||
          messagesInPerSecond.throughputNeeded ||
          dataInPerSecond.throughputNeeded;
    }
  }
}

class ThroughPutNode extends BrokerNode {
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
