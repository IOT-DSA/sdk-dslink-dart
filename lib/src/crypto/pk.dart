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

/// hard code the EC curve data here, so the compiler don't have to register all curves
ECDomainParameters _secp256r1 = () {
  BigInteger q = new BigInteger("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", 16);
  BigInteger a = new BigInteger("ffffffff00000001000000000000000000000000fffffffffffffffffffffffc", 16);
  BigInteger b = new BigInteger("5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b", 16);
  BigInteger g = new BigInteger("046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5", 16);
  BigInteger n = new BigInteger("ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", 16);
  BigInteger h = new BigInteger("1", 16);
  BigInteger seed = new BigInteger("c49d360886e704936a6678e1139d26b7819f7e90", 16);
  var seedBytes = seed.toByteArray();
  
  var curve = new fp.ECCurve(q, a, b);

  return new ECDomainParametersImpl('secp256r1', curve, curve.decodePoint(g.toByteArray()), n, h, seedBytes);
}();


class ECDH {
  Uint8List bytes;

  ECPrivateKey ecPrivateKey;
  ECPublicKey ecPublicKey;

  ECPublicKey ecPublicKeyRemote;

  ECDH(this.ecPublicKeyRemote, [this.ecPrivateKey, this.ecPublicKey]) {
    var Q2 = ecPublicKeyRemote.Q * ecPrivateKey.d;
    bytes = bigintToUint8List(Q2.x.toBigInteger());
  }
  factory ECDH.generate(PublicKey publicKeyRemote) {
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars, DSRandom.instance);
    gen.init(params);
    var pair = gen.generateKeyPair();
    return new ECDH(publicKeyRemote.ecPublicKey, pair.privateKey, pair.publicKey);
  }

  String toString() {
    return 'DsSecretNonce: ${Base64.encode(bytes)}';
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

  String encodeECDH(ECDH ecdh) {
    return Base64.encode(ecdh.ecPublicKey.Q.getEncoded(false));
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


  factory PrivateKey.generate() {
    var gen = new ECKeyGenerator();
    var rsapars = new ECKeyGeneratorParameters(_secp256r1);
    var params = new ParametersWithRandom(rsapars, DSRandom.instance);
    gen.init(params);
    var pair = gen.generateKeyPair();
    return new PrivateKey(pair.privateKey, pair.publicKey);
  }

  factory PrivateKey.loadFromString(String str) {
    var d = new BigInteger.fromBytes(1, Base64.decode(str));
    return new PrivateKey(new ECPrivateKey(d, _secp256r1));
  }
  String saveToString() {
    return Base64.encode(bigintToUint8List(ecPrivateKey.d));
  }

  ECDH decodeECDH(String key) {
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
    final keyBytes = [r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256)];
    final key = new KeyParameter(new Uint8List.fromList(keyBytes));
    r = new Math.Random((new DateTime.now()).millisecondsSinceEpoch);
    final iv = new Uint8List.fromList([r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256)]);
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
    for (var offset = 0; offset < bytes.lengthInBytes; ) {
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
  var this_array = input.array;
  var i = input.t;
  JSArray<int> r = new JSArray<int>();
  r[0] = input.s;
  var p = BigInteger.BI_DB - (i * BigInteger.BI_DB) % 8,
      d,
      k = 0;
  if (i-- > 0) {
    if (p < BigInteger.BI_DB && (d = this_array[i] >> p) != (input.s & BigInteger.BI_DM) >> p) {
      r[k++] = d | (input.s << (BigInteger.BI_DB - p));
    }

    while (i >= 0) {
      if (p < 8) {
        d = (this_array[i] & ((1 << p) - 1)) << (8 - p);
        d |= this_array[--i] >> (p += BigInteger.BI_DB - 8);
      } else {
        d = (this_array[i] >> (p -= 8)) & 0xff;
        if (p <= 0) {
          p += BigInteger.BI_DB;
          --i;
        }
      }
      if (d < 0) d |= -256;
      if (k == 0 && (input.s & 0x80) != (d & 0x80)) ++k;
      if (k > 0 || d != input.s) r[k++] = d;
    }
  }
  if (r.data[0] == 0) {
    // have ended up with an extra zero byte, copy down.
    return new Uint8List.fromList(r.data.sublist(1));
  }
  return new Uint8List.fromList(r.data);
}
