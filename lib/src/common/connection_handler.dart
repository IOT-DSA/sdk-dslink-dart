part of dslink.common;

abstract class ConnectionHandler {
  ConnectionChannel _conn;
  StreamSubscription _connListener;
  StreamSubscription _beforeSendListener;
  ConnectionChannel get connection => _conn;

  set connection(ConnectionChannel conn) {
    if (_connListener != null) {
      _connListener.cancel();
      _connListener = null;
      _onDisconnected(_conn);
    }
    _conn = conn;
    _connListener = _conn.onReceive.listen(onData);
    _conn.onDisconnected.then(_onDisconnected);
    // resend all requests after a connection
    if (_conn.connected) {
      onReconnected();
    } else {
      _conn.onConnected.then((conn)=>onReconnected());
    }
    
  }

  void _onDisconnected(ConnectionChannel conn) {
    if (_conn == conn) {
      if (_connListener != null) {
        _connListener.cancel();
        _connListener = null;
      }
      onDisconnected();
      _conn = null;
    }
  }

  void onDisconnected();
  void onReconnected() {
    if (_pendingSend) {
      _conn.sendWhenReady(doSend);
    }
  }
  void onData(List m);

  List _toSendList = [];

  void addToSendList(Map m) {
    _toSendList.add(m);
    if (!_pendingSend && _conn != null) {
      _conn.sendWhenReady(doSend);
      _pendingSend = true;
    }
  }

  List<Function> _processors = [];

  /// a processor function that's called just before the data is sent
  /// same processor won't be added to the list twice
  /// inside processor, send() data that only need to appear once per data frame
  void addProcessor(void processor()) {
    if (!_processors.contains(processor)) {
      _processors.add(processor);
    }

    if (!_pendingSend && _conn != null) {
      _conn.sendWhenReady(doSend);
      _pendingSend = true;
    }
  }

  bool _pendingSend = false;

  /// gather all the changes from
  List doSend() {
    _pendingSend = false;
    var processors = _processors;
    _processors = [];
    for (var proc in processors) {
      proc();
    }
    List rslt = _toSendList;
    _toSendList = [];
    return rslt;
  }
}
