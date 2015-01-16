part of dslink.client;

/// a client session for both http and ws
class HttpClientSession implements ClientSession {

  Completer<DsRequester> _onRequesterReadyCompleter = new Completer<DsRequester>();
  Future<DsRequester> get onRequesterReady => _onRequesterReadyCompleter.future;


  final String dsId;

  final DsRequester requester;
  final Responder responder;
  final DsPrivateKey privateKey;

  DsSecretNonce _nonce;
  DsSecretNonce get nonce => _nonce;

  Connection _connection;


  static const Map<String, int> saltNameMap = const {
    'salt': 0,
    'saltS': 1,
  };
  /// 2 salts, salt and saltS
  final List<String> salts = new List<String>(2);

  updateSalt(String salt, [bool shortPolling=false]) {
    // TODO: implement updateSalt
  }
  
  String _wsUpdateUri;
  String _httpUpdateUri;

  HttpClientSession(String conn, String dsIdPrefix, DsPrivateKey privateKey, {NodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.modulusHash64}',
        requester = isRequester ? new DsRequester() : null,
        responder = (isResponder && nodeProvider != null) ? new Responder(nodeProvider) : null {
    // TODO don't put everything in constructor
    // TODO more error handling
    HttpClient client = new HttpClient();
    Uri connUri = Uri.parse('$conn?dsId=$dsId');
    client.postUrl(connUri).then((HttpClientRequest request) {
      Map requestJson = {
        'publicKey': privateKey.publicKey.modulusBase64,
        'isRequester': isRequester,
        'isResponder': (isResponder && nodeProvider != null)
      };

      request.add(jsonUtf8Encoder.convert(requestJson));
      request.close().then((HttpClientResponse response) {
        print(response.headers);
        response.fold([], foldList).then((List<int> merged) {
          try {
            String rslt = UTF8.decode(merged);
            Map serverConfig = JSON.decode(rslt);

            saltNameMap.forEach((name, idx) {
              //read salts
              salts[idx] = serverConfig[name];
            });
            String encryptedNonce = serverConfig['encryptedNonce'];
            _nonce = privateKey.decryptNonce(encryptedNonce);

            if (serverConfig['wsUri'] is String) {
              _wsUpdateUri = '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'.replaceFirst('http', 'ws');
            }
            if (serverConfig['httpUri'] is String) {
              // TODO implement http
              _httpUpdateUri = '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
            }
            // start requester and responder
//            if (_wsUpdateUri != null) {
//              initWebsocket();
//            }
            if (_httpUpdateUri != null) {
              initHttp();
            }
          } catch (err) {
            print(err);
            return;
          }
        });
      });
    });
  }
  
  initWebsocket() async {
    var socket = await WebSocket.connect('$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}');
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
  
  void initHttp() {
    _connection = new DsHttpClientConnection(_httpUpdateUri, this, salts[0], salts[1]);
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
