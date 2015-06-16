part of dslink.server;

/// a server link for both http and ws
class HttpServerLink implements ServerLink {
  final bool trusted;
  final String dsId;
  final String session;
  Completer<Requester> onRequesterReadyCompleter = new Completer<Requester>();

  Future<Requester> get onRequesterReady => onRequesterReadyCompleter.future;

  final Requester requester;
  final Responder responder;
  final PublicKey publicKey;

  /// nonce for authentication, don't overwrite existing nonce
  ECDH tempNonce;

  /// nonce after user verified the public key
  ECDH verifiedNonce;

  ECDH get nonce => verifiedNonce;

  ServerConnection connection;

  // TODO(rinick): deprecate this, all dslinks need to support it
  final bool enableTimeout;

  final List<String> _saltBases = new List<String>(3);
  final List<int> _saltInc = <int>[0, 0, 0];

  /// 3 salts, salt saltS saltL
  final List<String> salts = new List<String>(3);

  void _updateSalt(int type) {
    _saltInc[type] += DSRandom.instance.nextUint16();
    salts[type] = '${_saltBases[type]}${_saltInc[type].toRadixString(16)}';
  }

  HttpServerLink(String id, this.publicKey, ServerLinkManager linkManager, {NodeProvider nodeProvider, String sessionId, this.trusted: false, this.enableTimeout:false})
  : dsId = id,
  session = sessionId,
  requester = linkManager.getRequester(id),
  responder = (nodeProvider != null) ? linkManager.getResponder(id, nodeProvider, sessionId) : null {
    if (!trusted) {
      for (int i = 0; i < 3; ++i) {
        List<int> bytes = new List<int>(12);
        for (int j = 0; j < 12; ++j) {
          bytes[j] = DSRandom.instance.nextUint8();
        }
        _saltBases[i] = Base64.encode(bytes);
        _updateSalt(i);
      }
    }

    // TODO(rinick): need a requester ready property? because client can disconnect and reconnect and change isResponder value
  }

  /// check if public key matches the dsId
  bool get valid {
    if (trusted) {
      return true;
    }
    return publicKey.verifyDsId(dsId);
  }

  bool isRequester = false;

  /// by default it's a responder only link
  bool isResponder = true;

  void initLink(HttpRequest request, bool clientRequester, bool clientResponder, String serverDsId, String serverKey,
                {String wsUri:'/ws', String httpUri:'/http', int updateInterval:200}) {
    isRequester = clientResponder;
    isResponder = clientRequester;

    // TODO(rinick): don't use a hardcoded id and public key
    Map respJson = {
      "id": serverDsId, //"broker-dsa-VLK07CSRoX_bBTQm4uDIcgfU-jV-KENsp52KvDG_o8g",
      "publicKey": serverKey,
      //"vvOSmyXM084PKnlBz3SeKScDoFs6I_pdGAdPAB8tOKmA5IUfIlHefdNh1jmVfi1YBTsoYeXm2IH-hUZang48jr3DnjjI3MkDSPo1czrI438Cr7LKrca8a77JMTrAlHaOS2Yd9zuzphOdYGqOFQwc5iMNiFsPdBtENTlx15n4NGDQ6e3d8mrKiSROxYB9LrF1-53goDKvmHYnDA_fbqawokM5oA3sWUIq5uNdp55_cF68Lfo9q-ea8JEsHWyDH73FqNjUaPLFdgMl8aYl-sUGpdlMMMDwRq-hnwG3ad_CX5iFkiHpW-uWucta9i3bljXgyvJ7dtVqEUQBH-GaUGkC-w",
      "wsUri": wsUri,
      "httpUri": httpUri,
      "updateInterval": updateInterval
    };
    if (!trusted) {
      tempNonce = new ECDH.assign(publicKey, verifiedNonce);
      respJson["tempKey"] = tempNonce.encodePublicKey();
      respJson["salt"] = salts[0];
      respJson["saltS"] = salts[1];
      respJson["saltL"] = salts[2];
    }
    updateResponseBeforeWrite(request);
    request.response.write(DsJson.encode(respJson));
    request.response.close();
  }

  bool verifySalt(int type, String hash) {
    if (trusted) {
      return true;
    }
    if (hash == null) {
      return false;
    }
    if (verifiedNonce != null &&
    verifiedNonce.verifySalt(salts[type], hash)) {
      _updateSalt(type);
      return true;
    } else if (tempNonce != null && tempNonce.verifySalt(salts[type], hash)) {
      _updateSalt(type);
      nonceChanged();
      return true;
    }
    return false;
  }

