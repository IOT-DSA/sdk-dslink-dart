part of dslink.browser_client;

class WebSocketConnection extends Connection {
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

  Function onConnect;

  /// clientLink is not needed when websocket works in server link
  WebSocketConnection(this.socket, this.clientLink, {this.onConnect}) {
    socket.binaryType = 'arraybuffer';
    _responderChannel = new PassiveChannel(this);
    _requesterChannel = new PassiveChannel(this);
    socket.onMessage.listen(_onData, onDone: _onDone);
    socket.onClose.listen(_onDone);
    socket.onOpen.listen(_onOpen);
    // TODO, when it's used in client link, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));

    pingTimer = new Timer.periodic(new Duration(seconds: 20), onPingTimer);
  }

  Timer pingTimer;
  bool _dataSent = false;

  /// add this count every 20 seconds, set to 0 when receiving data
  /// when the count is 3, disconnect the link
  int _dataReceiveCount = 0;

  void onPingTimer(Timer t) {
    if (_dataReceiveCount >= 3) {
      this._onDone();
      return;
    }
    _dataReceiveCount++;

    if (_dataSent) {
      _dataSent = false;
      return;
    }
    addConnCommand(null, null);
  }

  void requireSend() {
    if (!_sending) {
      _sending = true;
      DsTimer.callLater(_send);
    }
  }

  bool _opened = false;
  void _onOpen(Event e) {
    logger.info('Connected');
    _opened = true;
    if (onConnect != null) {
      onConnect();
    }
    _responderChannel.updateConnect();
    _requesterChannel.updateConnect();
    socket.sendString('{}');
    requireSend();
  }
  
  /// special server command that need to be merged into message
  /// now only 2 possible value, salt, allowed
  Map _msgCommand;

  /// add server command, will be called only when used as server connection
  void addConnCommand(String key, Object value) {
    if (_msgCommand == null) {
      _msgCommand = {};
    }
    if (key != null) {
      _msgCommand[key] = value;
    }
    requireSend();
  }

  

  BinaryInCache binaryInCache = new BinaryInCache();
  void _onData(MessageEvent e) {
    logger.fine('onData:');
    _dataReceiveCount = 0;
    Map m;
    if (e.data is ByteBuffer) {
      try {
        Uint8List bytes = (e.data as ByteBuffer).asUint8List();
        if (bytes.length != 0 && bytes[0] == 0) {
          // binary channel
          binaryInCache.receiveData(bytes);
          return;
        }

        // TODO(rick): JSONUtf8Decoder
        m = DsJson.decodeFrame(UTF8.decode(bytes), binaryInCache);
        logger.fine('$m');

        if (m['salt'] is String) {
          clientLink.updateSalt(m['salt']);
        }
        bool needAck = false;
        if (m['responses'] is List && (m['responses'] as List).length > 0) {
          needAck = true;
          // send responses to requester channel
          _requesterChannel.onReceiveController.add(m['responses']);
        }

        if (m['requests'] is List && (m['requests'] as List).length > 0) {
          needAck = true;
          // send requests to responder channel
          _responderChannel.onReceiveController.add(m['requests']);
        }
        if (m['ack'] is int) {
          ack(m['ack']);
        }
        if (needAck) {
          Object msgId = m['msg'];
          if (msgId != null) {
            addConnCommand('ack', msgId);
          }
        }
      } catch (err, stack) {
        logger.severe("error in onData", err, stack);
        close();
        return;
      }
    } else if (e.data is String) {
      try {
        m = DsJson.decodeFrame(e.data, binaryInCache);
        logger.fine('$m');

        bool needAck = false;
        if (m['responses'] is List && (m['responses'] as List).length > 0) {
          needAck = true;
          // send responses to requester channel
          _requesterChannel.onReceiveController.add(m['responses']);
        }

        if (m['requests'] is List && (m['requests'] as List).length > 0) {
          needAck = true;
          // send requests to responder channel
          _responderChannel.onReceiveController.add(m['requests']);
        }
        if (m['ack'] is int) {
          ack(m['ack']);
        }
        if (needAck) {
          Object msgId = m['msg'];
          if (msgId != null) {
            addConnCommand('ack', msgId);
          }
        }
      } catch (err) {
        logger.severe(err);
        close();
        return;
      }
    }
  }

  BinaryOutCache binaryOutCache = new BinaryOutCache();
  
  int msgId = 0;
  
  bool _sending = false;
  void _send() {
    _sending = false;
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

    List pendingAck = [];
    ProcessorResult rslt = _responderChannel.getSendingData();
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m['responses'] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    rslt = _requesterChannel.getSendingData();
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m['requests'] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    
    if (needSend) {
      if (pendingAck.length > 0) {
        pendingAcks.add(new ConnectionAckGroup(msgId, pendingAck));
      }
      m['msg'] = msgId++;
      logger.fine('send: $m');
//      Uint8List list = jsonUtf8Encoder.convert(m);
//      socket.sendTypedData(list);
      String json = DsJson.encodeFrame(m, binaryOutCache);
      if (binaryOutCache.hasData) {
        socket.sendByteBuffer(binaryOutCache.export().buffer);
      }
      socket.send(json);
      _dataSent = true;
    }
  }

  bool _authError = false;
  void _onDone([Object o]) {
    if (o is CloseEvent) {
      CloseEvent e = o;
      if (e.code == 1006) {
        _authError = true;
      }
    }

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
