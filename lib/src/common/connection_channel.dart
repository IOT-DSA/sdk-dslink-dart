part of dslink.common;

class PassiveChannel implements ConnectionChannel {
  final StreamController<List> onReceiveController =
      new StreamController<List>();
  Stream<List> get onReceive => onReceiveController.stream;

  List<Function> _processors = [];

  final Connection conn;

  PassiveChannel(this.conn, [this.connected = false]) {}

  Function getData;
  void sendWhenReady(List getData()) {
    this.getData = getData;
    conn.requireSend();
  }

  bool _isReady = false;
  bool get isReady => _isReady;
  void set isReady(bool val) {
    _isReady = val;
  }

  bool connected = true;

  final Completer<ConnectionChannel> onDisconnectController =
      new Completer<ConnectionChannel>();
  Future<ConnectionChannel> get onDisconnected => onDisconnectController.future;

  final Completer<ConnectionChannel> onConnectController =
      new Completer<ConnectionChannel>();
  Future<ConnectionChannel> get onConnected => onConnectController.future;

  void updateConnect() {
    if (connected) return;
    connected = true;
    onConnectController.complete(this);
  }
}
