library dslink.storage.indexed_db;

import '../../responder.dart';
import '../../common.dart';
import 'dart:html';
import 'dart:indexed_db';
import 'dart:async';

class IndexedDbResponderStorage extends ISubscriptionResponderStorage {
  Map<String, IndexedDbNodeStorage> values = new Map<String, IndexedDbNodeStorage>();
  /// not needed
  String get responderPath => null;

  static Future<IndexedDbResponderStorage> createStorage([String dbName = 'DSA_Value_Store',
      String storeName = 'DSA_Value_Store', int version = 1]) async {
    void onUpgradeNeeded(VersionChangeEvent e) {
      Database db = (e.target as Request).result;
      var objectStore = db.createObjectStore(storeName);
      objectStore.createIndex('path', 'path', multiEntry:true);
    }
    Database db = await window.indexedDB.open(dbName,
        onUpgradeNeeded: onUpgradeNeeded, version: version);
    return new IndexedDbResponderStorage(db, storeName);
  }

  Database db;
  String storeName;
  IndexedDbResponderStorage(this.db, this.storeName);

  ObjectStore newTransaction() {
    return db.transaction(storeName).objectStore(storeName);
  }
  ISubscriptionNodeStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    IndexedDbNodeStorage value = new IndexedDbNodeStorage(path, this);
    values[path] = value;
    return value;
  }
  Future<List<ISubscriptionNodeStorage>> load() async {
    Completer<List<ISubscriptionNodeStorage>> completer = new Completer<List<ISubscriptionNodeStorage>>();
    List<ISubscriptionNodeStorage> rslt = [];
    ObjectStore objStore = newTransaction();
    void onData(CursorWithValue cursor) {
      Map map = cursor.value;
      ValueUpdate value = new ValueUpdate(map['value'], ts:map['ts'], meta:map);
      value.storedData = cursor.key;
      String path = map['path'];
      IndexedDbNodeStorage nodeStore = values[path];
      
      if (nodeStore == null) {
        nodeStore = new IndexedDbNodeStorage(path, this);
        nodeStore._cachedValue = [];
        values[path] = nodeStore;
        rslt.add(nodeStore);
      }
      nodeStore._cachedValue.add(value);
    }
    void onDone(){;
      completer.complete(rslt);
    }
    objStore.openCursor(autoAdvance:true).listen(onData, onDone:onDone);

    return completer.future;
  }

  void destroyValue(String path) {
    if (values.containsKey(path)) {
      values[path].clear();
      values.remove(path);
    }
  }
  void destroy() {
    values.forEach((String path, IndexedDbNodeStorage value) {
      value.clear();
    });
    values.clear();
  }
}

class IndexedDbNodeStorage extends ISubscriptionNodeStorage {
  static double key = 0.0;

  IndexedDbNodeStorage(String path, IndexedDbResponderStorage storage)
      : super(path, storage) {}
  /// add data to List of values
  void addValue(ValueUpdate value) {
    qos = 3;
    Map map = value.toMap();
    map['path'] = path;
    (storage as IndexedDbResponderStorage).newTransaction().put(map, ++key);
    value.storedData = key;
  }
  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue) {
    qos = 2;
    Map map = newValue.toMap();
    map['path'] = path;
    map['qos'] = 2;
    var objStore = (storage as IndexedDbResponderStorage).newTransaction();
    for (ValueUpdate val in removes) {
      objStore.delete(val.storedData);
    }
    objStore.put(map, ++key);
    newValue.storedData = key;
  }
  void removeValue(ValueUpdate value) {
    (storage as IndexedDbResponderStorage).newTransaction().delete(value.storedData);
  }
  void valueRemoved(Iterable<ValueUpdate> updates) {
    // nothing needs to be done here
  }
  void clear() {
    var objStore = (storage as IndexedDbResponderStorage).newTransaction();
    objStore.index('path').openCursor(key:path,autoAdvance:true).listen(_onClear);
  }
  void _onClear(CursorWithValue cursor) {
    cursor.delete();
  }

  List<ValueUpdate> _cachedValue;

  List<ValueUpdate> getLoadedValues() {
    return _cachedValue;
  }
}
