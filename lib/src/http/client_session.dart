part of dslink.client;

/// a client session for both http and ws
class DsHttpClientSession implements DsSession {
  final String dsId;

  final DsRequester requester;
  final DsResponder responder;
  final DsPrivateKey _privateKey;

  DsSecretNonce _nonce;

  DsConnection _requesterConn;
  DsConnection _responderConn;


  static const Map<String, int> saltNameMap = const {
    'ds-req-salt': 0,
    'ds-req-salt-s': 1,
    'ds-resp-salt': 2,
    'ds-resp-salt-s': 3
  };
  /// 4 salts, reqSaltL reqSaltS respSaltL respSaltS
  final List<String> salts = new List<String>(4);

  Uri _wsDataUri;
  Uri _wsUpdateUri;
  Uri _httpDataUri;
  Uri _httpUpdateUri;

  DsHttpClientSession(String conn, String dsIdPrefix, DsPrivateKey privateKey, {DsNodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : _privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.modulusHash64}',
        requester = isRequester ? new DsRequester() : null,
        responder = (isResponder && nodeProvider != null) ? new DsResponder(nodeProvider) : null {
    // TODO don't put everything in constructor
    // TODO more error handling
    HttpClient client = new HttpClient();
    Uri connUri = Uri.parse(conn);
    client.getUrl(connUri).then((HttpClientRequest request) {
      request.headers.add('ds-id', dsId);
      request.headers.add('ds-public-key', privateKey.publicKey.modulusBase64);
      request.headers.add('ds-is-requester', isRequester.toString());
      request.headers.add('ds-is-responder', (isResponder && nodeProvider != null).toString());
      request.close().then((HttpClientResponse response) {
        try {
          saltNameMap.forEach((name, idx) {
            //read salts
            salts[idx] = response.headers.value(name);
          });
          String encryptedNonce = response.headers.value('ds-encrypted-nonce');
          _nonce = _privateKey.decryptNonce(encryptedNonce);
        } catch (err) {
          print(err);
          return;
        }
        response.toList().then((List<List<int>> lists) {
          try {
            List<int> merged = lists.fold([], (List a, List b) {
              return a..addAll(b);
            });
            String rslt = UTF8.decode(merged);
            Map serverConfig = JSON.decode(rslt);
            if (serverConfig['ws-data-uri'] is String) {
              _wsDataUri = connUri.resolve(serverConfig['ws-data-uri']);
            }
            if (serverConfig['ws-update-uri'] is String) {
              _wsUpdateUri = connUri.resolve(serverConfig['ws-update-uri']);
            }
            if (serverConfig['http-data-uri'] is String) {
              _httpDataUri = connUri.resolve(serverConfig['http-data-uri']);
            }
            if (serverConfig['http-update-uri'] is String) {
              _httpUpdateUri = connUri.resolve(serverConfig['http-update-uri']);
            }
            // start requester and responder
            if (requester != null && _wsDataUri != null) {
              initWebsocketRequester();
            }
            if (responder != null && _wsUpdateUri != null) {
              initWebsocketResponder();
            }
          } catch (err) {
            print(err);
            return;
          }
        });
      });
    });
  }
  void initWebsocketRequester() {
    WebSocket.connect(_wsDataUri.toString()).then((WebSocket socket) {
      _requesterConn = new DsWebsocketConnection(socket);
      requester.connection = _requesterConn;
    });

  }

  void initWebsocketResponder() {

  }
}
