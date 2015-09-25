library dslink.storage.simple;

import '../../responder.dart';
import '../../common.dart';
import 'dart:io';
import '../../utils.dart';
import 'dart:async';

class SimpleStorageManager implements IStorageManager {
  Map<String, SimpleResponderStorage> rsponders =
      new Map<String, SimpleResponderStorage>();
  Directory dir;
  SimpleStorageManager(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionResponderStorage getOrCreateStorage(String rpath) {
    if (rsponders.containsKey(rpath)) {
      return rsponders[rpath];
    }
    SimpleResponderStorage responder =
        new SimpleResponderStorage('${dir.path}/${Uri.encodeComponent(rpath)}', rpath);
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
    rsponders.forEach((String rpath, SimpleResponderStorage responder) {
      responder.destroy();
    });
    rsponders.clear();
  }
  Future<List<List<ISubscriptionNodeStorage>>> loadSubscriptions() async{
     List<Future<List<ISubscriptionNodeStorage>>> loading = [];
     for (FileSystemEntity entity in dir.listSync()) {
       if (await FileSystemEntity.type(entity.path) == FileSystemEntityType.DIRECTORY) {
         String rpath = Uri.decodeComponent(entity.path.substring(entity.path.lastIndexOf(Platform.pathSeparator) + 1));
         SimpleResponderStorage responder =
                 new SimpleResponderStorage(entity.path, rpath);
         rsponders[rpath] = responder;
         loading.add(responder.load());
       }
     }
     return Future.wait(loading);
  }
}

class SimpleResponderStorage extends ISubscriptionResponderStorage {
  Map<String, SimpleNodeStorage> values = new Map<String, SimpleNodeStorage>();
  Directory dir;
  String responderPath;
  
  SimpleResponderStorage(String path, [this.responderPath]) {
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
    SimpleNodeStorage value = new SimpleNodeStorage(path, dir.path, this);
    values[path] = value;
    return value;
  }
  Future<List<ISubscriptionNodeStorage>> load() async {
    List<Future<ISubscriptionNodeStorage>> loading = [];
    for (FileSystemEntity entity in dir.listSync()) {
      String name = entity.uri.pathSegments.last;
      String path = Uri.decodeComponent(name);
      values[path] = new SimpleNodeStorage(path, dir.path, this);
      loading.add(values[path].load());
    }
    return Future.wait(loading);
  }

  void destroyValue(String path) {
    if (values.containsKey(path)) {
      values[path].destroy();
      values.remove(path);
    }
  }
  void destroy() {
    values.forEach((String path, SimpleNodeStorage value) {
      value.destroy();
    });
    values.clear();
  }
}

class SimpleNodeStorage extends ISubscriptionNodeStorage {
  File file;
  SimpleNodeStorage(
      String path, String parentPath, SimpleResponderStorage storage)
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
  void clear(int qos) {
    if (qos == 3) {
      file.writeAsStringSync('');
    } else {
      file.writeAsStringSync(' ');
    }
  }
  void destroy() {
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