  void nonceChanged() {
    verifiedNonce = tempNonce;
    tempNonce = null;
    if (connection != null) {
      connection.close();
      connection = null;
    }
  }

  void handleHttpUpdate(HttpRequest request) {
    String saltS = request.uri.queryParameters['authS'];
    if (saltS != null) {
      if (connection is HttpServerConnection && verifySalt(1, saltS)) {
        // handle http short polling
        (connection as HttpServerConnection).handleInputS(request, salts[1]);
        return;
      } else {
        throw HttpStatus.UNAUTHORIZED;
      }
    }

    if (!verifySalt(2, request.uri.queryParameters['authL'])) {
      throw HttpStatus.UNAUTHORIZED;
    }
//    if (requester == null) {
//      throw HttpStatus.FORBIDDEN;
//    }
    if (connection != null && connection is! HttpServerConnection) {
      connection.close();
      connection = null;
    }
    if (connection == null) {
      connection = new HttpServerConnection();
      if (responder != null && isResponder) {
        responder.connection = connection.responderChannel;
      }
      if (requester != null && isRequester) {
        requester.connection = connection.requesterChannel;
        if (!onRequesterReadyCompleter.isCompleted) {
          onRequesterReadyCompleter.complete(requester);
        }
      }
    }
    connection.addServerCommand('saltL', salts[2]);
    (connection as HttpServerConnection).handleInput(request);
  }

  void handleStreamUpdate(StreamConnectionAdapter adapter) {
    adapter.auth().then((auth) async {
      if (!verifySalt(0, auth)) {
        adapter.close(1011);
        return;
      }

      var salts = await adapter.salts();

      StreamConnection sconnection = createStreamConnection(adapter);
      sconnection.addServerCommand("salt", salts[0]);
      sconnection.onRequesterReady.then((channel) {
        if (connection != null) {
          connection.close();
        }

        connection = sconnection;

        if (responder != null && isResponder) {
          responder.connection = connection.responderChannel;
        }

        if (requester != null && isRequester) {
          requester.connection = connection.requesterChannel;
          if (!onRequesterReadyCompleter.isCompleted) {
            onRequesterReadyCompleter.complete(requester);
          }
        }
      });

      if (connection is! HttpServerConnection) {
        sconnection.onRequestReadyCompleter.complete(sconnection.requesterChannel);
      }
    });
  }

  void handleWsUpdate(HttpRequest request) {
    if (!verifySalt(0, request.uri.queryParameters['auth'])) {
      logger.warning("$dsId was rejected due to an improper auth value");
      throw HttpStatus.UNAUTHORIZED;
    }

    updateResponseBeforeWrite(request, null, null, true);

    WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
      ServerWebSocket wsconnection = createWsConnection(websocket);
      wsconnection.addServerCommand('salt', salts[0]);

      wsconnection.onRequesterReady.then((channel) {
        if (connection != null) {
          connection.close();
        }
        connection = wsconnection;
        if (responder != null && isResponder) {
          responder.connection = connection.responderChannel;
        }
        if (requester != null && isRequester) {
          requester.connection = connection.requesterChannel;
          if (!onRequesterReadyCompleter.isCompleted) {
            onRequesterReadyCompleter.complete(requester);
          }
        }
      });

      if (connection is! HttpServerConnection) {
        // work around for backward compatibility
        // TODO(rinick): remove this when all clients send blank data to initialize ws
        wsconnection.onRequestReadyCompleter.complete(wsconnection.requesterChannel);;
      }
    }).catchError((e) {
      try {
        if (e is WebSocketException) {
          request.response.statusCode = HttpStatus.BAD_REQUEST;
          request.response.writeln("Failed to upgrade to a WebSocket.");
        } else {
          request.response.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
          request.response.writeln("Internal Server Error");
        }
      } catch (e) {
      }
      return request.response.close();
    });
  }

  ServerWebSocket createWsConnection(WebSocket websocket) {
    return new ServerWebSocket(websocket, enableTimeout:enableTimeout);
  }

  StreamConnection createStreamConnection(StreamConnectionAdapter adapter) {
    return new StreamConnection(adapter, enableTimeout: enableTimeout);
  }
}
