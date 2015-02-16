part of dslink.browser_client;

class WebSocketConnection implements ClientConnection {
  PassiveChannel _responderChannel;
  ConnectionChannel get responderChannel => _responderChannel;

  PassiveChannel _requesterChannel;
  ConnectionChannel get requesterChannel => _requesterChannel;

  Completer<ConnectionChannel> _onRequestReadyCompleter = new Completer<ConnectionChannel>();
  Future<ConnectionChannel> get onRequesterReady => _onRequestReadyCompleter.future;

  final ClientLink clientLink;

  final WebSocket socket;
  /// clientLink is not needed when websocket works in server link
  WebSocketConnection(this.socket, {this.clientLink}) {
    socket.binaryType = 'arraybuffer';
    _responderChannel = new PassiveChannel(this);
    _requesterChannel = new PassiveChannel(this);
    socket.onMessage.listen(_onData, onDone: _onDone);
    socket.onClose.listen(_onDone);
    socket.onOpen.listen(_onOpen);
    // TODO, when it's used in client link, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));
  }

  void requireSend() {
    DsTimer.callLaterOnce(_send);
  }
  void _onOpen(Event e) {
    requireSend();
  }
  void _onData(MessageEvent e) {
    print('onData:');
    Map m;
    if (e.data is ByteBuffer) {
      try {
        // TODO JSONUTF8Decoder
        m = JSON.decode(UTF8.decode((e.data as ByteBuffer).asInt8List()));
        print('$m');
      } catch (err) {
        print(err);
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
    } else if (e.data is String) {
      try {
        m = JSON.decode(e.data);
        print('$m');
      } catch (err) {
        print(err);
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
    if (socket.readyState != WebSocket.OPEN) {
      return;
    }
    print('browser sending');
    bool needSend = false;
    Map m = {};

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
//      Uint8List list = jsonUtf8Encoder.convert(m);
//      socket.sendTypedData(list);
      socket.send(JSON.encode(m));
    }
  }

  void _onDone([Object o]) {
    print('socket disconnected1');
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
  }

  void close() {
    if (socket.readyState == WebSocket.OPEN || socket.readyState == WebSocket.CONNECTING) {
      socket.close();
    }
    _onDone();
  }
}
