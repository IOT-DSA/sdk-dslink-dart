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

  /// 2 salts, salt and saltS
  final List<String> salts = const ['', ''];

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

  void init() {

    initWebsocket();

    //    if (_httpUpdateUri != null) {
    //      await initHttp();
    //    }
  }

  initWebsocket() {
    var socket = new WebSocket('$wsUpdateUri?session=$session');
    _connection = new WebSocketConnection(socket);

    if (responder != null) {
      responder.connection = _connection.responderChannel;
    }

    if (requester != null) {
      _connection.onRequesterReady.then((channel) {
        requester.connection = channel;
        _onRequesterReadyCompleter.complete(requester);
      });
    }
  }

  initHttp() {
    _connection = new HttpBrowserConnection('$httpUpdateUri?session=$session', this, '', '');

    if (responder != null) {
      responder.connection = _connection.responderChannel;
    }

    if (requester != null) {
      _connection.onRequesterReady.then((channel) {
        requester.connection = channel;
        _onRequesterReadyCompleter.complete(requester);
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
