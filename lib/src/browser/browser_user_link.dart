part of dslink.browser_client;

/// a client link for both http and ws
class BrowserUserLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  String session = DSRandom.instance.nextUint16().toRadixString(16) + DSRandom.instance.nextUint16().toRadixString(16) + DSRandom.instance.nextUint16().toRadixString(16) + DSRandom.instance.nextUint16().toRadixString(16);
  final Requester requester;
  final Responder responder;

  final ECDH nonce = const DummyECDH();
  PrivateKey privateKey;

  Connection _connection;

  static const Map<String, int> saltNameMap = const {
    'salt': 0,
    'saltS': 1,
  };

  updateSalt(String salt, [bool shortPolling = false]) {
    // TODO: implement updateSalt
  }

  String wsUpdateUri;
  String httpUpdateUri;

  BrowserUserLink({NodeProvider nodeProvider, bool isRequester: true, bool isResponder: true, this.wsUpdateUri, this.httpUpdateUri})
      : requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null) ? new Responder(nodeProvider) : null {
    if (wsUpdateUri.startsWith('http')) {
      wsUpdateUri = 'ws${wsUpdateUri.substring(4)}';
    }
  }

  void connect() {
    initWebsocket();
    //initHttp();
  }

  initWebsocket() {
    var socket = new WebSocket('$wsUpdateUri?session=$session');
    _connection = new WebSocketConnection(socket, this);

    if (responder != null) {
      responder.connection = _connection.responderChannel;
    }

    if (requester != null) {
      _connection.onRequesterReady.then((channel) {
        requester.connection = channel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      });
    }
    _connection.onDisconnected.then((connection){initHttp();});
  }

  initHttp() {
    _connection = new HttpBrowserConnection('$httpUpdateUri?session=$session', this, '0', '0', true);

    if (responder != null) {
      responder.connection = _connection.responderChannel;
    }

    if (requester != null) {
      _connection.onRequesterReady.then((channel) {
        requester.connection = channel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
        
      });
    }
  }
}

class DummyECDH implements ECDH {

  const DummyECDH();
  String encodePublicKey() {
    return '';
  }

  String hashSalt(String salt) {
    return '';
  }

  bool verifySalt(String salt, String hash) {
    return true;
  }
}
