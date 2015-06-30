part of dslink.browser_client;

/// a client link for both http and ws
class BrowserUserLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  String session = DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16);
  final Requester requester;
  final Responder responder;

  final ECDH nonce = const DummyECDH();
  PrivateKey privateKey;

  WebSocketConnection _wsConnection;
  HttpBrowserConnection _httpConnection;

  static const Map<String, int> saltNameMap = const {'salt': 0, 'saltS': 1,};

  updateSalt(String salt, [int saltId = 0]) {
    // TODO: implement updateSalt
  }

  String wsUpdateUri;
  String httpUpdateUri;

  BrowserUserLink(
      {NodeProvider nodeProvider,
      bool isRequester: true,
      bool isResponder: true,
      this.wsUpdateUri,
      this.httpUpdateUri})
      : requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null)
            ? new Responder(nodeProvider)
            : null {
    if (wsUpdateUri.startsWith('http')) {
      wsUpdateUri = 'ws${wsUpdateUri.substring(4)}';
    }
  }

  void connect() {
    lockCryptoProvider();
    initWebsocket(false);
    //initHttp();
  }

  int _wsDelay = 1;
  initWebsocket([bool reconnect = true]) {
    if (reconnect && _httpConnection == null) {
      initHttp();
    }
    var socket = new WebSocket('$wsUpdateUri?session=$session');
    _wsConnection = new WebSocketConnection(socket, this);

    if (responder != null) {
      responder.connection = _wsConnection.responderChannel;
    }

    if (requester != null) {
      _wsConnection.onRequesterReady.then((channel) {
        requester.connection = channel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      });
    }
    _wsConnection.onDisconnected.then((connection) {
      logger.info('Disconnected');
      if (_wsConnection._opened) {
        _wsDelay = 1;
        initWebsocket(false);
      } else if (reconnect) {
        DsTimer.timerOnceAfter(initWebsocket, _wsDelay * 1000);
        if (_wsDelay < 60) _wsDelay++;
      } else {
        initHttp();
        _wsDelay = 5;
        DsTimer.timerOnceAfter(initWebsocket, 5000);
      }
    });
  }

  initHttp() {
    _httpConnection = new HttpBrowserConnection(
        '$httpUpdateUri?session=$session', this, '0', '0', true);

    if (responder != null) {
      responder.connection = _httpConnection.responderChannel;
    }

    if (requester != null) {
      _httpConnection.onRequesterReady.then((channel) {
        requester.connection = channel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      });
    }
    _httpConnection.onDisconnected.then((bool authFailed) {
      _httpConnection = null;
      if (authFailed) {
        DsTimer.timerCancel(initWebsocket);
        connect();
      } else {
        // reconnection of websocket should handle this case
      }
    });
  }
}
