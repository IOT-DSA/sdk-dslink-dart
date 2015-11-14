part of dslink.browser_client;

/// a client link for both http and ws
class BrowserECDHLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Completer _onConnectedCompleter = new Completer();
  Future get onConnected => _onConnectedCompleter.future;
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  final String dsId;
  final String token;
  
  final Requester requester;
  final Responder responder;
  final PrivateKey privateKey;

  ECDH _nonce;
  ECDH get nonce => _nonce;

  WebSocketConnection _wsConnection;
//  HttpBrowserConnection _httpConnection;

  bool enableAck = false;
  
  static const Map<String, int> saltNameMap = const {
    'salt': 0,
    'saltS': 1,
    'saltL': 2,
  };

  /// 2 salts, salt and saltS
  final List<String> salts = new List<String>(3);

  updateSalt(String salt, [int saltId = 0]) {
    salts[saltId] = salt;
  }

  String _wsUpdateUri;
  String _httpUpdateUri;
  String _conn;
  String tokenHash;
  /// formats sent to broker
  List formats = ['msgpack', 'json'];
  /// format received from broker
  String format = 'json';
  BrowserECDHLink(this._conn, String dsIdPrefix, PrivateKey privateKey,
      {NodeProvider nodeProvider,
      bool isRequester: true,
      bool isResponder: true,
      this.token, List formats})
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.qHash64}',
        requester = isRequester ? new Requester() : null,
        responder = (isResponder && nodeProvider != null)
            ? new Responder(nodeProvider)
            : null {
              if (!_conn.contains('://')) {
                _conn = 'http://$_conn';
              }
              if (token != null && token.length > 16) {
                // pre-generate tokenHash
                String tokenId = token.substring(0, 16);
                String hashStr =   CryptoProvider.sha256(UTF8.encode('$dsId$token'));
                tokenHash = '&token=$tokenId$hashStr';
              }
              if (formats != null) {
                this.formats = formats;
              }
              if (window.location.hash.contains('dsa_json')) {
                formats = ['json'];
              }
            }

  int _connDelay = 1;
  connect() async {
    if (_closed) return;
    lockCryptoProvider();
    String connUrl = '$_conn?dsId=$dsId';
    if (tokenHash != null) {
      connUrl = '$connUrl$tokenHash';
    }
    Uri connUri = Uri.parse(connUrl);
    logger.info('Connecting: $connUri');
    try {
      Map requestJson = {
        'publicKey': privateKey.publicKey.qBase64,
        'isRequester': requester != null,
        'isResponder': responder != null,
        'formats': formats,
        'version': DSA_VERSION
      };
      HttpRequest request = await HttpRequest.request(connUrl,
          method: 'POST',
          withCredentials: false,
          mimeType: 'application/json',
          sendData: DsJson.encode(requestJson));
      Map serverConfig = DsJson.decode(request.responseText);
      saltNameMap.forEach((name, idx) {
        //read salts
        salts[idx] = serverConfig[name];
      });
      String tempKey = serverConfig['tempKey'];
      _nonce = await privateKey.getSecret(tempKey);

      if (serverConfig['wsUri'] is String) {
        _wsUpdateUri = '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'
            .replaceFirst('http', 'ws');
        if (tokenHash != null) {
          _wsUpdateUri = '$_wsUpdateUri$tokenHash';
        }
      }

      if (serverConfig['httpUri'] is String) {
        // TODO implement http
        _httpUpdateUri =
            '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
        if (tokenHash != null) {
          _httpUpdateUri = '$_httpUpdateUri$tokenHash';
        }
      }

      // server start to support version since 1.0.4
      // and this is the version ack is added
      enableAck = serverConfig.containsKey('version');
      if (serverConfig['format'] is String) {
       format = serverConfig['format'];
      }
      initWebsocket(false);
      _connDelay = 1;
      _wsDelay = 1;
      // initHttp();

    } catch (err) {
      DsTimer.timerOnceAfter(connect, _connDelay * 1000);
      if (_connDelay < 60) _connDelay++;
    }
  }

  int _wsDelay = 1;
  initWebsocket([bool reconnect = true]) {
    if (_closed) return;
//    if (reconnect && _httpConnection == null) {
//      initHttp();
//    }
    String wsUrl = '$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}&format=$format';
    var socket = new WebSocket(wsUrl);
    _wsConnection = new WebSocketConnection(socket, this, enableAck:enableAck, onConnect: () {
      if (!_onConnectedCompleter.isCompleted) {
        _onConnectedCompleter.complete();
      }
    }, useCodec:DsCodec.getCodec(format));

    if (responder != null) {
      responder.connection = _wsConnection.responderChannel;
    }

    if (requester != null) {
      _wsConnection.onRequesterReady.then((channel) {
        if (_closed) return;
        requester.connection = channel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      });
    }
    _wsConnection.onDisconnected.then((authError) {
      logger.info('Disconnected');
      if (_closed) return;

      if (_wsConnection._opened) {
        _wsDelay = 1;
        if (authError) {
          connect();
        } else {
          initWebsocket(false);
        }
      } else if (reconnect) {
        if (authError) {
          connect();
        } else {
          DsTimer.timerOnceAfter(initWebsocket, _wsDelay * 1000);
          if (_wsDelay < 60) _wsDelay++;
        }
      } else {
//        initHttp();
        _wsDelay = 5;
        DsTimer.timerOnceAfter(initWebsocket, 5000);
      }
    });
  }

//  initHttp() {
//    if (_closed) return;
//    _httpConnection =
//        new HttpBrowserConnection(_httpUpdateUri, this, salts[2], salts[1]);
//
//    if (!_onConnectedCompleter.isCompleted) {
//      _onConnectedCompleter.complete();
//    }
//
//    if (responder != null) {
//      responder.connection = _httpConnection.responderChannel;
//    }
//
//    if (requester != null) {
//      _httpConnection.onRequesterReady.then((channel) {
//        requester.connection = channel;
//        if (!_onRequesterReadyCompleter.isCompleted) {
//          _onRequesterReadyCompleter.complete(requester);
//        }
//      });
//    }
//    _httpConnection.onDisconnected.then((bool authFailed) {
//      if (_closed) return;
//      _httpConnection = null;
//      if (authFailed) {
//        DsTimer.timerCancel(initWebsocket);
//        connect();
//      } else {
//        // reconnection of websocket should handle this case
//      }
//    });
//  }

  bool _closed = false;
  void close() {
    _onConnectedCompleter = new Completer();
    if (_closed) return;
    _closed = true;
    if (_wsConnection != null) {
      _wsConnection.close();
      _wsConnection = null;
    }
//    if (_httpConnection != null) {
//      _httpConnection.close();
//      _httpConnection = null;
//    }
  }
}
