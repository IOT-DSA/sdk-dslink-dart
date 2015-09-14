library dslink.storage.simple;

import '../../responder.dart';
import '../../common.dart';
import 'dart:io';
import '../../utils.dart';
import 'dart:async';

class IndexedDbStorageManager implements ISubscriptionStorageManager {
  Map<String, IndexedDbResponderStorage> rsponders =
      new Map<String, IndexedDbResponderStorage>();
  Directory dir;
  IndexedDbStorageManager(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionResponderStorage getOrCreateStorage(String rpath) {
    if (rsponders.containsKey(rpath)) {
      return rsponders[rpath];
    }
    IndexedDbResponderStorage responder =
        new IndexedDbResponderStorage('${dir.path}/${Uri.encodeComponent(rpath)}', rpath);
    rsponders[rpath] = responder;
    return responder;
  }
  void destroyStorage(String rpath) {
    if (rsponders.containsKey(rpath)) {
      rsponders[rpath].destroy();
      rsponders.remove(rpath);
    }
  }
  void destroy() {
    rsponders.forEach((String rpath, IndexedDbResponderStorage responder) {
      responder.destroy();
    });
    rsponders.clear();
  }
  Future<List<List<ISubscriptionNodeStorage>>> load() async{
     List<Future<List<ISubscriptionNodeStorage>>> loading = [];
     for (FileSystemEntity entity in dir.listSync()) {
       if (await FileSystemEntity.type(entity.path) == FileSystemEntityType.DIRECTORY) {
         String rpath = Uri.decodeComponent(entity.path.substring(entity.path.lastIndexOf(Platform.pathSeparator) + 1));
         IndexedDbResponderStorage responder =
                 new IndexedDbResponderStorage(entity.path, rpath);
         rsponders[rpath] = responder;
         loading.add(responder.load());
       }
     }
     return Future.wait(loading);
  }
}

class IndexedDbResponderStorage extends ISubscriptionResponderStorage {
  Map<String, IndexedDbNodeStorage> values = new Map<String, IndexedDbNodeStorage>();
  Directory dir;
  String responderPath;
  
  IndexedDbResponderStorage(String path, [this.responderPath]) {
    if (responderPath == null) {
      responderPath = Uri.decodeComponent(path.substring(path.lastIndexOf(Platform.pathSeparator) + 1));
    }
    
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionNodeStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    IndexedDbNodeStorage value = new IndexedDbNodeStorage(path, dir.path, this);
    values[path] = value;
    return value;
  }
  Future<List<ISubscriptionNodeStorage>> load() async {
    List<Future<ISubscriptionNodeStorage>> loading = [];
    for (FileSystemEntity entity in dir.listSync()) {
      String name = entity.uri.pathSegments.last;
      String path = Uri.decodeComponent(name);
      values[path] = new IndexedDbNodeStorage(path, dir.path, this);
      loading.add(values[path].load());
    }
    return Future.wait(loading);
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
  File file;
  IndexedDbNodeStorage(
      String path, String parentPath, IndexedDbResponderStorage storage)
      : super(path, storage) {
    file = new File('$parentPath/${Uri.encodeComponent(path)}');
  }
  /// add data to List of values
  void addValue(ValueUpdate value) {
    qos = 3;
    value.storedData = '${DsJson.encode(value.toMap())}\n';
    file.openSync(mode: FileMode.APPEND)
      ..writeStringSync(value.storedData)
      ..closeSync();
  }
  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue) {
    qos = 2;
    newValue.storedData = ' ${DsJson.encode(newValue.toMap())}\n';
    // add a space when qos = 2
    file.writeAsStringSync(newValue.storedData);
  }
  void removeValue(ValueUpdate value) {
    // do nothing, it's done in valueRemoved
  }
  void valueRemoved(Iterable<ValueUpdate> updates) {
    file.writeAsStringSync(updates.map((v) => v.storedData).join());
  }
  void clear() {
    file.delete();
  }

  List<ValueUpdate> _cachedValue;
  Future<ISubscriptionNodeStorage> load() async {
    String str = await file.readAsString();
    List<String> strs = str.split('\n');
    if (strs.length == 1 && str.startsWith(' ')) {
      // where there is space, it's qos 2
      qos = 2;
    } else {
      qos = 3;
    }
    List<ValueUpdate> rslt = new List<ValueUpdate>();
    for (String s in strs) {
      if (s.length < 18) {
        // a valid data is always 18 bytes or more
        continue;
      }
      try {
        Map m = DsJson.decode(s);
        ValueUpdate value = new ValueUpdate(m['value'], ts: m['ts'], meta: m);
        rslt.add(value);
      } catch (err) {}
    }
    _cachedValue = rslt;
    return this;
  }

  List<ValueUpdate> getLoadedValues() {
    return _cachedValue;
  }
}
