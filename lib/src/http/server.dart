part of dslink.http_server;

class DsSimpleLinkManager implements ServerLinkManager{
  final Map<String, HttpServerLink> _links = new Map<String, HttpServerLink>();
  
  void addLink(ServerLink link) {
    _links[link.dsId] = link;
  }

  ServerLink getLink(String dsId) {
   return _links[dsId];
  }

  void removeLink(ServerLink link) {
    if (_links[link.dsId] == link) {
      _links.remove(link.dsId);
    }
  }
}
class DsHttpServer {
  final NodeProvider nodeProvider;
  ServerLinkManager _links;
  /// to open a secure server, SecureSocket.initialize() need to be called before start()
  DsHttpServer.start(dynamic address, //
      {int httpPort: 80, int httpsPort: 443, String certificateName, this.nodeProvider, linkManager}) {
    if (linkManager == null){
      _links = new DsSimpleLinkManager();
    } else {
      _links = linkManager;
    }
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

  void _handleRqeuest(HttpRequest request) {
    try {
      String dsId = request.uri.queryParameters['dsId'];

      if (dsId == null || dsId.length < 64) {
        request.response.close();
        return;
      }

      switch (request.requestedUri.path) {
        case '/conn':
          _handleConn(request, dsId);
          break;
        case '/http':
          _handleHttpUpdate(request, dsId);
          break;
        case '/ws':
          _handleWsUpdate(request, dsId);
          break;
        default:
          request.response.close();
      }
    } catch (err) {
      if (err is int) {
        // TODO need protection because changing statusCode itself can throw
        request.response.statusCode = err;
      }
      request.response.close();
    }
  }

  void _handleConn(HttpRequest request, String dsId) {
    request.fold([], foldList).then((List<int> merged) {
      try {
        if (merged.length > 1024) {
          // invalid connection request
          request.response.close();
          return;
        }
        String str = UTF8.decode(merged);
        Map m = JSON.decode(str);
        HttpServerLink link = _links.getLink(dsId);
        if (link == null) {
          String modulus = m['publicKey'];
          var bytes = Base64.decode(modulus);
          if (bytes == null) {
            // public key is invalid
            throw HttpStatus.BAD_REQUEST;
          }
          link = new HttpServerLink(dsId, new BigInteger.fromBytes(1, bytes), nodeProvider: nodeProvider);
          if (!link.valid) {
            // dsId doesn't match public key
            throw HttpStatus.BAD_REQUEST;
          }
          _links.addLink(link);
        }
        link.initLink(request);
      } catch (err) {
        if (err is int) {
          // TODO need protection because changing statusCode itself can throw
          request.response.statusCode = err;
        }
        request.response.close();
      }
    });

  }
  void _handleHttpUpdate(HttpRequest request, String dsId) {
    HttpServerLink link = _links.getLink(dsId);
    if (link != null) {
      link._handleHttpUpdate(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }

  void _handleWsUpdate(HttpRequest request, String dsId) {
    HttpServerLink link = _links.getLink(dsId);
    if (link != null) {
      link._handleWsUpdate(request);
    } else {
      throw HttpStatus.UNAUTHORIZED;
    }
  }
}
