part of dslink.http_server;

class DsWebsocketConnection implements DsConnection {
  Stream<Map> get onReceive => null;

  List<Function> _processors = [];

  final WebSocket socket;

  DsWebsocketConnection(this.socket);

  void send(Map data) {

  }
  void addProcessor(void processor()) {
    if (_processors.contains(processor)) {
      _processors.add(processor);
    }
  }

  void _doSend() {
    var processors = _processors;
    _processors = [];
    for (Function processor in processors) {
      processor();
    }
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

  StreamController<DsConnection> _onBeforeSendController = new StreamController<DsConnection>();
  Stream<DsConnection> get onBeforeSend => _onBeforeSendController.stream;
}
