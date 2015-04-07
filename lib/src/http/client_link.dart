part of dslink.client;

/// a client link for both http and ws
class HttpClientLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  final String dsId;

  final Requester requester;
  final Responder responder;
  final PrivateKey privateKey;

  ECDH _nonce;
  ECDH get nonce => _nonce;

  Connection _wsConnection;
  Connection _httpConnection;

  static const Map<String, int> saltNameMap = const {'salt': 0, 'saltS': 1, 'saltL': 2,};

  /// 2 salts, salt and saltS
  final List<String> salts = new List<String>(3);

  updateSalt(String salt, [int saltId = 0]) {
    salts[saltId] = salt;
  }

  String _wsUpdateUri;
  String _httpUpdateUri;
  String _conn;

  HttpClientLink(this._conn, String dsIdPrefix, PrivateKey privateKey,
      {NodeProvider nodeProvider, bool isRequester: true,
      bool isResponder: true})
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.qHash64}',
        requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null)
            ? new Responder(nodeProvider)
            : null {}

  int _connDelay = 1;
  connect() async {
    HttpClient client = new HttpClient();
    Uri connUri = Uri.parse('$_conn?dsId=$dsId');
    printDebug('connecting: $connUri');
    try {
      HttpClientRequest request = await client.postUrl(connUri);
      Map requestJson = {
        'publicKey': privateKey.publicKey.qBase64,
        'isRequester': requester != null,
        'isResponder': responder != null
      };
      printDebug(dsId);
    
      request.add(jsonUtf8Encoder.convert(requestJson));
      HttpClientResponse response = await request.close();
      List<int> merged = await response.fold([], foldList);
      String rslt = UTF8.decode(merged);
      Map serverConfig = JSON.decode(rslt);
      saltNameMap.forEach((name, idx) {
        //read salts
        salts[idx] = serverConfig[name];
      });
      String tempKey = serverConfig['tempKey'];
      _nonce = privateKey.decodeECDH(tempKey);

      if (serverConfig['wsUri'] is String) {
        _wsUpdateUri = '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'
            .replaceFirst('http', 'ws');
      }

      if (serverConfig['httpUri'] is String) {
        // TODO implement http
        _httpUpdateUri = '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
      }

      initWebsocket();
      _connDelay = 1;
      _wsDelay = 1;
      //initHttp();
      
    } catch (err) {
      DsTimer.timerOnceAfter(connect, _connDelay * 1000);
      if (_connDelay < 60)_wsDelay++;
    }
  }

  initWebsocket() async {
    try {
      var socket = await WebSocket
          .connect('$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}');
      _wsConnection = new WebSocketConnection(socket, clientLink: this);

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
        initWebsocketAfterDisconnect();
      });
    } catch (error) {
      initHttp();
      _wsDelay = 5;
      DsTimer.timerOnceAfter(initWebsocketAfterDisconnect, 5000);
    }
  }
  int _wsDelay = 1;
  initWebsocketAfterDisconnect() async {
    if (_httpConnection == null) {
      initHttp();
    }
    try {
      var socket = await WebSocket
          .connect('$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}');
      _wsConnection = new WebSocketConnection(socket, clientLink: this);
      _wsDelay = 1;
      if (_httpConnection != null) {
        _httpConnection.close();
      }
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
        initWebsocketAfterDisconnect();
      });
    } catch (error) {
      printDebug(error);
      DsTimer.timerOnceAfter(initWebsocketAfterDisconnect, _wsDelay*1000);
      if (_wsDelay < 60)_wsDelay++;
    }
  }
  void attachWsResponderRequester() {
    
  }
  
  initHttp() async {
    _httpConnection =
        new HttpClientConnection(_httpUpdateUri, this, salts[2], salts[1]);

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
    _httpConnection.onDisconnected.then((bool authFailed){
      _httpConnection = null;
      if (authFailed) {
        DsTimer.timerCancel(initWebsocketAfterDisconnect);
        connect();
      } else {
        // reconnection of websocket should handle this case
      }
    });
  }
}
