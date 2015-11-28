part of dslink.browser_client;

/// a client link for both http and ws
class BrowserUserLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();

  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  static String session = DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16) +
      DSRandom.instance.nextUint16().toRadixString(16);
  final Requester requester;
  final Responder responder;

  final ECDH nonce = const DummyECDH();
  PrivateKey privateKey;

  WebSocketConnection _wsConnection;

  bool enableAck;

  static const Map<String, int> saltNameMap = const {"salt": 0, "saltS": 1,};

  updateSalt(String salt, [int saltId = 0]) {
    // TODO: implement updateSalt
  }

  String wsUpdateUri;
  String format = "json";

  BrowserUserLink({NodeProvider nodeProvider,
  bool isRequester: true,
  bool isResponder: true,
  this.wsUpdateUri,
  this.enableAck: false,
  String format})
      : requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null)
            ? new Responder(nodeProvider)
            : null {
    if (wsUpdateUri.startsWith("http")) {
      wsUpdateUri = "ws${wsUpdateUri.substring(4)}";
    }

    if (format != null) {
      this.format = format;
    }

    if (window.location.hash.contains("dsa_json")) {
      this.format = "json";
    }
  }

  void connect() {
    lockCryptoProvider();
    initWebsocket(false);
  }

  int _wsDelay = 1;

  initWebsocket([bool reconnect = true]) {
    var socket = new WebSocket("$wsUpdateUri?session=$session&format=$format");
    _wsConnection = new WebSocketConnection(
        socket, this, enableAck: enableAck, useCodec: DsCodec.getCodec(format));

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
      logger.info("Disconnected");
      if (_wsConnection._opened) {
        _wsDelay = 1;
        initWebsocket(false);
      } else if (reconnect) {
        DsTimer.timerOnceAfter(initWebsocket, _wsDelay * 1000);
        if (_wsDelay < 60) _wsDelay++;
      } else {
        _wsDelay = 5;
        DsTimer.timerOnceAfter(initWebsocket, 5000);
      }
    });
  }
}
