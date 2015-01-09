part of dslink.http_server;

/// a server session for both http and ws
class DsHttpServerSession implements DsSession {
  final String dsId;
  DsSecretNonce _tempNonce;
  DsSecretNonce _verifiedNonce;
  DsPublicKey _publicKey;

  int reqSalt = DsaRandom.instance.nextUint8();
  int respSalt = DsaRandom.instance.nextUint8();

  DsHttpServerSession(this.dsId, BigInteger modulus) {
    _publicKey = new DsPublicKey(modulus);
  }
  /// check if public key matchs the dsId
  bool get valid {
    return _publicKey.verifyDsId(dsId);
  }

  void initSession(HttpRequest request) {
    _tempNonce = new DsSecretNonce.generate();
    request.response.headers.add('ds-encrypted-nonce', _tempNonce.nonce64);
    request.response.headers.add('ds-req-salt', 'q$reqSalt');
    request.response.headers.add('ds-resp-salt', 'p$respSalt');
    // TODO, dont use hard coded id and public key
    request.response.write(r'''{
  "id":"broker-dsa-5PjTP4kGLqxAAykKBU1MDUb0diZNOUpk_Au8MWxtCYa2YE_hOFaC8eAO6zz6FC0e",
  "public-key":"AIHYvVkY5M_uMsRI4XmTH6nkngf2lMLXOOX4rfhliEYhv4Hw1wlb_I39Q5cw6a9zHSvonI8ZuG73HWLGKVlDmHGbYHWsWsXgrAouWt5H3AMGZl3hPoftvs0rktVsq0L_pz2Cp1h_7XGot87cLah5IV-AJ5bKBBFkXHOqOsIiDXNFhHjSI_emuRh01LmaN9_aBwfkyNq73zP8kY-hpb5mEG-sIcLvMecxsVS-guMFRCk_V77AzVCwOU52dmpfT5oNwiWhLf2n9A5GVyFxxzhKRc8NrfSdTFzKn0LvDPM29UDfzGOyWpfJCwrYisrftC3QbBD7e0liGbMCN5UgZsSssOk=",
  "ws-data-uri":"/ws_data",
  "ws-update-uri":"/ws_update",
  "http-data-uri":"/http_data",
  "http-update-uri":"/http_update",
  "min-update-interval-ms":200
}
''');
    request.response.close();
  }

  // TODO: implement requestConn
  DsConnection get requestConn => null;

  // TODO: implement responseConn
  DsConnection get responseConn => null;
}
