library dslink.storage.simple;

import '../../responder.dart';
import '../../common.dart';
import 'dart:io';
import '../../utils.dart';

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
    SimpleResponderStorage responder = new SimpleResponderStorage('${dir.path}/$dsId');
    rsponders[dsId] = responder;
    return responder;
  }
  void destroyStorage(String dsId) {
    if (rsponders.containsKey(dsId)){
      rsponders[dsId].destroy();
      rsponders.remove(dsId);
    }
  }
  void destroy() {
    rsponders.forEach((String dsId, SimpleResponderStorage responder){
      responder.destroy();
    });
    rsponders.clear();
  }
}

class SimpleResponderStorage extends ISubscriptionResponderStorage {
  Map<String, SimpleValueStorage> values =
      new Map<String, SimpleValueStorage>();
  Directory dir;
  SimpleResponderStorage(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionValueStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    SimpleValueStorage value = new SimpleValueStorage(path, dir.path);
    values[path] = value;
    return value;
  }
  Map<String, ISubscriptionValueStorage> load() {
    for (FileSystemEntity entity in dir.listSync()){
      String name = entity.uri.pathSegments.last;
      String path = Uri.decodeComponent(name);
      values[path] = new SimpleValueStorage(path, dir.path);
    }
    return values;
  }
  
  void destroyValue(String path) {
    if (values.containsKey(path)){
      values[path].clear();
      values.remove(path);
    }
  }
  void destroy() {
    values.forEach((String path, SimpleValueStorage value){
      value.clear();
    });
    values.clear();
  }
}

class SimpleValueStorage extends ISubscriptionValueStorage {
  File file;
  final String path;
  SimpleValueStorage(this.path, String parentPath) {
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

  List<ValueUpdate> loadAll() {
    String str = file.readAsStringSync();
    List<String> strs = str.split('\n');
    if (strs.length == 1 && str.startsWith(' ')){
      // where there is space, it's qos 2
      qos = 2;
    } else {
      qos = 3;
    }
    List<ValueUpdate> rslt = new List<ValueUpdate>();
    for (String s in strs) {
      try {
        Map m = DsJson.decode(s);
        ValueUpdate value = new ValueUpdate(m['value'], ts: m['ts'], meta: m);
        rslt.add(value);
      } catch (err) {print(err);}
    }
    return rslt;
  }
}
