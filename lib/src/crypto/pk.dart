library dslink.pk;

import 'package:bignum/bignum.dart';
import "package:cipher/cipher.dart";
import "package:cipher/digests/sha256.dart";
import "package:cipher/key_generators/ec_key_generator.dart";
import "package:cipher/params/key_generators/ec_key_generator_parameters.dart";
import "package:cipher/random/secure_random_base.dart";
import "package:cipher/random/block_ctr_random.dart";
import "package:cipher/block/aes_fast.dart";
import 'dart:typed_data';
import '../../utils.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'package:cipher/ecc/ecc_base.dart';
import 'package:cipher/ecc/ecc_fp.dart' as fp;
import 'dart:async';

/// hard code the EC curve data here, so the compiler don't have to register all curves
ECDomainParameters _secp256r1 = () {
  BigInteger q = new BigInteger(
      "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", 16);
  BigInteger a = new BigInteger(
      "ffffffff00000001000000000000000000000000fffffffffffffffffffffffc", 16);
  BigInteger b = new BigInteger(
      "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b", 16);
  BigInteger g = new BigInteger(
      "046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
      16);
  BigInteger n = new BigInteger(
      "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", 16);
  BigInteger h = new BigInteger("1", 16);
  BigInteger seed =
      new BigInteger("c49d360886e704936a6678e1139d26b7819f7e90", 16);
  var seedBytes = seed.toByteArray();

  var curve = new fp.ECCurve(q, a, b);

  return new ECDomainParametersImpl(
      'secp256r1', curve, curve.decodePoint(g.toByteArray()), n, h, seedBytes);
}();

abstract class ECDH {
  
  static ECPrivateKey _cachedPrivate;
  static ECPublicKey _cachedPublic;
  static int _cachedTime = -1;
  
  static Future<ECDH> assign(PublicKey publicKeyRemote, ECDH old) async{
    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    /// reuse same ECDH server pair for up to 1 minute
    if (_cachedPrivate == null || ts - _cachedTime > 60000 || (old is ECDHImpl && old._ecPrivateKey == _cachedPrivate)) {
      var gen = new ECKeyGenerator();
      var rsapars = new ECKeyGeneratorParameters(_secp256r1);
      var params = new ParametersWithRandom(rsapars, DSRandom.instance);
      gen.init(params);
      var pair = gen.generateKeyPair();
      _cachedPrivate = pair.privateKey;
      _cachedPublic = pair.publicKey;
      _cachedTime = ts;
    }
     return new ECDHImpl(
              publicKeyRemote.ecPublicKey, _cachedPrivate, _cachedPublic);
   }
  
  static Future<ECDH> generate(PublicKey publicKeyRemote) async{
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars, DSRandom.instance);
    gen.init(params);
    var pair = gen.generateKeyPair();
    return new ECDHImpl(
        publicKeyRemote.ecPublicKey, pair.privateKey, pair.publicKey);
  }
  factory ECDH(ECPublicKey ecPublicKeyRemote, ECPrivateKey ecPrivateKey,
      ECPublicKey ecPublicKey) {
    return new ECDHImpl(ecPublicKeyRemote, ecPrivateKey, ecPublicKey);
  }
  String encodePublicKey();

  String hashSalt(String salt);

  bool verifySalt(String salt, String hash);
}
class ECDHImpl implements ECDH {
  Uint8List bytes;

  ECPrivateKey _ecPrivateKey;
  ECPublicKey _ecPublicKey;

  ECPublicKey _ecPublicKeyRemote;

  ECDHImpl(this._ecPublicKeyRemote, this._ecPrivateKey, this._ecPublicKey) {
    var Q2 = _ecPublicKeyRemote.Q * _ecPrivateKey.d;
    bytes = bigintToUint8List(Q2.x.toBigInteger());
    if (bytes.length > 32) {
      bytes = bytes.sublist(bytes.length - 32);
    } else if (bytes.length < 32) {
      var newbytes = new Uint8List(32);
      int dlen = 32 - bytes.length;
      for (int i = 0; i < bytes.length; ++i) {
        newbytes[i + dlen] = bytes[i];
      }
      for (int i = 0; i < dlen; ++i) {
        newbytes[i] = 0;
      }
      bytes = newbytes;
    }
  }

  String encodePublicKey() {
    return Base64.encode(_ecPublicKey.Q.getEncoded(false));
  }

  String hashSalt(String salt) {
    List raw = []
      ..addAll(UTF8.encode(salt))
      ..addAll(bytes);
    SHA256Digest sha256 = new SHA256Digest();
    var hashed = sha256.process(new Uint8List.fromList(raw));
    return Base64.encode(hashed);
  }

  bool verifySalt(String salt, String hash) {
    return hashSalt(salt) == hash;
  }
}

class PublicKey {
  static final BigInteger publicExp = new BigInteger(65537);

  ECPublicKey ecPublicKey;
  String qBase64;
  String qHash64;

