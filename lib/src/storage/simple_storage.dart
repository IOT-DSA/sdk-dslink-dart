library dslink.storage.simple;

import "dart:async";
import "dart:io";

import "../../responder.dart";
import "../../common.dart";
import "../../utils.dart";

void _ignoreError(Object obj) {}

class SimpleStorageManager implements IStorageManager {
  Map<String, SimpleResponderStorage> rsponders = new Map<String, SimpleResponderStorage>();
  Directory dir;
  Directory subDir;

  SimpleStorageManager(String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    subDir = new Directory("$path/resp_subscription");
    if (!subDir.existsSync()) {
      subDir.createSync(recursive: true);
    }
  }

  ISubscriptionResponderStorage getOrCreateSubscriptionStorage(String rpath) {
    if (rsponders.containsKey(rpath)) {
      return rsponders[rpath];
    }
    SimpleResponderStorage responder =
    new SimpleResponderStorage(
        "${subDir.path}/${Uri.encodeComponent(rpath)}", rpath);
    rsponders[rpath] = responder;
    return responder;
  }

  void destroySubscriptionStorage(String rpath) {
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
    values.forEach((String name, SimpleValueStorageBucket store) {
      store.destroy();
    });
    values.clear();
  }

  Future<List<List<ISubscriptionNodeStorage>>> loadSubscriptions() async {
    List<Future<List<ISubscriptionNodeStorage>>> loading = [];
    for (FileSystemEntity entity in subDir.listSync()) {
      if (await FileSystemEntity.type(entity.path) ==
          FileSystemEntityType.DIRECTORY) {
        String rpath = Uri.decodeComponent(entity.path.substring(
            entity.path.lastIndexOf(Platform.pathSeparator) + 1));
        SimpleResponderStorage responder =
        new SimpleResponderStorage(entity.path, rpath);
        rsponders[rpath] = responder;
        loading.add(responder.load());
      }
    }
    return Future.wait(loading);
  }

  Map<String, SimpleValueStorageBucket> values =
  new Map<String, SimpleValueStorageBucket>();

  IValueStorageBucket getOrCreateValueStorageBucket(String category) {
    if (values.containsKey(category)) {
      return values[category];
    }
    SimpleValueStorageBucket store =
    new SimpleValueStorageBucket(
        category, "${dir.path}/${Uri.encodeComponent(category)}");
    values[category] = store;
    return store;
  }

  void destroyValueStorageBucket(String category) {
    if (values.containsKey(category)) {
      values[category].destroy();
      values.remove(category);
    }
  }
}

class SimpleResponderStorage extends ISubscriptionResponderStorage {
  Map<String, SimpleNodeStorage> values = new Map<String, SimpleNodeStorage>();
  Directory dir;
  String responderPath;

  SimpleResponderStorage(String path, [this.responderPath]) {
    if (responderPath == null) {
      responderPath = Uri.decodeComponent(
          path.substring(path.lastIndexOf(Platform.pathSeparator) + 1));
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
    SimpleNodeStorage value = new SimpleNodeStorage(
        path, Uri.encodeComponent(path), dir.path, this);
    values[path] = value;
    return value;
  }

  Future<List<ISubscriptionNodeStorage>> load() async {
    List<Future<ISubscriptionNodeStorage>> loading = [];
    for (FileSystemEntity entity in dir.listSync()) {
      String name = entity.path.substring(
          entity.path.lastIndexOf(Platform.pathSeparator) + 1);
      String path = Uri.decodeComponent(name);
      values[path] = new SimpleNodeStorage(path, name, dir.path, this);
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
  String filename;

  SimpleNodeStorage(String path, this.filename, String parentPath,
      SimpleResponderStorage storage)
      : super(path, storage) {
    file = new File("$parentPath/$filename");
  }

  /// add data to List of values
  void addValue(ValueUpdate value) {
    qos = 3;
    value.storedData = "${DsJson.encode(value.toMap())}\n";
    file.openSync(mode: FileMode.APPEND)
      ..writeStringSync(value.storedData)
      ..closeSync();
  }

  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue) {
    qos = 2;
    newValue.storedData = " ${DsJson.encode(newValue.toMap())}\n";
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
      file.writeAsStringSync("");
    } else {
      file.writeAsStringSync(" ");
    }
  }

  void destroy() {
    file.delete().catchError(_ignoreError);
    ;
  }

  List<ValueUpdate> _cachedValue;

  Future<ISubscriptionNodeStorage> load() async {
    String str = await file.readAsString();
    List<String> strs = str.split("\n");
    if (strs.length == 1 && str.startsWith(" ")) {
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
        ValueUpdate value = new ValueUpdate(m["value"], ts: m["ts"], meta: m);
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

/// basic key/value pair storage
class SimpleValueStorageBucket implements IValueStorageBucket {

  String category;
  Directory dir;

  SimpleValueStorageBucket(this.category, String path) {
    dir = new Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  IValueStorage getValueStorage(String key) {
    return new SimpleValueStorage(this, key);
  }

  void destroy() {
    dir.delete(recursive: true).catchError(_ignoreError);
  }

  Future<Map> load() {
    Map rslt = {};
    List<Future<ISubscriptionNodeStorage>> loading = [];
    for (FileSystemEntity entity in dir.listSync()) {
      String name = Uri.decodeComponent(entity.path.substring(
          entity.path.lastIndexOf(Platform.pathSeparator) + 1));
      File f = new File(entity.path);
      Future future = f.readAsString().then((String str) {
        try {
          rslt[name] = DsJson.decode(str);
        } catch (err) {
          logger.fine(err);
        }
      });
      loading.add(future);
    }
    Completer<Map> completer = new Completer<Map>();
    Future.wait(loading).then((obj) {
      completer.complete(rslt);
    });
    return completer.future;
  }
}


class SimpleValueStorage extends IValueStorage {
  String key;
  SimpleValueStorageBucket bucket;
  File _file;

  SimpleValueStorage(this.bucket, this.key) {
    _file = new File("${bucket.dir.path}/${Uri.encodeComponent(key)}");
  }

  void setValue(Object value) {
    // TODO: optimize this part so it doesn"t need to re-create path and File object everytime
    _file.writeAsString(DsJson.encode(value));
  }

  void destroy() {
    _file.delete().catchError(_ignoreError);
  }

  getValueAsync() async {
    try {
      return DsJson.decode(await _file.readAsString());
    } catch (err) {}
    return null;
  }
}
