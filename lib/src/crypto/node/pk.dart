library dslink.pk.node;

import '../pk.dart';

import 'dart:typed_data';
import 'dart:async';
import 'dart:js';

JsObject _context = (const bool.fromEnvironment("calzone.browser", defaultValue: false)) ? context["__iot_dsa__"] : context;

require(String input) => _context.callMethod("require", [input]);

JsObject _toObj(obj) {
  if(obj is JsObject || obj == null)
    return obj;
  return new JsObject.fromBrowserObject(obj);
}

String _urlSafe(String base64) {
  return base64.replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

JsObject _crypto = require('crypto');
JsObject _curve = require('dhcurve');

String _hash(obj) {
  JsObject hash = _crypto.callMethod("createHash", ["sha256"]);
  hash.callMethod('update', [obj]);
  return _urlSafe(hash.callMethod('digest', ['base64']));
}

class NodeCryptoProvider implements CryptoProvider {
  static final NodeCryptoProvider INSTANCE = new NodeCryptoProvider();
  final DSRandom random = new DSRandomImpl();

  PrivateKey _cachedPrivate;
  int _cachedTime = -1;

  Future<ECDH> assign(PublicKeyImpl publicKeyRemote, ECDH old) async {
    int ts = (new DateTime.now()).millisecondsSinceEpoch;

    /// reuse same ECDH server pair for up to 1 minute
    if (_cachedPrivate == null ||
        ts - _cachedTime > 60000 ||
        (old is ECDHImpl && old.privateKey == _cachedPrivate)) {

      _cachedPrivate = generateSync();

      _cachedTime = ts;
    }

    return _cachedPrivate.getSecret(publicKeyRemote.qBase64);
  }

  Future<ECDH> getSecret(PublicKeyImpl publicKeyRemote) async {
    return generateSync().getSecret(publicKeyRemote.qBase64);
  }

  Future<PrivateKey> generate() async {
    return generateSync();
  }

  PrivateKey generateSync() {
    var keys = _curve.callMethod("generateKeyPair", ["prime256v1"]);

    var publicKey = new PublicKeyImpl(_toObj(keys["publicKey"]));
    return new PrivateKeyImpl(publicKey, _toObj(keys["privateKey"]));
  }

  PrivateKey loadFromString(String str) {
    List parts = str.split(' ');

    var privateKeyBuf = new JsObject(_context["Buffer"], [parts[0], "base64"]);

    var privateKey = new JsObject(_curve["PrivateKey"], ["prime256v1", privateKeyBuf]);
    var publicKey = privateKey.callMethod("getPublicKey", []);

    return new PrivateKeyImpl(new PublicKeyImpl(_toObj(publicKey)), _toObj(privateKey));
  }

  PublicKey getKeyFromBytes(Uint8List bytes) {
    var buf = listToBuf(bytes);
    return new PublicKeyImpl(_toObj(_curve["Point"].callMethod("fromEncoded", ["prime256v1", buf])));
  }
}

class ECDHImpl extends ECDH {
  String get encodedPublicKey => publicKey._point.callMethod("toEncoded");

  PublicKeyImpl publicKey;
  PrivateKeyImpl privateKey;

  JsObject _buffer;

  ECDHImpl(this._buffer, this.publicKey, this.privateKey);

  String hashSalt(String salt) {
    var saltBuffer = new JsObject(_context["Buffer"], [salt]);

    var newBuffer = new JsObject(_context["Buffer"], [saltBuffer["length"] + _buffer["length"]]);

    saltBuffer.callMethod("copy", [newBuffer, 0]);
    _buffer.callMethod("copy", [newBuffer, saltBuffer["length"]]);

    return _hash(newBuffer);
  }
}

class PublicKeyImpl extends PublicKey {
  JsObject _point;

  String qBase64;
  String qHash64;

  PublicKeyImpl(this._point) {
    var encoded = _toObj(_point.callMethod('getEncoded', []));

    qBase64 = _urlSafe(encoded.callMethod('toString', ['base64']));
    qHash64 = _hash(encoded);
  }
}

class PrivateKeyImpl implements PrivateKey {
  PublicKey publicKey;
  JsObject _privateKey;

  PrivateKeyImpl(this.publicKey, this._privateKey);

  String saveToString() {
    return _urlSafe(_toObj(_privateKey["d"]).callMethod("toString", ["base64"])) + " ${publicKey.qBase64}";
  }

  Future<ECDH> getSecret(String key) async {
    var buf = new JsObject(_context["Buffer"], [key, "base64"]);
    var point = _curve["Point"].callMethod("fromEncoded", ["prime256v1", buf]);
    var secret = _privateKey.callMethod("getSharedSecret", [point]);

    return new Future.value(new ECDHImpl(_toObj(secret), publicKey, this));
  }
}

class DSRandomImpl extends DSRandom {
  bool get needsEntropy => false;

  int nextUint8() {
    return _crypto.callMethod("randomBytes", [1]).callMethod("readUInt8", [0]);
  }

  void addEntropy(String str) {}
}

JsObject listToBuf(Uint8List bytes) {
  var length = bytes.length;
  var buf = new JsObject(_context["Buffer"], [length]);

  var offset = 0;
  for(var byte in bytes) {
    if(offset >= length)
      break;
    buf.callMethod("writeUInt8", [byte, offset]);
    offset++;
  }

  return buf;
}
