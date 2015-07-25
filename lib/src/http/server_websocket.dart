part of dslink.server;

class ServerWebSocket extends WebSocketConnection {
  ServerWebSocket(WebSocket socket, {bool enableTimeout: false, bool enableAck:false})
      : super(socket, enableTimeout: enableTimeout, enableAck:enableAck);
  void onPingTimer(Timer t) {
    if (throughput > 0) {
      ThroughPutNode.instance.addThroughput(throughput);
      throughput = 0;
    }
    super.onPingTimer(t);
  }
}

class ThroughPutNode extends LocalNodeImpl {
  static ThroughPutNode instance;
  final NodeProvider provider;
  int throughput = 0;
  ThroughPutNode(String path, this.provider) : super(path) {
    instance = this;
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
