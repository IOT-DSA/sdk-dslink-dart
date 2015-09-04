library dslink.storage.base;

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
    SimpleResponderStorage responder = new SimpleResponderStorage(dsId, dir);
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
  final String dsId;
  Map<String, SimpleValueStorage> values =
      new Map<String, SimpleValueStorage>();
  Directory dir;
  SimpleResponderStorage(this.dsId, Directory parentDir) {
    dir = new Directory.fromUri(parentDir.uri.resolve(dsId));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  ISubscriptionValueStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    SimpleValueStorage value = new SimpleValueStorage(path, dir);
    values[path] = value;
    return value;
  }
  Map<String, ISubscriptionValueStorage> load() {
    for (FileSystemEntity entity in dir.listSync()){
      String name = entity.uri.pathSegments.last;
      String path = Uri.decodeComponent(name);
      values[path] = new SimpleValueStorage(path, dir);
    }
    return values;
  }
  
  void destroyValue(String path) {
    if (values.containsKey(path)){
      values[path].destroy();
      values.remove(path);
    }
  }
  void destroy() {
    values.forEach((String path, SimpleValueStorage value){
      value.destroy();
    });
    values.clear();
  }
}

class SimpleValueStorage extends ISubscriptionValueStorage {
  File file;
  final String path;
  SimpleValueStorage(this.path, Directory parentDir) {
    file = new File.fromUri(parentDir.uri.resolve(Uri.encodeComponent(path)));
  }
  /// add data to List of values
  void addValue(ValueUpdate value) {
    super.addValue(value);
    file.openSync(mode: FileMode.APPEND)
      ..writeStringSync(value.serialized)
      ..writeStringSync('\n')
      ..closeSync();
  }
  void setValue(ValueUpdate value) {
    super.setValue(value);
    file.writeAsStringSync(value.serialized);
  }
  void removeValue(ValueUpdate value) {
    // do nothing, it's done in valueRemoved
  }
  void valueRemoved() {
    file.writeAsStringSync(waitingValues.map((v) => v.serialized).join('\n'));
  }
  void clear() {
    super.clear();
    file.delete();
  }
  void destroy() {
    file.delete();
  }

  List<ValueUpdate> loadAll() {
    String str = file.readAsStringSync();
    List<String> strs = str.split('\n');
    List<ValueUpdate> rslt = new List<ValueUpdate>();
    for (String s in strs) {
      try {
        Map m = DsJson.decode(str);
        ValueUpdate value = new ValueUpdate(m['value'], ts: m['ts'], meta: m);
        rslt.add(value);
      } catch (err) {}
    }
    waitingValues.addAll(rslt);
    return rslt;
  }
}
