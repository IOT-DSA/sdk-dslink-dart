library dslink.pk;

import 'package:bignum/bignum.dart';
import "package:cipher/cipher.dart";
import "package:cipher/digests/sha384.dart";
import "package:cipher/digests/sha256.dart";
import "package:cipher/key_generators/rsa_key_generator.dart";
import "package:cipher/params/key_generators/rsa_key_generator_parameters.dart";
import "package:cipher/random/secure_random_base.dart";
import "package:cipher/random/block_ctr_random.dart";
import "package:cipher/block/aes_fast.dart";
import 'package:cipher/asymmetric/rsa.dart';
import 'dart:typed_data';
import '../../utils.dart';
import 'dart:math' as Math;
import 'dart:convert';


class DsSecretNonce {
  Uint8List bytes;

  DsSecretNonce(this.bytes);

  DsSecretNonce.generate() {
    bytes = new Uint8List(16);
    for (int i = 0; i < 16; ++i) {
      bytes[i] = DsaRandom.instance.nextUint8();
    }
  }

  String toString() {
    return 'DsSecretNonce: ${Base64.encode(bytes)}';
  }

  String hashSalt(String salt) {
    List raw = []
        ..addAll(UTF8.encode(salt))
        ..addAll(bytes);
    SHA256Digest sha256 = new SHA256Digest();
    return Base64.encode(sha256.process(bytes));
  }

  bool verifySalt(String salt, String hash) {
    return hashSalt(salt) == hash;
  }
}

class DsPublicKey {
  static final BigInteger _publicExp = new BigInteger(65537);

  RSAPublicKey rsaPublicKey;
  String modulusBase64;
  String modulusHash64;

  DsPublicKey(BigInteger modulus) {
    rsaPublicKey = new RSAPublicKey(modulus, _publicExp);
    List bytes = _bigintToUint8List(modulus);
    modulusBase64 = Base64.encode(bytes);
    SHA384Digest sha384 = new SHA384Digest();
    modulusHash64 = Base64.encode(sha384.process(bytes));
  }

  String getDsaId(String prefix) {
    return '$prefix-$modulusHash64';
  }
  bool verifyDsId(String dsId) {
    return (dsId.length >= 64 && dsId.substring(dsId.length - 64) == modulusHash64);
  }

  String encryptNonce(DsSecretNonce nonce) {
    var pubpar = new PublicKeyParameter<RSAPublicKey>(rsaPublicKey);
    RSAEngine encrypt = new RSAEngine();
    encrypt.init(true, pubpar);
    var encrypted = encrypt.process(nonce.bytes);
    return Base64.encode(encrypted);
  }
}

class DsPrivateKey {
  DsPublicKey publicKey;
  RSAPrivateKey rsaPrivateKey;
  AsymmetricKeyPair keyPair;

  DsPrivateKey(BigInteger modulus, BigInteger exponent, BigInteger p, BigInteger q) {
    publicKey = new DsPublicKey(modulus);
    rsaPrivateKey = new RSAPrivateKey(modulus, exponent, p, q);
    keyPair = new AsymmetricKeyPair(publicKey.rsaPublicKey, rsaPrivateKey);
  }

  factory DsPrivateKey.generate() {
    var gen = new RSAKeyGenerator();
    var rnd = new DsaRandom();
    var rsapars = new RSAKeyGeneratorParameters(DsPublicKey._publicExp, 2048, 12);
    var params = new ParametersWithRandom(rsapars, rnd);
    gen.init(params);
    var pair = gen.generateKeyPair();
    RSAPrivateKey key = pair.privateKey;
    return new DsPrivateKey(key.modulus, key.exponent, key.p, key.q);
  }

  factory DsPrivateKey.loadFromString(String str) {
    Map m = _parseOpensslTextKey(str);

    if (m['publicExponent'] == ' 65537 (0x10001)') {
      // load a plain text openssl private key generated with following commands
      // > openssl genrsa -out private.pem 2048
      // > openssl rsa -text -in private.pem -out private.txt
      BigInteger modulus = new BigInteger()..fromString(m['modulus'], 16);
      BigInteger exponent = new BigInteger()..fromString(m['privateExponent'], 16);
      BigInteger p = new BigInteger()..fromString(m['prime1'], 16);
      BigInteger q = new BigInteger()..fromString(m['prime2'], 16);
      return new DsPrivateKey(modulus, exponent, p, q);
    } else {
      // load a key file generated with saveToString()
      BigInteger modulus = new BigInteger.fromBytes(1, Base64.decode(m['m']));
      BigInteger exponent = new BigInteger.fromBytes(1, Base64.decode(m['e']));
      BigInteger p = new BigInteger.fromBytes(1, Base64.decode(m['p']));
      BigInteger q = new BigInteger.fromBytes(1, Base64.decode(m['q']));
      return new DsPrivateKey(modulus, exponent, p, q);
    }
  }

  DsSecretNonce decryptNonce(String nonce) {
    var privpar = new PrivateKeyParameter<RSAPrivateKey>(rsaPrivateKey);
    RSAEngine decrypt = new RSAEngine();
    decrypt.init(false, privpar);
    var decrypted = decrypt.process(Base64.decode(nonce));
    return new DsSecretNonce(decrypted);
  }

  String saveToString() {
    StringBuffer sb = new StringBuffer();
    sb.write('m:\n');
    sb.write(Base64.encode(rsaPrivateKey.modulus.toByteArray(), 44, 2));
    sb.write('\ne:\n');
    sb.write(Base64.encode(rsaPrivateKey.exponent.toByteArray(), 44, 2));
    sb.write('\np:\n');
    sb.write(Base64.encode(rsaPrivateKey.p.toByteArray(), 44, 2));
    sb.write('\nq:\n');
    sb.write(Base64.encode(rsaPrivateKey.q.toByteArray(), 44, 2));
    return sb.toString();
  }
}


/// parse key file, works for both dsa key file and openssl plain text key file
Map _parseOpensslTextKey(String str) {
  var rslt = {};
  var lines = str.split('\n');

  for (int i = 0; i < lines.length; ++i) {
    String line = lines[i];
    String hex = '';
    if (line.endsWith(':')) {
      for (i = i + 1; i < lines.length; ++i) {
        String data = lines[i];
        if (!data.startsWith(' ')) {
          if (hex.length > 0) {
            --i;
          }
          break;
        }
        hex += data.trim();
      }
      rslt[line.substring(0, line.length - 1)] = hex;
    } else if (line.contains(':')) {
      List arr = line.split(':');
      if (arr.length == 2) {
        rslt[arr[0]] = arr[1];
      }
    }
  }
  return rslt;
}

/// random number generator
class DsaRandom extends SecureRandomBase {
  static final DsaRandom instance = new DsaRandom();

  BlockCtrRandom _delegate;
  AESFastEngine _aes;

  String get algorithmName => _delegate.algorithmName;

  DsaRandom([int seed = -1]) {
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

/// BigInteger.toByteArray contains negative values, so we need a different version
Uint8List _bigintToUint8List(BigInteger input) {
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
  return new Uint8List.fromList(r.data);
}