  PublicKey(this.ecPublicKey) {
    List bytes = ecPublicKey.Q.getEncoded(false);
    qBase64 = Base64.encode(bytes);
    SHA256Digest sha256 = new SHA256Digest();
    qHash64 = Base64.encode(sha256.process(bytes));
  }
  factory PublicKey.fromBytes(Uint8List bytes) {
    ECPoint Q = _secp256r1.curve.decodePoint(bytes);
    return new PublicKey(new ECPublicKey(Q, _secp256r1));
  }

  String getDsId(String prefix) {
    return '$prefix$qHash64';
  }

  bool verifyDsId(String dsId) {
    return (dsId.length >= 43 && dsId.substring(dsId.length - 43) == qHash64);
  }
}

class PrivateKey {
  PublicKey publicKey;
  ECPrivateKey ecPrivateKey;
  ECPublicKey ecPublicKey;
  PrivateKey(this.ecPrivateKey, [this.ecPublicKey]) {
    if (ecPublicKey == null) {
      ecPublicKey = new ECPublicKey(_secp256r1.G * ecPrivateKey.d, _secp256r1);
    }
    publicKey = new PublicKey(ecPublicKey);
  }

  static Future<PrivateKey> generate() async{
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars, DSRandom.instance);
    gen.init(params);
    var pair = gen.generateKeyPair();
    return new PrivateKey(pair.privateKey, pair.publicKey);
  }

  factory PrivateKey.generateSync(){
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars, DSRandom.instance);
    gen.init(params);
    var pair = gen.generateKeyPair();
    return new PrivateKey(pair.privateKey, pair.publicKey);
  }
  factory PrivateKey.loadFromString(String str) {
    if (str.contains(' ')) {
      List ss = str.split(' ');
      var d = new BigInteger.fromBytes(1, Base64.decode(ss[0]));
      ECPrivateKey pri = new ECPrivateKey(d, _secp256r1);
      var Q = _secp256r1.curve.decodePoint(Base64.decode(ss[1]));
      ECPublicKey pub = new ECPublicKey(Q, _secp256r1);
      return new PrivateKey(pri, pub);
    } else {
      var d = new BigInteger.fromBytes(1, Base64.decode(str));
      ECPrivateKey pri = new ECPrivateKey(d, _secp256r1);
      return new PrivateKey(pri);
    }
  }
  String saveToString() {
    return '${Base64.encode(bigintToUint8List(ecPrivateKey.d))} ${publicKey.qBase64}';
  }

  ECDHImpl decodeECDH(String key) {
    ECPoint p = ecPrivateKey.parameters.curve.decodePoint(Base64.decode(key));
    return new ECDH(new ECPublicKey(p, _secp256r1), ecPrivateKey, ecPublicKey);
  }
}

/// random number generator
class DSRandom extends SecureRandomBase {
  static final DSRandom instance = new DSRandom();

  BlockCtrRandom _delegate;
  AESFastEngine _aes;

  String get algorithmName => _delegate.algorithmName;

  DSRandom([int seed = -1]) {
    _aes = new AESFastEngine();
    _delegate = new BlockCtrRandom(_aes);
    // use the native prng, but still need to use randmize to add more seed later
    Math.Random r = new Math.Random();
    final keyBytes = [
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256)
    ];
    final key = new KeyParameter(new Uint8List.fromList(keyBytes));
    r = new Math.Random((new DateTime.now()).millisecondsSinceEpoch);
    final iv = new Uint8List.fromList([
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256),
      r.nextInt(256)
    ]);
    final params = new ParametersWithIV(key, iv);
    _delegate.seed(params);
  }

  void seed(CipherParameters params) {
    _delegate.seed(params);
  }

  void randomize(String str) {
    List utf = UTF8.encode(str);
    int length2 = (utf.length).ceil() * 16;
    if (length2 > utf.length) {
      utf = utf.toList();
      while (length2 > utf.length) {
        utf.add(0);
      }
    }
    final bytes = new Uint8List.fromList(utf);

    final out = new Uint8List(16);
    for (var offset = 0; offset < bytes.lengthInBytes;) {
      var len = _aes.processBlock(bytes, offset, out, 0);
      offset += len;
    }
  }

  int nextUint8() {
    return _delegate.nextUint8();
  }
}

String bytes2hex(List<int> bytes) {
  var result = new StringBuffer();
  for (var part in bytes) {
    result.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
  }
  return result.toString();
}

/// BigInteger.toByteArray contains negative values, so we need a different version
/// this version also remove the byte for sign, so it's not able to serialize negative number
Uint8List bigintToUint8List(BigInteger input) {
  List rslt = input.toByteArray();
  if (rslt.length > 32 && rslt[0] == 0){
    rslt = rslt.sublist(1);
  }
  int len = rslt.length;
  for (int i = 0; i < len; ++i) {
    if (rslt[i] < 0) {
      rslt[i] &= 0xff; 
    }
  }
  return new Uint8List.fromList(rslt);
}
