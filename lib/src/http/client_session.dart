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

  String _wsUpdateUri;
  String _httpUpdateUri;

  DsHttpClientSession(String conn, String dsIdPrefix, DsPrivateKey privateKey, {DsNodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : _privateKey = privateKey,
        dsId = '$dsIdPrefix${privateKey.publicKey.modulusHash64}',
        requester = isRequester ? new DsRequester() : null,
        responder = (isResponder && nodeProvider != null) ? new DsResponder(nodeProvider) : null {
    // TODO don't put everything in constructor
    // TODO more error handling
    HttpClient client = new HttpClient();
    Uri connUri = Uri.parse('$conn?dsId=$dsId');
    client.postUrl(connUri).then((HttpClientRequest request) {
      Map requestJson = {
        'publicKey': privateKey.publicKey.modulusBase64,
        'isRequester': isRequester,
        'isResponder': (isResponder && nodeProvider != null)
      };

      request.add(jsonUtf8Encoder.convert(requestJson));
      request.close().then((HttpClientResponse response) {
        print(response.headers);

        response.toList().then((List<List<int>> lists) {
          try {
            List<int> merged = lists.fold([], (List a, List b) {
              return a..addAll(b);
            });
            String rslt = UTF8.decode(merged);
            Map serverConfig = JSON.decode(rslt);

            saltNameMap.forEach((name, idx) {
              //read salts
              salts[idx] = serverConfig[name];
            });
            String encryptedNonce = serverConfig['encryptedNonce'];
            _nonce = _privateKey.decryptNonce(encryptedNonce);

            if (serverConfig['wsUri'] is String) {
              _wsUpdateUri = '${connUri.resolve(serverConfig['wsUri'])}?dsId=$dsId'.replaceFirst('http', 'ws');
            }
            if (serverConfig['httpUri'] is String) {
              // TODO implement http
              _httpUpdateUri = '${connUri.resolve(serverConfig['httpUri'])}?dsId=$dsId';
            }
            // start requester and responder
            if (_wsUpdateUri != null) {
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
    WebSocket.connect('$_wsUpdateUri&auth=${_nonce.hashSalt(salts[0])}').then((WebSocket socket) {
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
