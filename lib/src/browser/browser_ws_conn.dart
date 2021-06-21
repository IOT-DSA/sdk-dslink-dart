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
  WebSocketConnection(this.socket, this.clientLink, {
    this.onConnect,
    bool enableAck: false,
    DsCodec useCodec
  }) {
    if (useCodec != null) {
      codec = useCodec;
    }

    if (!enableAck) {
      nextMsgId = -1;
    }
    socket.binaryType = "arraybuffer";
    _responderChannel = new PassiveChannel(this);
    _requesterChannel = new PassiveChannel(this);
    socket.onMessage.listen(_onData, onDone: _onDone);
    socket.onClose.listen(_onDone);
    socket.onOpen.listen(_onOpen);
    // TODO, when it's used in client link, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));

    pingTimer = new Timer.periodic(const Duration(seconds: 20), onPingTimer);
  }

  Timer pingTimer;

  int _dataReceiveTs = new DateTime.now().millisecondsSinceEpoch;
  int _dataSentTs = new DateTime.now().millisecondsSinceEpoch;

  void onPingTimer(Timer t) {
    int currentTs = new DateTime.now().millisecondsSinceEpoch;
    if (currentTs - this._dataReceiveTs >= 65000) {
      // close the connection if no message received in the last 65 seconds
      close();
      return;
    }

    if (currentTs - this._dataSentTs > 21000) {
      // add message if no data was sent in the last 21 seconds
      this.addConnCommand(null, null);
    }
  }

  void requireSend() {
    if (!_sending) {
      _sending = true;
      DsTimer.callLater(_send);
    }
  }

  // sometimes setTimeout and setInterval is not run due to browser throttling
  checkBrowserThrottling() {
    int currentTs = new DateTime.now().millisecondsSinceEpoch;
    if (currentTs - this._dataSentTs > 25000) {
      logger.finest('Throttling detected');
      // timer is supposed to be run every 20 seconds, if that passes 25 seconds, force it to run
      this.onPingTimer(null);
      if (this._sending) {
        this._send();
      }
    }
  }

  bool _opened = false;
  bool get opened => _opened;

  void _onOpen(Event e) {
    logger.info("Connected");
    _opened = true;
    if (onConnect != null) {
      onConnect();
    }
    _responderChannel.updateConnect();
    _requesterChannel.updateConnect();
    socket.sendString("{}");
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

  void _onData(MessageEvent e) {
    logger.fine("onData:");
    this._dataReceiveTs = new DateTime.now().millisecondsSinceEpoch;
    Map m;
    if (e.data is ByteBuffer) {
      try {
        Uint8List bytes = (e.data as ByteBuffer).asUint8List();

        m = codec.decodeBinaryFrame(bytes);
        logger.fine("$m");
        checkBrowserThrottling();

        if (m["salt"] is String) {
          clientLink.updateSalt(m["salt"]);
        }
        bool needAck = false;
        if (m["responses"] is List && (m["responses"] as List).length > 0) {
          needAck = true;
          // send responses to requester channel
          _requesterChannel.onReceiveController.add(m["responses"]);
        }

        if (m["requests"] is List && (m["requests"] as List).length > 0) {
          needAck = true;
          // send requests to responder channel
          _responderChannel.onReceiveController.add(m["requests"]);
        }
        if (m["ack"] is int) {
          ack(m["ack"]);
        }
        if (needAck) {
          Object msgId = m["msg"];
          if (msgId != null) {
            addConnCommand("ack", msgId);
          }
        }
      } catch (err, stack) {
        logger.severe("error in onData", err, stack);
        close();
        return;
      }
    } else if (e.data is String) {
      try {
        m = codec.decodeStringFrame(e.data);
        logger.fine("$m");
        checkBrowserThrottling();

        bool needAck = false;
        if (m["responses"] is List && (m["responses"] as List).length > 0) {
          needAck = true;
          // send responses to requester channel
          _requesterChannel.onReceiveController.add(m["responses"]);
        }

        if (m["requests"] is List && (m["requests"] as List).length > 0) {
          needAck = true;
          // send requests to responder channel
          _responderChannel.onReceiveController.add(m["requests"]);
        }
        if (m["ack"] is int) {
          ack(m["ack"]);
        }
        if (needAck) {
          Object msgId = m["msg"];
          if (msgId != null) {
            addConnCommand("ack", msgId);
          }
        }
      } catch (err) {
        logger.severe(err);
        close();
        return;
      }
    }
  }

  int nextMsgId = 1;

  bool _sending = false;
  void _send() {
    _sending = false;
    if (socket.readyState != WebSocket.OPEN) {
      return;
    }
    logger.fine("browser sending");
    bool needSend = false;
    Map m;
    if (_msgCommand != null) {
      m = _msgCommand;
      needSend = true;
      _msgCommand = null;
    } else {
      m = {};
    }

    var pendingAck = <ConnectionProcessor>[];

    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    ProcessorResult rslt = _responderChannel.getSendingData(ts, nextMsgId);
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m["responses"] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    rslt = _requesterChannel.getSendingData(ts, nextMsgId);
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m["requests"] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }

    if (needSend) {
      if (nextMsgId != -1) {
        if (pendingAck.length > 0) {
          pendingAcks.add(new ConnectionAckGroup(nextMsgId, ts, pendingAck));
        }
        m["msg"] = nextMsgId;
        if (nextMsgId < 0x7FFFFFFF) {
          ++nextMsgId;
        } else {
          nextMsgId = 1;
        }
      }


      logger.fine("send: $m");
      var encoded = codec.encodeFrame(m);
      if (encoded is List<int>) {
        encoded = ByteDataUtil.list2Uint8List(encoded as List<int>);
      }
      try {
        socket.send(encoded);
      } catch (e) {
        logger.severe('Unable to send on socket', e);
        close();
      }
      _dataSentTs = new DateTime.now().millisecondsSinceEpoch;
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
