part of dslink.common;

abstract class StreamConnectionAdapter {
  Future<String> auth();
  Future<String> salts();
  Stream receive();
  Future send(dynamic data);
  Future onDisconnected();
  Future close([int code]);
  Future<String> getMetadata(String name);
}

class StreamConnection implements ClientConnection, ServerConnection {
  final StreamConnectionAdapter adapter;

  ClientLink clientLink;

  PassiveChannel _responderChannel;
  ConnectionChannel get responderChannel => _responderChannel;
  PassiveChannel _requesterChannel;
  ConnectionChannel get requesterChannel => _requesterChannel;
  Completer<ConnectionChannel> onRequestReadyCompleter = new Completer<ConnectionChannel>();
  Future<ConnectionChannel> get onRequesterReady => onRequestReadyCompleter.future;
  Completer<bool> _onDisconnectedCompleter = new Completer<bool>();
  Future<bool> get onDisconnected => _onDisconnectedCompleter.future;

  StreamConnection(this.adapter, {this.clientLink, bool enableTimeout: false}) {
    _responderChannel = new PassiveChannel(this, true);
    _requesterChannel = new PassiveChannel(this, true);
    adapter.receive().listen(onData, onDone: _onDone);
    adapter.send(fixedBlankData);
    if (enableTimeout) {
      pingTimer = new Timer.periodic(new Duration(seconds: 20), onPingTimer);
    }
  }

  Timer pingTimer;
  int pingCount = 0;
  bool _dataSent = false;
  int _dataReceiveCount = 0;

  void onPingTimer(Timer t) {
    if (_dataReceiveCount >= 3) {
      this.close();
      return;
    }
    _dataReceiveCount ++;

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

  Map _serverCommand;

  void addServerCommand(String key, Object value) {
    if (_serverCommand == null) {
      _serverCommand = {};
    }
    _serverCommand[key] = value;
    DsTimer.callLaterOnce(_send);
  }

  void onData(dynamic data) {
    if (_onDisconnectedCompleter.isCompleted) {
      return;
    }
    logger.finest("begin StreamConnection.onData");
    if (!onRequestReadyCompleter.isCompleted) {
      onRequestReadyCompleter.complete(_requesterChannel);
    }
    _dataReceiveCount = 0;
    Map m;
    if (data is List<int>) {
      try {
        m = DsJson.decode(UTF8.decode(data));
        logger.fine("Stream JSON (bytes): ${m}");
      } catch (err, stack) {
        logger.fine("Failed to decode JSON bytes in Stream Connection", err, stack);
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
      try {
        m = DsJson.decode(data);
        logger.fine("Stream JSON: ${m}");
      } catch (err, stack) {
        logger.severe("Failed to decode JSON from Stream Connection", err, stack);
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

    logger.finest("end StreamConnection.onData");
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
      logger.fine('send: $m');
      addData(m);
      _dataSent = true;
    }
  }

  void addData(Map m) {
    adapter.send(DsJson.encode(m));
  }

  void _onDone() {
    logger.fine("Stream disconnected");
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

  @override
  void close() {
    adapter.close().then((_) => _onDone());
  }
}
