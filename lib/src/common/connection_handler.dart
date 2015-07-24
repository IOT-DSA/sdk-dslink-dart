part of dslink.common;

abstract class ConnectionProcessor {
  static const int WAITCOUNT = 4;
  
  void startSendingData(int waitingAckId, int currentTime);
  void ackReceived(int receiveAckId, int startTime, int currentTime);
}

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
      _conn.onConnected.then((conn) => onReconnected());
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
      _conn.sendWhenReady(this);
    }
  }

  void onData(List m);

  List<Map> _toSendList = <Map>[];

  void addToSendList(Map m) {
    _toSendList.add(m);
    if (!_pendingSend && _conn != null) {
      _conn.sendWhenReady(this);
      _pendingSend = true;
    }
  }

  List<ConnectionProcessor> _processors = [];

  /// a processor function that's called just before the data is sent
  /// same processor won't be added to the list twice
  /// inside processor, send() data that only need to appear once per data frame
  void addProcessor(ConnectionProcessor processor) {
    _processors.add(processor);
    if (!_pendingSend && _conn != null) {
      _conn.sendWhenReady(this);
      _pendingSend = true;
    }
  }

  bool _pendingSend = false;

  /// gather all the changes from
  ProcessorResult getSendingData(int currentTime, int waitingAckId) {
    _pendingSend = false;
    List<ConnectionProcessor> processors = _processors;
    _processors = [];
    for (ConnectionProcessor proc in processors) {
      proc.startSendingData(currentTime, waitingAckId);
    }
    List<Map> rslt = _toSendList;
    _toSendList = [];
    return new ProcessorResult(rslt, processors);
  }
}
