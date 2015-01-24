library dslink.pk;

import 'package:bignum/bignum.dart';
import "package:cipher/cipher.dart";
import "package:cipher/digests/sha256.dart";
import "package:cipher/key_generators/rsa_key_generator.dart";
import "package:cipher/params/key_generators/rsa_key_generator_parameters.dart";
import "package:cipher/random/secure_random_base.dart";
import "package:cipher/random/block_ctr_random.dart";
import "package:cipher/block/aes_fast.dart";
import 'dart:typed_data';
import '../../utils.dart';
import 'dart:math' as Math;
import 'dart:convert';

class SecretNonce {
  Uint8List bytes;

  SecretNonce(this.bytes);

  SecretNonce.generate() {
    bytes = new Uint8List(16);
    for (int i = 0; i < 16; ++i) {
      bytes[i] = DSRandom.instance.nextUint8();
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
    var hashed = sha256.process(new Uint8List.fromList(raw));
    return Base64.encode(hashed);
  }

  bool verifySalt(String salt, String hash) {
    return hashSalt(salt) == hash;
  }
}

class PublicKey {
  static final BigInteger publicExp = new BigInteger(65537);

  final BigInteger modulus;
  String modulusBase64;
  String modulusHash64;

  PublicKey(this.modulus) {
    List bytes = bigintToUint8List(modulus);
    modulusBase64 = Base64.encode(bytes);
    SHA256Digest sha256 = new SHA256Digest();
    modulusHash64 = Base64.encode(sha256.process(bytes));
  }

  String getDsId(String prefix) {
    return '$prefix$modulusHash64';
  }

  bool verifyDsId(String dsId) {
    return (dsId.length >= 43 && dsId.substring(dsId.length - 43) == modulusHash64);
  }

  String encryptNonce(SecretNonce nonce) {
    // TODO optional security enhancement, add more bytes infront of the 16 bytes nonce
    BigInteger A = new BigInteger.fromBytes(1, nonce.bytes);
    BigInteger E = A.modPow(publicExp, modulus);
    Uint8List encrypted = bigintToUint8List(E);
    return Base64.encode(encrypted);
  }
}

class PrivateKey {
  PublicKey publicKey;
  final BigInteger modulus;
  final BigInteger exponent;
  /// optional, not really needed
  final BigInteger p, q;

  PrivateKey(this.modulus, this.exponent, [this.p, this.q]) {
    publicKey = new PublicKey(modulus);
  }

  factory PrivateKey.generate() {
    var gen = new RSAKeyGenerator();
    var rnd = new DSRandom();
    var rsapars = new RSAKeyGeneratorParameters(PublicKey.publicExp, 2048, 32);
    var params = new ParametersWithRandom(rsapars, rnd);
    gen.init(params);
    var pair = gen.generateKeyPair();
    RSAPrivateKey key = pair.privateKey;
    return new PrivateKey(key.modulus, key.exponent, key.p, key.q);
  }

  factory PrivateKey.loadFromString(String str) {
    Map m = _parseOpensslTextKey(str);

    if (m['publicExponent'] == ' 65537 (0x10001)') {
      // load a plain text openssl private key generated with following commands
      // > openssl genrsa -out private.pem 2048
      // > openssl rsa -text -in private.pem -out private.txt
      BigInteger modulus = new BigInteger()..fromString(m['modulus'], 16);
      BigInteger exponent = new BigInteger()..fromString(m['privateExponent'], 16);
      BigInteger p = new BigInteger()..fromString(m['prime1'], 16);
      BigInteger q = new BigInteger()..fromString(m['prime2'], 16);
      return new PrivateKey(modulus, exponent, p, q);
    } else {
      // load a key file generated with saveToString()
      BigInteger modulus = new BigInteger.fromBytes(1, Base64.decode(m['m']));
      BigInteger exponent = new BigInteger.fromBytes(1, Base64.decode(m['e']));
      BigInteger p = new BigInteger.fromBytes(1, Base64.decode(m['p']));
      BigInteger q = new BigInteger.fromBytes(1, Base64.decode(m['q']));
      return new PrivateKey(modulus, exponent, p, q);
    }
  }

  SecretNonce decryptNonce(String nonce) {
    Uint8List encrypted = Base64.decode(nonce);
    BigInteger E = new BigInteger.fromBytes(1, encrypted);
    BigInteger D = E.modPow(exponent, modulus);
    Uint8List decrypted = bigintToUint8List(D);
    if (decrypted.length < 16) {
      int nMissing = 16 - decrypted.length;
      Uint8List d = new Uint8List(16);
      for (int i = 0; i < decrypted.length; ++i) {
        d[nMissing + i] = decrypted[i];
      }
      decrypted = d;
    } else if (decrypted.length > 16) {
      // shoudln't happen now, but we might want to add some random bytes before the 16 bytes to make it more secure
      decrypted = decrypted.sublist(decrypted.length - 16);
    }
    return new SecretNonce(decrypted);
  }

  String saveToString() {
    StringBuffer sb = new StringBuffer();
    sb.write('m:\n');
    sb.write(Base64.encode(bigintToUint8List(modulus), 44, 2));
    sb.write('\ne:\n');
    sb.write(Base64.encode(bigintToUint8List(exponent), 44, 2));
    if (p != null && q != null) {
      sb.write('\np:\n');
      sb.write(Base64.encode(bigintToUint8List(p), 44, 2));
      sb.write('\nq:\n');
      sb.write(Base64.encode(bigintToUint8List(q), 44, 2));
    }
    return sb.toString();
  }
}


/// parse key file, works for both dsa key file and openssl plain text key file
Map _parseOpensslTextKey(String str) {
  var rslt = {};
  var lines = str.replaceAll('\r\n', '\n').split('\n');

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
  if (r.data[0] == 0) { // have ended up with an extra zero byte, copy down.
    return new Uint8List.fromList(r.data.sublist(1));
  }
  return new Uint8List.fromList(r.data);
}
