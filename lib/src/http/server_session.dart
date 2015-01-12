part of dslink.http_server;

/// a server session for both http and ws
class DsHttpServerSession implements DsSession {
  final String dsId;

  final DsRequester requester;
  final DsResponder responder;
  final DsPublicKey _publicKey;

  /// nonce for authentication, don't overwrite existing nonce
  DsSecretNonce _tempNonce;
  /// nonce after user verified the public key
  DsSecretNonce _verifiedNonce;

  DsWebSocketConnection _connection;

  /// 2 salts, salt saltS
  final List<int> salts = new List<int>(2);

  DsHttpServerSession(this.dsId, BigInteger modulus, {DsNodeProvider nodeProvider, bool isRequester: true, bool isResponder: true})
      : _publicKey = new DsPublicKey(modulus),
        requester = isRequester ? new DsRequester() : null,
        responder = (isResponder && nodeProvider != null) ? new DsResponder(nodeProvider) : null {
    for (int i = 0; i < 4; ++i) {
      salts[i] = DsaRandom.instance.nextUint8();
    }
  }
  /// check if public key matchs the dsId
  bool get valid {
    return _publicKey.verifyDsId(dsId);
  }

  void initSession(HttpRequest request) {
    _tempNonce = new DsSecretNonce.generate();

    // TODO, dont use hard coded id and public key
    request.response.write(r'''{
  "id":"broker-dsa-5PjTP4kGLqxAAykKBU1MDUb0diZNOUpk_Au8MWxtCYa2YE_hOFaC8eAO6zz6FC0e",
  "publicKey":"AIHYvVkY5M_uMsRI4XmTH6nkngf2lMLXOOX4rfhliEYhv4Hw1wlb_I39Q5cw6a9zHSvonI8ZuG73HWLGKVlDmHGbYHWsWsXgrAouWt5H3AMGZl3hPoftvs0rktVsq0L_pz2Cp1h_7XGot87cLah5IV-AJ5bKBBFkXHOqOsIiDXNFhHjSI_emuRh01LmaN9_aBwfkyNq73zP8kY-hpb5mEG-sIcLvMecxsVS-guMFRCk_V77AzVCwOU52dmpfT5oNwiWhLf2n9A5GVyFxxzhKRc8NrfSdTFzKn0LvDPM29UDfzGOyWpfJCwrYisrftC3QbBD7e0liGbMCN5UgZsSssOk=",
  "wsUri":"/ws_data",
  "httpUri":"/http_update",
  "encryptedNonce":_publicKey.encryptNonce(_tempNonce),
  "salt":,'0x${salts[0]}',
  "saltS":,'1x${salts[1]}',
  "min-update-interval-ms":200
}
''');
    request.response.close();
  }

  bool _verifySalt(int type, String hash) {
    if (hash == null) {
      return false;
    }
    if (_verifiedNonce != null && _verifiedNonce.verifySalt('${type}x${salts[type]}', hash)) {
      salts[type] += DsaRandom.instance.nextUint8() + 1;
      return true;
    } else if (_tempNonce != null && _tempNonce.verifySalt('${type}x${salts[type]}', hash)) {
      salts[type] += DsaRandom.instance.nextUint8() + 1;
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
  void _handleHttpUpdate(HttpRequest request) {
    if (!_verifySalt(2, request.headers.value('auth'))) {
      throw HttpStatus.UNAUTHORIZED;
    }
    if (requester == null) {
      throw HttpStatus.FORBIDDEN;
    }
    //TODO
  }
  void _handleHttpData(HttpRequest request) {
    if (!_verifySalt(0, request.headers.value('auth'))) {
      throw HttpStatus.UNAUTHORIZED;
    }
    if (responder == null) {
      throw HttpStatus.FORBIDDEN;
    }
    //TODO
  }

  void _handleWsUpdate(HttpRequest request) {
    if (!_verifySalt(2, request.headers.value('auth'))) {
      throw HttpStatus.UNAUTHORIZED;
    }

    WebSocketTransformer.upgrade(request).then((WebSocket websocket) {
      _connection = new DsWebSocketConnection(websocket);
      if (responder != null) {
        responder.connection = _connection.responderChannel;
      }
      if (requester != null) {
        requester.connection = _connection.requesterChannel;
      }
    });
  }

}
