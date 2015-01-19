part of dslink.common;

class PassiveChannel implements ConnectionChannel {
  final StreamController<List> onReceiveController = new StreamController<List>();
  Stream<List> get onReceive => onReceiveController.stream;

  List<Function> _processors = [];

  final Connection conn;

  PassiveChannel(this.conn) {
  }

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

  final Completer<ConnectionChannel> onDisconnectController = new Completer<ConnectionChannel>();
  Future<ConnectionChannel> get onDisconnected => onDisconnectController.future;
}
