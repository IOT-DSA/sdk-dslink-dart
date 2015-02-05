part of dslink.browser_client;

/// a client link for both http and ws
class BrowserUserLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;
  
  
  final Requester requester;
  final Responder responder;
  
  final ECDH nonce = const DummyECDH();
  PrivateKey privateKey;
  
  Connection _connection;
  
  static const Map<String, int> saltNameMap = const {'salt': 0, 'saltS': 1,};
  
  /// 2 salts, salt and saltS
  final List<String> salts = const['', ''];
  
  updateSalt(String salt, [bool shortPolling = false]) {
    // TODO: implement updateSalt
  }
  
  String wsUpdateUri;
  String httpUpdateUri;
  String _conn;
  
  BrowserUserLink(this._conn, PrivateKey privateKey,
      {NodeProvider nodeProvider, bool isRequester: true, bool isResponder: true, this.wsUpdateUri, this.httpUpdateUri})
      :
        requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null) ? new Responder(nodeProvider) : null {}
  
  Future init() async {
    
    if (wsUpdateUri != null) {
      await initWebsocket();
    }
  
  //    if (_httpUpdateUri != null) {
  //      await initHttp();
  //    }
  }
  
  initWebsocket() async {
    var socket = new WebSocket(wsUpdateUri);
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
  
  initHttp() async {
    _connection = new HttpBrowserConnection(httpUpdateUri, this, '', '');
  
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