/// Base API for DSA in the Browser
library dslink.browser_client;

import 'dart:async';
import 'dart:html';
import 'dart:convert';
import 'dart:typed_data';
import 'common.dart';
import 'utils.dart';
import 'requester.dart';
import 'responder.dart';
import 'src/crypto/pk.dart';

part 'src/browser/browser_user_link.dart';
part 'src/browser/browser_ecdh_link.dart';
//part 'src/browser/browser_http_conn.dart';
part 'src/browser/browser_ws_conn.dart';

/// A Storage System for DSA Data
abstract class DataStorage {
  /// Get a key's value.
  String get(String key);

  /// Check if a key is stored.
  bool has(String key);

  /// Remove the specified key.
  String remove(String key);

  /// Store a key value pair.
  void store(String key, String value);
}

/// Storage for DSA in Local Storage
class LocalDataStorage extends DataStorage {
  static final LocalDataStorage INSTANCE = new LocalDataStorage();

  LocalDataStorage();

  @override
  String get(String key) => window.localStorage[key];

  @override
  bool has(String key) => window.localStorage.containsKey(key);

  @override
  void store(String key, String value) {
      window.localStorage[key] = value;
  }

  @override
  String remove(String key) => window.localStorage.remove(key);
}

/// Get a Private Key using the specified storage strategy.
/// If [storage] is not specified, it uses the [LocalDataStorage] class.
Future<PrivateKey> getPrivateKey({DataStorage storage}) async {
  if (storage == null) {
    storage = LocalDataStorage.INSTANCE;
  }

  String keyPath = 'dsa_key:${window.location.pathname}';
  String keyLockPath = 'dsa_key_lock:${window.location.pathname}';
  String randomToken = '${new DateTime.now().millisecondsSinceEpoch} ${DSRandom.instance.nextUint16()} ${DSRandom.instance.nextUint16()}';
      
  if (storage.has(keyPath)) {
    storage.store(keyLockPath, randomToken);
    await new Future.delayed(new Duration(milliseconds: 20));
    if (storage.get(keyLockPath) == randomToken) {
      _startStorageLock(keyLockPath, randomToken);
      return new PrivateKey.loadFromString(storage.get("dsa_key"));
    } else {
      // use temp key, don't lock it;
      keyLockPath = null;
    }
  }

  var key = await PrivateKey.generate();

  if (keyLockPath != null) {
    storage.store(keyPath, key.saveToString());
    storage.store(keyLockPath, randomToken);
    _startStorageLock(keyLockPath, randomToken);
  }

  return key;
}

void _startStorageLock(String lockKey, String token){
  void onStorage(StorageEvent e){
    if (e.key == lockKey) {
      window.localStorage[lockKey] = token;
    }
  }
  window.onStorage.listen(onStorage);
}
