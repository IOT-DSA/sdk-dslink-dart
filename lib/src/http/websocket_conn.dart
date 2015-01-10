part of dslink.http_server;

class DsWebsocketConnection implements DsConnection {
  Stream<Map> get onReceive => null;

  List<Function> _processors = [];

  final WebSocket socket;
  DsWebsocketConnection(this.socket) {
  }

  void sendWhenReady(Map getData()) {
    // TODO: implement sendWhenReady
  }

  bool _isReady = false;
  bool get isReady => _isReady;
  void set isReady(bool val) {
    _isReady = val;
  }

  void close() {
    socket.close();
  }

  Completer<DsConnection> _onDisconnectController = new Completer<DsConnection>();
  Future<DsConnection> get onDisconnected => _onDisconnectController.future;

}
