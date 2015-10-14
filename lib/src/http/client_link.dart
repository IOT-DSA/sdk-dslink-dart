part of dslink.client;

/// a client link for both http and ws
class HttpClientLink implements ClientLink {
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Completer _onConnectedCompleter = new Completer();

  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  Future get onConnected => _onConnectedCompleter.future;

  String remotePath;

  final String dsId;
  final String home;
  final String token;
  final PrivateKey privateKey;

  String tokenHash;
  
  Requester requester;
  Responder responder;

  ECDH _nonce;

  ECDH get nonce => _nonce;

  WebSocketConnection _wsConnection;
//  HttpClientConnection _httpConnection;

  static const Map<String, int> saltNameMap = const {
    'salt': 0,
    'saltS': 1,
    'saltL': 2
  };

  /// 2 salts, salt and saltS
  final List<String> salts = new List<String>(3);

  updateSalt(String salt, [int saltId = 0]) {
    salts[saltId] = salt;
  }

  String _wsUpdateUri;
//  String _httpUpdateUri;
  String _conn;
//  bool enableHttp;
  bool enableAck = false;

  Map linkData;

  HttpClientLink(this._conn, String dsIdPrefix, PrivateKey privateKey,
      {NodeProvider nodeProvider, bool isRequester: true,
      bool isResponder: true, Requester overrideRequester,
      Responder overrideResponder, this.home, this.token, this.linkData
      //this.enableHttp: false
      })
      : privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.qHash64}' {
    if (isRequester) {
      if (overrideRequester != null) {
        requester = overrideRequester;
      } else {
        requester = new Requester();
      }
    }
    if (isResponder) {
      if (overrideResponder != null) {
        responder = overrideResponder;
      } else if (nodeProvider != null) {
        responder = new Responder(nodeProvider);
      }
    }
    if (token != null && token.length > 16) {
      // pre-generate tokenHash
      String tokenId = token.substring(0, 16);
      Uint8List bytes = ByteDataUtil.list2Uint8List(UTF8.encode('$dsId$token'));
      SHA256Digest sha256 = new SHA256Digest();
      Uint8List hashed = sha256.process(new Uint8List.fromList(bytes));
      String hashStr =  Base64.encode(hashed);
      tokenHash = '&token=$tokenId$hashStr';
    }
  }

  int _connDelay = 1;

  connect() async {
    if (_closed) return;

    lockCryptoProvider();
    DsTimer.timerCancel(initWebsocket);

    HttpClient client = new HttpClient();

    client.badCertificateCallback = (X509Certificate cert, String host,
        int port) {
      return true;
    };

    String connUrl = '$_conn?dsId=$dsId';
    if (home != null) {
      connUrl = '$connUrl&home=$home';
    }
    if (tokenHash != null) {
      connUrl = '$connUrl$tokenHash';
    }
    Uri connUri = Uri.parse(connUrl);
    logger.info("Connecting to ${_conn}");
    try {
      HttpClientRequest request = await client.postUrl(connUri);
      Map requestJson = {
        'publicKey': privateKey.publicKey.qBase64,
        'isRequester': requester != null,
        'isResponder': responder != null,
        'version': DSA_VERSION
      };
      if (linkData != null) {
        requestJson['linkData'] = linkData;
      }

      logger.fine("DS ID: ${dsId}");

      request.add(UTF8.encode(DsJson.encode(requestJson)));
      HttpClientResponse response = await request.close();
      List<int> merged = await response.fold([], foldList);
      String rslt = UTF8.decode(merged);
      Map serverConfig = DsJson.decode(rslt);
      saltNameMap.forEach((name, idx) {
        //read salts
        salts[idx] = serverConfig[name];
      });
      String tempKey = serverConfig['tempKey'];
      if (tempKey == null) {
        // trusted client, don't do ECDH handshake
        _nonce = const DummyECDH();
      } else {
        _nonce = await privateKey.getSecret(tempKey);
      }
      // server start to support version since 1.0.4
      // and this is the version ack is added
      enableAck = serverConfig.containsKey('version');
      remotePath = serverConfig['path'];

      if (serverConfig['wsUri'] is String) {
        _wsUpdateUri = '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'
            .replaceFirst('http', 'ws');
        if (home != null) {
          _wsUpdateUri = '$_wsUpdateUri&home=$home';
        }
      }

//      if (serverConfig['httpUri'] is String) {
//        _httpUpdateUri =
//            '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
//      }

      initWebsocket(false);
      _connDelay = 1;
      _wsDelay = 1;
      //initHttp();

    } catch (err) {
      DsTimer.timerOnceAfter(connect, _connDelay * 1000);
      if (_connDelay < 60) _connDelay++;
    }
  }

  int _wsDelay = 1;

  initWebsocket([bool reconnect = true]) async {
    if (_closed) return;

//    if (reconnect && _httpConnection == null) {
//      initHttp();
//    }
    try {
      String wsUrl = '$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}';
      if (tokenHash != null) {
        wsUrl = '$wsUrl$tokenHash';
      }
      var socket = await HttpHelper.connectToWebSocket(wsUrl);
      _wsConnection = new WebSocketConnection(socket,
          clientLink: this, enableTimeout: true, enableAck: enableAck);

      logger.info("Connected");
      if (!_onConnectedCompleter.isCompleted) {
        _onConnectedCompleter.complete();
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
        initWebsocket();
      });
    } catch (error) {
      logger.fine(error);
      if (error is WebSocketException && (
            error.message.contains('not upgraded to websocket') // error from dart
              || error.message.contains('(401)') // error from nodejs
          )) {
        DsTimer.timerOnceAfter(connect, _connDelay * 1000);
      } else if (reconnect) {
        DsTimer.timerOnceAfter(initWebsocket, _wsDelay * 1000);
        if (_wsDelay < 60) _wsDelay++;
      }
//      else {
//        initHttp();
//        _wsDelay = 5;
//        DsTimer.timerOnceAfter(initWebsocket, 5000);
//      }
    }
  }

//  initHttp() async {
//    if (!enableHttp) {
//      return;
//    }
//
//    if (_closed) return;
//
//    _httpConnection =
//        new HttpClientConnection(_httpUpdateUri, this, salts[2], salts[1]);
//
//    logger.info("Connected");
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
//
//    _httpConnection.onDisconnected.then((bool authFailed) {
//      if (_closed) return;
//      _httpConnection = null;
//      if (authFailed) {
//        DsTimer.timerOnceAfter(connect, _connDelay * 1000);
//      } else {
//        // reconnection of websocket should handle this case
//      }
//    });
//  }

  bool _closed = false;

  void close() {
    if (_closed) return;
    _onConnectedCompleter = new Completer();
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

Future<PrivateKey> getKeyFromFile(String path) async {
  var file = new File(path);

  PrivateKey key;
  if (!file.existsSync()) {
    key = await PrivateKey.generate();
    file.createSync(recursive: true);
    file.writeAsStringSync(key.saveToString());
  } else {
    key = new PrivateKey.loadFromString(file.readAsStringSync());
  }

  return key;
}
