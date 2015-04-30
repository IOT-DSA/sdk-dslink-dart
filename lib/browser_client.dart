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

/// A Storage System for Private Keys
abstract class PrivateKeyStorage {
  /// Get Private Key Content
  Future<String> get();

  /// Check if a Private Key is stored.
  Future<bool> has();

  /// Store a Private Key
  Future store(String value);
}

/// Storage for Private Keys in Local Storage
class LocalPrivateKeyStorage extends PrivateKeyStorage {
  /// Local Storage Key
  final String key;

  LocalPrivateKeyStorage([this.key = "dsa_key"]);

  @override
  Future<String> get() async => window.localStorage[key];

  @override
  Future<bool> has() async => window.localStorage.containsKey(key);

  @override
  Future store(String value) async => window.localStorage[key] = value;
}

final LocalPrivateKeyStorage _localPrivateKeyStorage = new LocalPrivateKeyStorage();

/// Get a Private Key using the specified storage strategy.
/// If [storage] is not specified, it uses the [LocalPrivateKeyStorage] class.
Future<PrivateKey> getPrivateKey({PrivateKeyStorage storage}) async {
  if (storage == null) {
    storage = _localPrivateKeyStorage;
  }

  if (await storage.has()) {
    return new PrivateKey.loadFromString(await storage.get());
  }

  var key = new PrivateKey.generate();

  await storage.store(key.saveToString());

  return key;
}
