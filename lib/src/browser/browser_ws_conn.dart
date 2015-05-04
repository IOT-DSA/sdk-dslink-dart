part of dslink.browser_client;

class WebSocketConnection implements ClientConnection {
  PassiveChannel _responderChannel;

  ConnectionChannel get responderChannel => _responderChannel;

  PassiveChannel _requesterChannel;

  ConnectionChannel get requesterChannel => _requesterChannel;

  Completer<ConnectionChannel> _onRequestReadyCompleter =
  new Completer<ConnectionChannel>();

  Future<ConnectionChannel> get onRequesterReady =>
  _onRequestReadyCompleter.future;

  Completer<bool> _onDisconnectedCompleter = new Completer<bool>();
  Future<bool> get onDisconnected => _onDisconnectedCompleter.future;

  final ClientLink clientLink;

  final WebSocket socket;

  /// clientLink is not needed when websocket works in server link
  WebSocketConnection(this.socket, this.clientLink) {
    socket.binaryType = 'arraybuffer';
    _responderChannel = new PassiveChannel(this);
    _requesterChannel = new PassiveChannel(this);
    socket.onMessage.listen(_onData, onDone: _onDone);
    socket.onClose.listen(_onDone);
    socket.onOpen.listen(_onOpen);
    // TODO, when it's used in client link, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));

    pingTimer = new Timer.periodic(new Duration(seconds:20), onPingTimer);
  }

  Timer pingTimer;
  int pingCount = 0;
  bool _dataSent = false;

  /// add this count every 20 seconds, set to 0 when receiving data
  /// when the count is 3, disconnect the link
  int _dataReceiveCount = 0;

  void onPingTimer(Timer t){
    if (_dataReceiveCount >= 3) {
      this._onDone();
      return;
    }
    _dataReceiveCount ++;

    if (_dataSent) {
      _dataSent = false;
      return;
    }
    if (_msgCommand == null) {
      _msgCommand = {};
    }
    _msgCommand['ping'] = ++pingCount;
    requireSend();
  }
  Map _msgCommand;

  void requireSend() {
    DsTimer.callLaterOnce(_send);
  }
  bool _opened = false;
  void _onOpen(Event e) {
    _opened = true;
    _responderChannel.updateConnect();
    _requesterChannel.updateConnect();
    socket.sendString('{}');
    requireSend();
  }

  void _onData(MessageEvent e) {
    logger.fine('onData:');
    _dataReceiveCount = 0;
    Map m;
    if (e.data is ByteBuffer) {
      try {
        // TODO(rick): JSONUtf8Decoder
        m = DsJson.decode(UTF8.decode((e.data as ByteBuffer).asInt8List()));
        logger.fine('$m');

        if (m['salt'] is String) {
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
      } catch (err, stack) {
        logger.severe("error in onData", err, stack);
        close();
        return;
      }
    } else if (e.data is String) {
      try {
        m = DsJson.decode(e.data);
        logger.fine('$m');

        if (m['responses'] is List) {
          // send responses to requester channel
          _requesterChannel.onReceiveController.add(m['responses']);
        }

        if (m['requests'] is List) {
          // send requests to responder channel
          _responderChannel.onReceiveController.add(m['requests']);
        }
      } catch (err) {
        logger.severe(err);
        close();
        return;
      }
    }
  }

  void _send() {
    if (socket.readyState != WebSocket.OPEN) {
      return;
    }
    logger.fine('browser sending');
    bool needSend = false;
    Map m;
    if (_msgCommand != null) {
      m = _msgCommand;
      needSend = true;
      _msgCommand = null;
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
      logger.fine('send: $m');
//      Uint8List list = jsonUtf8Encoder.convert(m);
//      socket.sendTypedData(list);
      socket.send(DsJson.encode(m));
      _dataSent = true;
    }
  }

  bool _authError = false;
  void _onDone([Object o]) {
    logger.fine('socket disconnected');

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
      _onDisconnectedCompleter.complete(_authError);
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
