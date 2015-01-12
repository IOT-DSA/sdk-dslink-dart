library dslink.http.websocket;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../../ds_common.dart';
import '../../utils.dart';


class DsWebsocketConnection implements DsConnection {
  StreamController<Map> _onReceiveController = new StreamController<Map>();
  Stream<Map> get onReceive => null;

  List<Function> _processors = [];

  final WebSocket socket;
  DsWebsocketConnection(this.socket) {
    socket.listen(_onData, onDone: _onDone);
  }
  Function _getData;
  void sendWhenReady(Map getData()) {
    _getData = getData;
    DsTimer.callLaterOnce(_send);
  }
  void _send() {
    if (_getData != null) {
      Map rslt = _getData();
      if (rslt != null) {
        print('sent:$rslt');
        socket.add(JSON.encode(rslt));
      }
    }
  }
  void _onData(dynamic data) {
    if (data is String) {
      Object m;
      try {
        m = JSON.decode(data);
      } catch (err) {
        return;
      }
      if (m is Map) {
        _onReceiveController.add(m);
      }
    }
  }
  void _onDone() {
    _onReceiveController.close();
    _onDisconnectController.complete(this);
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
