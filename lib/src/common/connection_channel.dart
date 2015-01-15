part of dslink.common;

class DsPassiveChannel implements DsConnectionChannel{
  final StreamController<List> onReceiveController = new StreamController<List>();
  Stream<List> get onReceive => onReceiveController.stream;

  List<Function> _processors = [];

  final DsConnection conn;
  DsPassiveChannel(this.conn) {
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

  final Completer<DsConnectionChannel> onDisconnectController = new Completer<DsConnectionChannel>();
  Future<DsConnectionChannel> get onDisconnected => onDisconnectController.future;

}