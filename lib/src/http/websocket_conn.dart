library dslink.http.websocket;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../../common.dart';
import '../../utils.dart';

class WebSocketConnection implements ServerConnection, ClientConnection {
  PassiveChannel _responderChannel;

  ConnectionChannel get responderChannel => _responderChannel;

  PassiveChannel _requesterChannel;

  ConnectionChannel get requesterChannel => _requesterChannel;

  Completer<ConnectionChannel> onRequestReadyCompleter =
      new Completer<ConnectionChannel>();

  Future<ConnectionChannel> get onRequesterReady =>
      onRequestReadyCompleter.future;

  Completer<bool> _onDisconnectedCompleter = new Completer<bool>();

  Future<bool> get onDisconnected => _onDisconnectedCompleter.future;

  final ClientLink clientLink;

  final WebSocket socket;

  /// clientLink is not needed when websocket works in server link
  WebSocketConnection(this.socket,
      {this.clientLink, bool enableTimeout: false}) {
    _responderChannel = new PassiveChannel(this, true);
    _requesterChannel = new PassiveChannel(this, true);
    socket.listen(onData, onDone: _onDone);
    socket.add(fixedBlankData);
    if (enableTimeout) {
      pingTimer = new Timer.periodic(new Duration(seconds: 20), onPingTimer);
    }
    // TODO(rinick): when it's used in client link, wait for the server to send {allowed} before complete this
  }

  Timer pingTimer;
  int pingCount = 0;

  /// set to true when data is sent, reset the flag every 20 seconds
  /// since the previous ping message will cause the next 20 seoncd to have a message
  /// max interval between 2 ping messages is 40 seconds
  bool _dataSent = false;

  /// add this count every 20 seconds, set to 0 when receiving data
  /// when the count is 3, disconnect the link (>=60 seconds)
  int _dataReceiveCount = 0;

  int throughput = 0;

  void onPingTimer(Timer t) {
    if (_dataReceiveCount >= 3) {
      this.close();
      return;
    }

    _dataReceiveCount++;

    if (_dataSent) {
      _dataSent = false;
      return;
    }
    if (_serverCommand == null) {
      _serverCommand = {};
    }
    _serverCommand['ping'] = ++pingCount;
    requireSend();
  }

  void requireSend() {
    DsTimer.callLaterOnce(_send);
  }

  /// special server command that need to be merged into message
  /// now only 2 possible value, salt, allowed
  Map _serverCommand;

  /// add server command, will be called only when used as server connection
  void addServerCommand(String key, Object value) {
    if (_serverCommand == null) {
      _serverCommand = {};
    }
    _serverCommand[key] = value;
    DsTimer.callLaterOnce(_send);
  }

  BinaryInCache binaryInCache = new BinaryInCache();
  void onData(dynamic data) {
    if (_onDisconnectedCompleter.isCompleted) {
      return;
    }
    logger.finest("begin WebSocketConnection.onData");
    if (!onRequestReadyCompleter.isCompleted) {
      onRequestReadyCompleter.complete(_requesterChannel);
    }
    _dataReceiveCount = 0;
    Map m;
    if (data is List<int>) {
      throughput += data.length;
      if (data.length != 0 && data[0] == 0) {
        logger.finest(" receive binary length ${data.length}");
        // binary channel
        binaryInCache.receiveData(data);
        return;
      }
      try {
        m = DsJson.decodeFrame(UTF8.decode(data), binaryInCache);
        logger.fine("WebSocket JSON (bytes): ${m}");
      } catch (err, stack) {
        logger.fine(
            "Failed to decode JSON bytes in WebSocket Connection", err, stack);
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
    } else if (data is String) {
      throughput += data.length;
      try {
        m = DsJson.decodeFrame(data, binaryInCache);
        logger.fine("WebSocket JSON: ${m}");
      } catch (err) {
        logger.severe("Failed to decode JSON from WebSocket Connection", err);
        close();
        return;
      }
      if (m['salt'] is String && clientLink != null) {
        clientLink.updateSalt(m['salt']);
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

    logger.finest("end WebSocketConnection.onData");
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
      addData(m);
      _dataSent = true;
    }
  }

  BinaryOutCache binaryOutCache = new BinaryOutCache();
  void addData(Map m) {
    String json = DsJson.encodeFrame(m, binaryOutCache);
    if (binaryOutCache.hasData) {
      logger.finest("send binary");
      socket.add(binaryOutCache.export());
    }
    logger.finest('send: $json');
    throughput += json.length;
    socket.add(json);
  }

  void _onDone() {
    logger.fine("socket disconnected");
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
      _responderChannel.onDisconnectController.complete(_responderChannel);
    }
    if (!_onDisconnectedCompleter.isCompleted) {
      _onDisconnectedCompleter.complete(false);
    }
    if (pingTimer != null) {
      pingTimer.cancel();
    }
  }

  void close() {
    if (socket.readyState == WebSocket.OPEN ||
        socket.readyState == WebSocket.CONNECTING) {
      socket.close();
    }
    _onDone();
  }
}
