part of dslink.browser_client;

/// a client link for both http and ws
class BrowserECDHLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  final String dsId;

  final Requester requester;
  final Responder responder;
  final PrivateKey privateKey;

  ECDH _nonce;
  ECDH get nonce => _nonce;

  Connection _connection;

  static const Map<String, int> saltNameMap = const {'salt': 0, 'saltS': 1,};

  /// 2 salts, salt and saltS
  final List<String> salts = new List<String>(2);

  updateSalt(String salt, [bool shortPolling = false]) {
    // TODO: implement updateSalt
  }

  String _wsUpdateUri;
  String _httpUpdateUri;
  String _conn;

  BrowserECDHLink(this._conn, String dsIdPrefix, PrivateKey privateKey,
      {NodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.qHash64}',
        requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null) ? new Responder(nodeProvider) : null {}

  void init() {

    Uri connUri = Uri.parse('$_conn?dsId=$dsId');
    
    Map requestJson = {
      'publicKey': privateKey.publicKey.qBase64,
      'isRequester': requester != null,
      'isResponder': responder != null
    };
    HttpRequest.request(connUri.toString(), method: 'POST', withCredentials: true, mimeType: 'application/json', sendData: JSON.encode(requestJson)).then(
        (HttpRequest request){
          Map serverConfig = JSON.decode(request.responseText);
          saltNameMap.forEach((name, idx) {
            //read salts
            salts[idx] = serverConfig[name];
          });
          String tempKey = serverConfig['tempKey'];
          _nonce = privateKey.decodeECDH(tempKey);

          if (serverConfig['wsUri'] is String) {
            _wsUpdateUri =
                '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'.replaceFirst('http', 'ws');
          }

          if (serverConfig['httpUri'] is String) {
            // TODO implement http
            _httpUpdateUri = '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
          }

          if (_wsUpdateUri != null) {
            initWebsocket();
          }else if (_httpUpdateUri != null) {
            initHttp();
          }
          
    });
  }

  initWebsocket() async {
     var socket = new WebSocket('$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}');
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
     _connection = new HttpBrowserConnection(_httpUpdateUri, this, salts[0], salts[1]);
   
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
