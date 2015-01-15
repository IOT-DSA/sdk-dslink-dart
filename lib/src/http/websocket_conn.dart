library dslink.http.websocket;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../../common.dart';
import '../../utils.dart';

class DsWebSocketConnection implements DsServerConnection, DsClientConnection {
  DsPassiveChannel _responderChannel;
  DsConnectionChannel get responderChannel => _responderChannel;

  DsPassiveChannel _requesterChannel;
  DsConnectionChannel get requesterChannel => _requesterChannel;

  Completer<DsConnectionChannel> _onRequestReadyCompleter = new Completer<DsConnectionChannel>();
  Future<DsConnectionChannel> get onRequesterReady => _onRequestReadyCompleter.future;

  final DsClientSession clientSession;

  final WebSocket socket;
  /// clientSession is not needed when websocket works in server session
  DsWebSocketConnection(this.socket, {this.clientSession}) {
    _responderChannel = new DsPassiveChannel(this);
    _requesterChannel = new DsPassiveChannel(this);
    socket.listen(_onData, onDone: _onDone);
    // TODO, when it's used in client session, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));
  }

  void requireSend() {
    DsTimer.callLaterOnce(_send);
  }

  Map _serverCommand;
  void addServerCommand(String key, Object value) {
    if (_serverCommand == null) {
      _serverCommand = {};
    }
    _serverCommand[key] = value;
    DsTimer.callLaterOnce(_send);
  }
  void _onData(dynamic data) {
    print('onData: $data');
    if (data is String) {
      Map m;
      try {
        m = JSON.decode(data);
      } catch (err) {
        close();
        return;
      }
      if (m['responses'] is List) {
        // send responses to requester channel
        _requesterChannel.onReceiveController.add(m['responses']);
      }
      if (m['requests'] is List) {
        // send requests to responder channel
        _responderChannel.onReceiveController.add(m['requests']);
      }

    }
  }
  void _send() {
    bool needSend = false;
    Map m;
    if (_serverCommand != null) {
      m = _serverCommand;
      _serverCommand = null;
      needSend = true;
    } else {
      m = {};
    }
    if (_responderChannel.getData != null) {
      List rslt = _responderChannel.getData();
      if (rslt != null && rslt.length != 0) {
        m['responses'] = rslt;
        needSend = true;
      }
    }
    if (_requesterChannel.getData != null) {
      List rslt = _requesterChannel.getData();
      if (rslt != null && rslt.length != 0) {
        m['requests'] = rslt;
        needSend = true;
      }
    }
    if (needSend) {
      print('send: $m');
      socket.add(JSON.encode(m));
    }
  }
  void _onDone() {
    if (!_requesterChannel.onReceiveController.isClosed) {
      _requesterChannel.onReceiveController.close();
    }
    if (!_requesterChannel.onDisconnectController.isCompleted) {
      _requesterChannel.onDisconnectController.complete(_requesterChannel);
    }
    if (!_responderChannel.onReceiveController.isClosed) {
      _responderChannel.onReceiveController.close();
    }
    if (!_responderChannel.onDisconnectController.isCompleted) {
      _responderChannel.onDisconnectController.complete(_requesterChannel);
    }
  }

  void close() {
    if (socket.readyState == WebSocket.OPEN || socket.readyState == WebSocket.CONNECTING) {
      socket.close();
    }
    _onDone();
  }
}
