library dslink.storage.simple;

import '../../responder.dart';
import '../../common.dart';
import 'dart:io';
import '../../utils.dart';
import 'dart:async';

class SimpleStorageManager implements ISubscriptionStorageManager {
  Map<String, SimpleResponderStorage> rsponders =
      new Map<String, SimpleResponderStorage>();
  Directory dir;
  SimpleStorageManager(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionResponderStorage getOrCreateStorage(String dsId) {
    if (rsponders.containsKey(dsId)) {
      return rsponders[dsId];
    }
    SimpleResponderStorage responder =
        new SimpleResponderStorage('${dir.path}/$dsId');
    rsponders[dsId] = responder;
    return responder;
  }
  void destroyStorage(String dsId) {
    if (rsponders.containsKey(dsId)) {
      rsponders[dsId].destroy();
      rsponders.remove(dsId);
    }
  }
  void destroy() {
    rsponders.forEach((String dsId, SimpleResponderStorage responder) {
      responder.destroy();
    });
    rsponders.clear();
  }
}

class SimpleResponderStorage extends ISubscriptionResponderStorage {
  Map<String, SimpleNodeStorage> values =
      new Map<String, SimpleNodeStorage>();
  Directory dir;
  SimpleResponderStorage(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionNodeStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    SimpleNodeStorage value = new SimpleNodeStorage(path, dir.path);
    values[path] = value;
    return value;
  }
  Future<List<ISubscriptionNodeStorage>> load() {
    List<Future<ISubscriptionNodeStorage>> loading = [];
    for (FileSystemEntity entity in dir.listSync()) {
      String name = entity.uri.pathSegments.last;
      String path = Uri.decodeComponent(name);
      values[path] = new SimpleNodeStorage(path, dir.path);
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
    values.forEach((String path, SimpleNodeStorage value) {
      value.clear();
    });
    values.clear();
  }
}

class SimpleNodeStorage extends ISubscriptionNodeStorage {
  File file;
  SimpleNodeStorage(String path, String parentPath) : super(path) {
    file = new File('$parentPath/${Uri.encodeComponent(path)}');
  }
  /// add data to List of values
  void addValue(ValueUpdate value) {
    qos = 3;
    super.addValue(value);
    file.openSync(mode: FileMode.APPEND)
      ..writeStringSync(value.serialized)
      ..writeStringSync('\n')
      ..closeSync();
  }
  void setValue(ValueUpdate value) {
    qos = 2;
    super.setValue(value);
    // add a space when qos = 2
    file.writeAsStringSync(' ${value.serialized}');
  }
  void removeValue(ValueUpdate value) {
    // do nothing, it's done in valueRemoved
  }
  void valueRemoved(Iterable<ValueUpdate> updates) {
    file.writeAsStringSync(updates.map((v) => v.serialized).join('\n'));
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
