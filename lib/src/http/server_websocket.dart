part of dslink.server;

class ServerWebSocket extends WebSocketConnection {
  ServerWebSocket(WebSocket socket, {bool enableTimeout: false})
      : super(socket, enableTimeout: enableTimeout);
  void onPingTimer(Timer t) {
    if (throughput > 0) {
      ThroughPutNode.instance.addThroughput(throughput);
      throughput = 0;
    }
    super.onPingTimer(t);
  }
}

class ThroughPutNode extends LocalNodeImpl {
  static ThroughPutNode instance = new ThroughPutNode("/sys/throughput");

  int throughput = 0;

  ThroughPutNode(String path) : super(path) {
    configs[r"$type"] = "number";
    // TODO(rinick): load initial value from encrypted file
    throughput = 0;
    updateValue(0);
  }

  void addThroughput(int size) {
    throughput += size;
    DsTimer.timerOnceBefore(changeValue, 60000);
  }

  void changeValue() {
    updateValue(throughput);
  }
}
