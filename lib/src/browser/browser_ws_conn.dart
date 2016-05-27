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

    _queue = new DSPacketQueue(
      DSPacketQueueMode.store,
      handleNewPacketStore,
      handleAckPacket,
      handleMsgPacket
    );

    socket.onMessage.listen(_onData, onDone: _onDone);
    socket.onClose.listen(_onDone);
    socket.onOpen.listen(_onOpen);
    // TODO, when it's used in client link, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));

    pingTimer = new Timer.periodic(const Duration(seconds: 20), onPingTimer);
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
    logger.info("Connected");
    _opened = true;
    if (onConnect != null) {
      onConnect();
    }
    _responderChannel.updateConnect();
    _requesterChannel.updateConnect();
    socket.sendByteBuffer(new Uint8List(0).buffer);
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

  DSPacketReader _reader = new DSPacketReader();
  DSPacketWriter _writer = new DSPacketWriter();
  DSPacketQueue _queue;

  void handleNewPacketStore(DSPacketStore store) {
    store.handler = handlePacketDelivery;
  }

  void handlePacketDelivery(DSPacketStore store, DSNormalPacket _) {
    if (store.isComplete) {
      var pkt = store.formNewPacket();
      if (pkt is DSResponsePacket) {
        _requesterChannel.onReceiveController.add(pkt);
      } else if (pkt is DSRequestPacket) {
        _responderChannel.onReceiveController.add(pkt);
      }
      store.drop();
    }
  }

  void handleAckPacket(DSAckPacket pkt) {
    ack(pkt.ackId);
  }

  void handleMsgPacket(DSMsgPacket pkt) {
    var id = pkt.ackId;
    if (id != null) {
      addConnCommand("ack", id);
    }
  }

  void _onData(MessageEvent e) {
    _dataReceiveCount = 0;

    if (e.data is ByteBuffer) {
      try {
        Uint8List bytes = (e.data as ByteBuffer).asUint8List();

        List<DSPacket> packets = _reader.read(bytes);

        if (logger.isLoggable(Level.FINEST)) {
          for (DSPacket pkt in packets) {
            logger.finest("Receive: ${pkt}");
          }
        }

        _queue.handleAll(packets);
      } catch (e, stack) {
        logger.warning("Failed to handle frame", e, stack);
      }
    }
  }

  int nextMsgId = 1;

  bool _sending = false;

  void _send() {
    if (socket.readyState != WebSocket.OPEN) {
      return;
    }

    _sending = false;
    bool needSend = false;

    var pkts = <DSPacket>[];

    if (_msgCommand != null && _msgCommand["ack"] is int) {
      var pkt = new DSAckPacket();
      pkt.ackId = _msgCommand["ack"];
      _msgCommand = null;
      if (logger.isLoggable(Level.FINEST)) {
        logger.finest("Send: ${pkt}");
      }
      pkt.writeTo(_writer);
      addData(_writer.done());
      requireSend();
      return;
    }

    var pendingAck = <ConnectionProcessor>[];
    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    ProcessorResult rslt = _responderChannel.getSendingData(ts, nextMsgId);
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        needSend = true;

        for (DSPacket pkt in rslt.messages) {
          if (pkt is DSNormalPacket && pkt.isLargePayload()) {
            pkts.addAll(pkt.split());
          } else {
            pkts.add(pkt);
          }
        }
      }

      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    rslt = _requesterChannel.getSendingData(ts, nextMsgId);

    if (rslt != null) {
      if (rslt.messages.length > 0) {
        needSend = true;

        for (DSPacket pkt in rslt.messages) {
          if (pkt is DSNormalPacket && pkt.isLargePayload()) {
            pkts.addAll(pkt.split());
          } else {
            pkts.add(pkt);
          }
        }
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
        var pkt = new DSMsgPacket();
        pkt.ackId = nextMsgId;

        // Consider where the msg packet is, adding it last is best
        // if we hit a frame limit.
        pkts.add(pkt);
        if (nextMsgId < 0x7FFFFFFF) {
          ++nextMsgId;
        } else {
          nextMsgId = 1;
        }
      }

      bool needsWrite = true;

      for (var pkt in pkts) {
        needsWrite = true;

        if (logger.isLoggable(Level.FINEST)) {
          logger.finest("Send: ${pkt}");
        }

        pkt.writeTo(_writer);

        if (_writer.currentLength > 76800) { // 75KB frame limit
          logger.finer("Frame limit hit, sending packets.");
          addData(_writer.done());
          needsWrite = false;
        }
      }

      if (needsWrite) {
        addData(_writer.done());
      }

      _dataSent = true;
    }
  }

  void addData(Uint8List data) {
    socket.sendTypedData(data);
  }

  bool _authError = false;
  void _onDone([Object o]) {
    if (o is CloseEvent) {
      CloseEvent e = o;
      if (e.code == 1006) {
        _authError = true;
      }
    }

    logger.fine("Disconnected");

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
