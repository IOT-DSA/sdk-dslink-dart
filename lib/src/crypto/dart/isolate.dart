part of dslink.pk.dart;

ECPrivateKey _cachedPrivate;
ECPublicKey _cachedPublic;
int _cachedTime = -1;
String cachedPrivateStr;

List generate(List publicKeyRemote, String oldPriKeyStr) {
  ECPoint publicPointRemote = _secp256r1.curve.decodePoint(publicKeyRemote);
  ECPrivateKey privateKey;
  ECPublicKey publicKey;
  int ts = (new DateTime.now()).millisecondsSinceEpoch;
  if (cachedPrivateStr == null ||
      ts - _cachedTime > 60000 ||
      oldPriKeyStr == cachedPrivateStr ||
      oldPriKeyStr == '') {
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars,
        DartCryptoProvider.INSTANCE.random);
    gen.init(params);
    var pair = gen.generateKeyPair();
    privateKey = pair.privateKey;
    publicKey = pair.publicKey;
    if (oldPriKeyStr != '') {
      _cachedPrivate = pair.privateKey;
      _cachedPublic = pair.publicKey;
      _cachedTime = ts;
    }
  } else {
    privateKey = _cachedPrivate;
    publicKey = _cachedPublic;
  }

  var Q2 = publicPointRemote * privateKey.d;
  return [
    privateKey.d.toByteArray(),
    publicKey.Q.getEncoded(false),
    Q2.getEncoded(false)
  ];
}

void _processECDH(SendPort initialReplyTo) {
  var response = new ReceivePort();
  initialReplyTo.send(response.sendPort);
  response.listen((msg) {
    if (msg is List && msg.length == 2) {
      initialReplyTo.send(generate(msg[0], msg[1]));
    }
  });
}

class ECDHIsolate {
  static bool get running => _ecdh_isolate != null;
  static Isolate _ecdh_isolate;
  static start() async {
    if (_ecdh_isolate != null) return;
    var response = new ReceivePort();
    _ecdh_isolate = await Isolate.spawn(_processECDH, response.sendPort);
    response.listen(_processResult);
    _checkRequest();
  }

  static SendPort _isolatePort;
  static void _processResult(message) {
    if (message is SendPort) {
      _isolatePort = message;
    } else if (message is List) {
      if (_waitingReq != null && message.length == 3) {
        var d1 = new BigInteger.fromBytes(1, message[0]);
        var Q1 = _secp256r1.curve.decodePoint(message[1]);
        var Q2 = _secp256r1.curve.decodePoint(message[2]);
        var ecdh = new ECDHImpl(
            new ECPrivateKey(d1, _secp256r1), new ECPublicKey(Q1, _secp256r1),
            Q2);
        _waitingReq._completer.complete(ecdh);
        _waitingReq = null;
      }
    }
    _checkRequest();
  }

  static ECDHIsolateRequest _waitingReq;
  static void _checkRequest() {
    if (_waitingReq == null && _requests.length > 0) {
      _waitingReq = _requests.removeFirst();
      _isolatePort.send([
        _waitingReq.publicKeyRemote.ecPublicKey.Q.getEncoded(false),
        _waitingReq.oldPrivate
      ]);
    }
  }

  static ListQueue<ECDHIsolateRequest> _requests =
      new ListQueue<ECDHIsolateRequest>();

  /// when oldprivate is '', don't use cache
  static Future<ECDH> _sendRequest(
      PublicKey publicKeyRemote, String oldprivate) {
    var req = new ECDHIsolateRequest(publicKeyRemote, oldprivate);
    _requests.add(req);
    _checkRequest();
    return req.future;
  }
}

class ECDHIsolateRequest {
  PublicKeyImpl publicKeyRemote;
  String oldPrivate;

  ECDHIsolateRequest(this.publicKeyRemote, this.oldPrivate);

  Completer<ECDH> _completer = new Completer<ECDH>();
  Future<ECDH> get future => _completer.future;
}
