part of dslink.common;

abstract class DsConnectionHandler {
  DsConnection _conn;
  StreamSubscription _connListener;
  StreamSubscription _beforeSendListener;
  DsConnection get connection => _conn;
  void set connection(DsConnection conn) {
    if (_connListener != null) {
      _connListener.cancel();
      _connListener = null;
      _onDisconnected(_conn);
    }
    _conn = conn;
    _connListener = _conn.onReceive.listen(onData);
    _conn.onDisconnected.then(_onDisconnected);
    // resend all requests after a connection
    onReconnected();
  }
  void _onDisconnected(DsConnection conn) {
    if (_conn == conn) {
      if (_connListener != null) {
        _connListener.cancel();
        _connListener = null;
      }
      //TODO clean up
      // send error and close all requests except the subscription and list requests
      _conn = null;
    }
  }
  void onDisconnected();
  void onReconnected();
  void onData(Map m);
  
  
  List _toSendList = [];
  void addToSendList(Map m){
    if (!_pendingSend && _conn != null) {
      _conn.sendWhenReady(_doSend);
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
      _conn.sendWhenReady(_doSend);
      _pendingSend = true;
    }
  }
  bool _pendingSend = false;
  /// gather all the changes from 
  Map _doSend(){
    _pendingSend = false;
    var processors = _processors;
    _processors = [];
    for (var proc in processors) {
      proc();
    }
    Map rslt = prepareData(_toSendList);
    _toSendList = null;
    return rslt;
  }
  Map prepareData(List<Map> datas);
}
