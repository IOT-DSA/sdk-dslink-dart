part of dslink.server;

/// a server link for both http and ws
class HttpServerLink implements ServerLink {
  final bool trusted;
  final String dsId;
  final String session;
  Completer<Requester> _onRequesterReadyCompleter = new Completer<Requester>();
  Future<Requester> get onRequesterReady => _onRequesterReadyCompleter.future;

  final Requester requester;
  final Responder responder;
  final PublicKey publicKey;

  /// nonce for authentication, don't overwrite existing nonce
  ECDH _tempNonce;
  /// nonce after user verified the public key
  ECDH _verifiedNonce;

  ECDH get nonce => _verifiedNonce;

  ServerConnection _connection;

  final List<String> _saltBases = new List<String>(2);
  final List<int> _saltInc = <int>[0, 0];
  /// 2 salts, salt saltS
  final List<String> salts = new List<String>(2);
  void _updateSalt(int type) {
    _saltInc[type] += DSRandom.instance.nextUint16();
    salts[type] = '${_saltBases[type]}${_saltInc[type].toRadixString(16)}';
  }
  HttpServerLink(String id, this.publicKey, ServerLinkManager linkManager,
      {NodeProvider nodeProvider, this.session, this.trusted: false})
      : dsId = id,
        requester = linkManager.getRequester(id),
        responder = (nodeProvider != null)
            ? linkManager.getResponder(id, nodeProvider)
            : null {
    if (!trusted) {
      for (int i = 0; i < 2; ++i) {
        List<int> bytes = new List<int>(12);
        for (int j = 0; j < 12; ++j) {
          bytes[j] = DSRandom.instance.nextUint8();
        }
        _saltBases[i] = Base64.encode(bytes);
        _updateSalt(i);
      }
    }

    // TODO, need a requester ready property? because client can disconnect and reconnect and change isResponder value
  }
  /// check if public key matchs the dsId
  bool get valid {
    if (trusted) {
      return true;
    }
    return publicKey.verifyDsId(dsId);
  }

  void initLink(HttpRequest request) {

//          isRequester: m['isResponder'] == true, // if client is responder, then server is requester
//          isResponder: m['isRequester'] == true // if client is requester, then server is responder

    // TODO, dont use hard coded id and public key
    Map respJson = {
      "id": "broker-dsa-VLK07CSRoX_bBTQm4uDIcgfU-jV-KENsp52KvDG_o8g",
      "publicKey":
          "vvOSmyXM084PKnlBz3SeKScDoFs6I_pdGAdPAB8tOKmA5IUfIlHefdNh1jmVfi1YBTsoYeXm2IH-hUZang48jr3DnjjI3MkDSPo1czrI438Cr7LKrca8a77JMTrAlHaOS2Yd9zuzphOdYGqOFQwc5iMNiFsPdBtENTlx15n4NGDQ6e3d8mrKiSROxYB9LrF1-53goDKvmHYnDA_fbqawokM5oA3sWUIq5uNdp55_cF68Lfo9q-ea8JEsHWyDH73FqNjUaPLFdgMl8aYl-sUGpdlMMMDwRq-hnwG3ad_CX5iFkiHpW-uWucta9i3bljXgyvJ7dtVqEUQBH-GaUGkC-w",
      "wsUri": "/ws",
      "httpUri": "/http",
      "updateInterval": 200
    };
    if (!trusted) {
      _tempNonce = new ECDH.generate(publicKey);
      respJson["tempKey"] = _tempNonce.encodePublicKey();
      respJson["salt"] = salts[0];
      respJson["saltS"] = salts[1];
    }
    updateResponseBeforeWrite(request);
    request.response.write(JSON.encode(respJson));
    request.response.close();
  }

  bool _verifySalt(int type, String hash) {
    if (trusted) {
      return true;
    }
    if (hash == null) {
      return false;
    }
    if (_verifiedNonce != null &&
        _verifiedNonce.verifySalt(salts[type], hash)) {
      _updateSalt(type);
      return true;
    } else if (_tempNonce != null && _tempNonce.verifySalt(salts[type], hash)) {
      _updateSalt(type);
      _nonceChanged();
      return true;
    }
    return false;
  }
  void _nonceChanged() {
    _verifiedNonce = _tempNonce;
    _tempNonce = null;
    if (_connection != null) {
      _connection.close();
      _connection = null;
    }
  }
  void handleHttpUpdate(HttpRequest request) {
    String saltS = request.uri.queryParameters['authS'];
    if (saltS != null) {
      if (_connection is HttpServerConnection && _verifySalt(1, saltS)) {
        // handle http short polling
        (_connection as HttpServerConnection).handleInputS(request, salts[1]);
        return;
      } else {
        throw HttpStatus.UNAUTHORIZED;
      }
    }

    if (!_verifySalt(0, request.uri.queryParameters['auth'])) {
      throw HttpStatus.UNAUTHORIZED;
    }
//    if (requester == null) {
//      throw HttpStatus.FORBIDDEN;
//    }
    if (_connection != null && _connection is! HttpServerConnection) {
      _connection.close();
      _connection = null;
    }
    if (_connection == null) {
      _connection = new HttpServerConnection();
      if (responder != null) {
        responder.connection = _connection.responderChannel;
      }
      if (requester != null) {
        requester.connection = _connection.requesterChannel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      }
    }
    _connection.addServerCommand('salt', salts[0]);
    (_connection as HttpServerConnection).handleInput(request);
  }

  void handleWsUpdate(HttpRequest request) {
    if (!_verifySalt(0, request.uri.queryParameters['auth'])) {
      throw HttpStatus.UNAUTHORIZED;
    }
    if (_connection != null) {
      _connection.close();
    }
    WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
      _connection = new WebSocketConnection(websocket);
      _connection.addServerCommand('salt', salts[0]);
      if (responder != null) {
        responder.connection = _connection.responderChannel;
      }
      if (requester != null) {
        requester.connection = _connection.requesterChannel;
        if (!_onRequesterReadyCompleter.isCompleted) {
          _onRequesterReadyCompleter.complete(requester);
        }
      }
    });
  }
}
