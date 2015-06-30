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
part 'src/browser/browser_http_conn.dart';
part 'src/browser/browser_ws_conn.dart';

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

  @override
  Future store(String key, String value) async =>
      window.localStorage[key] = value;

  @override
  Future<String> remove(String key) async => window.localStorage.remove(key);
}

/// Get a Private Key using the specified storage strategy.
/// If [storage] is not specified, it uses the [LocalDataStorage] class.
Future<PrivateKey> getPrivateKey({DataStorage storage}) async {
  if (storage == null) {
    storage = LocalDataStorage.INSTANCE;
  }

  if (await storage.has("dsa_key")) {
    return new PrivateKey.loadFromString(await storage.get("dsa_key"));
  }

  var key = await PrivateKey.generate();

  await storage.store("dsa_key", key.saveToString());

  return key;
}
