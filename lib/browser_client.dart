/// Base API for DSA in the Browser
library dslink.browser_client;

import "dart:async";
import "dart:html";
import "dart:convert";
import "dart:typed_data";
import "common.dart";
import "utils.dart";
import "requester.dart";
import "responder.dart";

import "src/crypto/pk.dart";

part "src/browser/browser_user_link.dart";
part "src/browser/browser_ecdh_link.dart";
part "src/browser/browser_ws_conn.dart";

/// A Storage System for DSA Data
abstract class DataStorage {
  /// Get a key's value.
  Future<String> get(String key);

  /// Check if a key is stored.
  Future<bool> has(String key);

  /// Remove the specified key.
  Future<String> remove(String key);

  /// Store a key value pair.
  Future store(String key, String value);
}

/// Storage for DSA in Local Storage
class LocalDataStorage extends DataStorage {
  static final LocalDataStorage INSTANCE = new LocalDataStorage();

  LocalDataStorage();

  @override
  Future<String> get(String key) async => window.localStorage[key];

  @override
  Future<bool> has(String key) async => window.localStorage.containsKey(key);

  bool hasSync(String key) => window.localStorage.containsKey(key);
  String getSync(String key) => window.localStorage[key];

  @override
  Future store(String key, String value) {
    window.localStorage[key] = value;
    return new Future.value();
  }

  @override
  Future<String> remove(String key) async => window.localStorage.remove(key);
}

PrivateKey _cachedPrivateKey;
/// Get a Private Key using the specified storage strategy.
/// If [storage] is not specified, it uses the [LocalDataStorage] class.
Future<PrivateKey> getPrivateKey({DataStorage storage}) async {
  if (_cachedPrivateKey != null) {
    return _cachedPrivateKey;
  }

  if (storage == null) {
    storage = LocalDataStorage.INSTANCE;
  }

  String keyPath = "dsa_key:${window.location.pathname}";
  String keyLockPath = "dsa_key_lock:${window.location.pathname}";
  String randomToken = "${new DateTime.now().millisecondsSinceEpoch} ${DSRandom.instance.nextUint16()} ${DSRandom.instance.nextUint16()}";

  var hasKeyPath = storage is LocalDataStorage ? storage.hasSync(keyPath) : await storage.has(keyPath);

  if (hasKeyPath) {
    await storage.store(keyLockPath, randomToken);
    await new Future.delayed(const Duration(milliseconds: 20));
    var existingToken = storage is LocalDataStorage ? storage.getSync(keyLockPath) : await storage.get(keyLockPath);
    var existingKey = storage is LocalDataStorage ? storage.getSync(keyPath) : await storage.get(keyPath);
    if (existingToken == randomToken) {
      if (storage is LocalDataStorage) {
        _startStorageLock(keyLockPath, randomToken);
      }
      _cachedPrivateKey = new PrivateKey.loadFromString(existingKey);
      return _cachedPrivateKey;
    } else {
      // use temp key, don't lock it;
      keyLockPath = null;
    }
  }

  _cachedPrivateKey = await PrivateKey.generate();

  if (keyLockPath != null) {
    storage.store(keyPath, _cachedPrivateKey.saveToString());
    storage.store(keyLockPath, randomToken);
    if (storage is LocalDataStorage) {
      _startStorageLock(keyLockPath, randomToken);
    }
  }

  return _cachedPrivateKey;
}

void _startStorageLock(String lockKey, String lockToken) {
  void onStorage(StorageEvent e) {
    if (e.key == lockKey) {
      window.localStorage[lockKey] = lockToken;
    }
  }
  window.onStorage.listen(onStorage);
}
