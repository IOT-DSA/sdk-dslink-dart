part of dslink.http_server;

class DsHttpServer {
  /// to open a secure server, SecureSocket.initialize() need to be called before start()
  DsHttpServer.start(dynamic address, {int httpPort: 80, int httpsPort: 443, String certificateName, this.nodeProvider}) {
    if (httpPort > 0) {
      HttpServer.bind(address, httpPort).then((server) {
        print('listen on $httpPort');
        server.listen(_handleRqeuest);
      }).catchError((Object err) {
        print(err);
      });
    }
    if (httpsPort > 0 && certificateName != null) {
      HttpServer.bindSecure(address, httpsPort, certificateName: certificateName).then((server) {
        print('listen on $httpsPort');
        server.listen(_handleRqeuest);
      }).catchError((Object err) {
        print(err);
      });
    }
  }
  final DsNodeProvider nodeProvider;
  final Map<String, DsHttpServerSession> _sessions = new Map<String, DsHttpServerSession>();

  void _handleRqeuest(HttpRequest request) {
    print(request);
    try {
      String dsId = request.headers.value('ds-id');
      if (dsId == null || dsId.length < 64) {
        request.response.close();
        return;
      }
      switch (request.requestedUri.path) {
        case '/conn':
          _handleConn(request, dsId);
          break;
        case '/http_update':
          _handleHttpUpdate(request, dsId);
          break;
        case '/http_data':
          _handleHttpData(request, dsId);
          break;
        case '/ws_update':
          _handleWsUpdate(request, dsId);
          break;
        case '/ws_data':
          _handleWsData(request, dsId);
          break;
        default:
          request.response.close();
      }
    } catch (err) {
      if (err is int) {
        // need protection because changing statusCode itself can throw
        request.response.statusCode = err;
      }
      request.response.close();
    }
  }

  void _handleConn(HttpRequest request, String dsId) {
    DsHttpServerSession session = _sessions[dsId];
    if (session == null) {
      String modulus = request.headers.value('ds-public-key');
      var bytes = Base64.decode(modulus);
      if (bytes == null) {
        // public key is invalid
        throw HttpStatus.BAD_REQUEST;
      }
      session = new DsHttpServerSession(dsId, new BigInteger.fromBytes(1, bytes), nodeProvider: nodeProvider, //
      isRequester: request.headers.value('ds-is-responder') == 'true', // if client is responder, then server is requester
      isResponder: request.headers.value('ds-is-requester') == 'true' // if client is requester, then server is responder
      );
      if (!session.valid) {
        // dsId doesn't match public key
        throw HttpStatus.BAD_REQUEST;
      }
      _sessions[dsId] = session;
    }
    session.initSession(request);
  }
  void _handleHttpUpdate(HttpRequest request, String dsId) {
    DsHttpServerSession session = _sessions[dsId];
    if (session != null) {
      session._handleHttpUpdate(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }
  void _handleHttpData(HttpRequest request, String dsId) {
    DsHttpServerSession session = _sessions[dsId];
    if (session != null) {
      session._handleHttpData(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }
  void _handleWsUpdate(HttpRequest request, String dsId) {
    DsHttpServerSession session = _sessions[dsId];
    if (session != null) {
      session._handleWsUpdate(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }
  void _handleWsData(HttpRequest request, String dsId) {
    DsHttpServerSession session = _sessions[dsId];
    if (session != null) {
      session._handleWsData(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }

}
