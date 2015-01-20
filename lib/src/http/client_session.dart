part of dslink.client;

/// a client link for both http and ws
class HttpClientLink implements ClientLink {

  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;


  final String dsId;

  final Requester requester;
  final Responder responder;
  final PrivateKey privateKey;

  SecretNonce _nonce;
  SecretNonce get nonce => _nonce;

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
  bool _isRequester;
  bool _isResponder;
  NodeProvider _nodeProvider;
  String _conn;

  HttpClientLink(String conn, String dsIdPrefix, PrivateKey privateKey, {NodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.modulusHash64}',
        requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null) ? new Responder(nodeProvider) : null {
    _isRequester = isRequester;
    _isResponder = isResponder;
    _nodeProvider = nodeProvider;
    _conn = conn;
  }
        
  Future init() async {
    if (_nonce != null) {
      return new Future.value();
    }
    
    HttpClient client = new HttpClient();
    Uri connUri = Uri.parse('$_conn?dsId=$dsId');
    HttpClientRequest request = await client.postUrl(connUri);
    Map requestJson = {
      'publicKey': privateKey.publicKey.modulusBase64,
      'isRequester': _isRequester,
      'isResponder': (_isResponder && _nodeProvider != null)
    };
    request.add(jsonUtf8Encoder.convert(requestJson));
    HttpClientResponse response = await request.close();
    List<int> merged = await response.fold([], foldList);
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
    
    if (_wsUpdateUri != null) {
      await initWebsocket();
    }
                        
//    if (_httpUpdateUri != null) {
//      await initHttp();
//    }
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
  
  initHttp() async {
    _connection = new HttpClientConnection(_httpUpdateUri, this, salts[0], salts[1]);
    
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
