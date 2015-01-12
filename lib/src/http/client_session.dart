part of dslink.client;

/// a client session for both http and ws
class DsHttpClientSession implements DsSession {
  final String dsId;

  final DsRequester requester;
  final DsResponder responder;
  final DsPrivateKey _privateKey;

  DsSecretNonce _nonce;

  DsConnection _connection;


  static const Map<String, int> saltNameMap = const {
    'salt': 0,
    'saltS': 1,
  };
  /// 4 salts, reqSaltL reqSaltS respSaltL respSaltS
  final List<String> salts = new List<String>(4);

  Uri _wsUpdateUri;
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
    client.postUrl(connUri).then((HttpClientRequest request) {
      request.headers.add('ds-id', dsId);
      request.headers.add('ds-public-key', privateKey.publicKey.modulusBase64);
      request.headers.add('ds-is-requester', isRequester.toString());
      request.headers.add('ds-is-responder', (isResponder && nodeProvider != null).toString());
      request.close().then((HttpClientResponse response) {
        print(response.headers);
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
            if (serverConfig['ws-update-uri'] is String) {
              _wsUpdateUri = connUri.resolve(serverConfig['wsUri']);
            }
            if (serverConfig['http-update-uri'] is String) {
              // TODO implement http
              _httpUpdateUri = connUri.resolve(serverConfig['httpUri']);
            }
            // start requester and responder
            if (responder != null && _wsUpdateUri != null) {
              initWebsocket();
            }
          } catch (err) {
            print(err);
            return;
          }
        });
      });
    });
  }
  void initWebsocket() {
    WebSocket.connect(_wsUpdateUri.toString()).then((WebSocket socket) {
      _connection = new DsWebSocketConnection(socket);
      if (requester != null) {
        requester.connection = _connection.requesterChannel;
      }
      if (responder != null) {
        responder.connection = _connection.responderChannel;
      }
    });

  }

  void initWebsocketResponder() {

  }
}
