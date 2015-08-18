part of dslink.broker;

class ServerWebSocket extends WebSocketConnection {
  ServerWebSocket(WebSocket socket, {bool enableTimeout: false, bool enableAck:false})
      : super(socket, enableTimeout: enableTimeout, enableAck:enableAck);
  void onPingTimer(Timer t) {
    if (WebSocketConnection.throughputEnabled && (dataIn != 0 || dataOut != 0)) {
      ThroughPutController.addThroughput(messageIn, messageOut, dataIn, dataOut);
      messageIn = 0;
      messageOut = 0;
      dataIn = 0;
      dataOut = 0;
    }
    super.onPingTimer(t);
  }
}


class ThroughPutController{
  static BrokerNode messagesOutPerSecond;
  static BrokerNode dataOutPerSecond;
  static BrokerNode messagesInPerSecond;
  static BrokerNode dataInPerSecond;
  static void initNodes(NodeProvider provider){
    messagesOutPerSecond = new BrokerNode("/sys/messagesOutPerSecond", provider)..configs[r"$type"] = "number";
    messagesInPerSecond = new BrokerNode("/sys/messagesInPerSecond", provider)..configs[r"$type"] = "number";
    
    dataOutPerSecond = new BrokerNode("/sys/dataOutPerSecond", provider)..configs[r"$type"] = "number";
    dataInPerSecond = new BrokerNode("/sys/dataInPerSecond", provider)..configs[r"$type"] = "number";
    changeValue();
    WebSocketConnection.throughputEnabled = true;
  }
  static int lastMessageIn = 0;
  static int lastDataIn = 0;
  static int lastMessageOut = 0;
  static int lastDataOut = 0;
  
  static int lastTs = -1;
  
  static addThroughput(int msgIn, int msgOut, int dataIn, int dataOut) {
    lastMessageIn += msgIn;
    lastDataIn += dataIn;
    lastMessageOut += msgOut;
    lastDataOut += dataOut;
    DsTimer.timerOnceBefore(changeValue, 5000);
  }
  static void changeValue() {
    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    num del = ts - lastTs;
    if (del > 5000) del = 5000;
    else if (del < 1) del = 1;
    del /= 1000.0;
    messagesInPerSecond.updateValue(lastMessageIn/del, force:true);
    dataInPerSecond.updateValue(lastDataIn/del, force:true);
    messagesOutPerSecond.updateValue(lastMessageOut/del, force:true);
    dataOutPerSecond.updateValue(lastDataOut/del, force:true);

    lastMessageIn = 0;
    lastDataIn = 0;
    lastMessageOut = 0;
    lastDataOut = 0;
    lastTs = ts;
  }
}

//class ThroughPutNode extends LocalNodeImpl {
//  static ThroughPutNode instance;
//  final NodeProvider provider;
//  int throughput = 0;
//  ThroughPutNode(String path, this.provider) : super(path) {
//    instance = this;
//    configs[r"$type"] = "number";
//    // TODO(rinick): load initial value from encrypted file
//    throughput = 0;
//    updateValue(0);
//  }
//
//  void addThroughput(int size) {
//    throughput += size;
//    DsTimer.timerOnceBefore(changeValue, 5000);
//  }
//
//  void changeValue() {
//    updateValue(throughput);
//  }
//}
