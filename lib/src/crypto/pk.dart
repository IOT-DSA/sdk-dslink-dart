library dslink.pk;

import 'dart:async';
import 'dart:typed_data';

import 'dart/pk.dart' show DartCryptoProvider;

CryptoProvider _CRYPTO_PROVIDER = DartCryptoProvider.INSTANCE;
bool _isCryptoProviderLocked = false;

setCryptoProvider(CryptoProvider provider) {
  if(_isCryptoProviderLocked)
    throw new StateError("crypto provider is locked");
  _CRYPTO_PROVIDER = provider;
  _isCryptoProviderLocked = true;
}

lockCryptoProvider() => _isCryptoProviderLocked = true;

abstract class CryptoProvider {
  DSRandom get random;

  Future<ECDH> assign(PublicKey publicKeyRemote, ECDH old);
  Future<ECDH> getSecret(PublicKey publicKeyRemote);

  Future<PrivateKey> generate();
  PrivateKey generateSync();

  PrivateKey loadFromString(String str);

  PublicKey getKeyFromBytes(Uint8List bytes);
}

abstract class ECDH {
  String get encodedPublicKey;

  static Future<ECDH> assign(PublicKey publicKeyRemote, ECDH old) async =>
    _CRYPTO_PROVIDER.assign(publicKeyRemote, old);

  String hashSalt(String salt);

  bool verifySalt(String salt, String hash) {
    return hashSalt(salt) == hash;
  }
}

abstract class PublicKey {
  String get qBase64;
  String get qHash64;

  PublicKey();

  factory PublicKey.fromBytes(Uint8List bytes) =>
    _CRYPTO_PROVIDER.getKeyFromBytes(bytes);

  String getDsId(String prefix) {
    return '$prefix$qHash64';
  }

  bool verifyDsId(String dsId) {
    return (dsId.length >= 43 && dsId.substring(dsId.length - 43) == qHash64);
  }
}

abstract class PrivateKey {
  PublicKey get publicKey;

  static Future<PrivateKey> generate() async =>
    _CRYPTO_PROVIDER.generate();

  factory PrivateKey.generateSync() =>
    _CRYPTO_PROVIDER.generateSync();

  factory PrivateKey.loadFromString(String str) =>
    _CRYPTO_PROVIDER.loadFromString(str);

  String saveToString();
  Future<ECDH> getSecret(String tempKey);
}

abstract class DSRandom {
  static DSRandom get instance => _CRYPTO_PROVIDER.random;
  bool get needsEntropy;

  int nextUint16() {
    var data = new ByteData(2);
    data.setUint8(0, nextUint8());
    data.setUint8(1, nextUint8());

    return data.getUint16(0);
  }

  int nextUint8();

  void addEntropy(String str);
}

class DummyECDH implements ECDH {
  final String encodedPublicKey = "";

  const DummyECDH();

  String hashSalt(String salt) {
    return '';
  }

  bool verifySalt(String salt, String hash) {
    return true;
  }
}