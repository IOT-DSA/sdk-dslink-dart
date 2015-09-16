library dslink.storage.web;

import '../../responder.dart';
import '../../common.dart';
import 'dart:html';
import '../../utils.dart';
import 'dart:async';



class WebResponderStorage extends ISubscriptionResponderStorage {
  Map<String, WebNodeStorage> values = new Map<String, WebNodeStorage>();
  final String prefix;
  String responderPath;
  
  WebResponderStorage([this.prefix = 'dsaValue:']);
  ISubscriptionNodeStorage getOrCreateValue(String path) {
    if (values.containsKey(path)) {
      return values[path];
    }
    WebNodeStorage value = new WebNodeStorage(path, prefix, this);
    values[path] = value;
    return value;
  }
  Future<List<ISubscriptionNodeStorage>> load() async {
    List<ISubscriptionNodeStorage> rslt = [];
    for (String key in window.localStorage.keys) {
      if (key.startsWith(prefix)){
        String path = key.substring(prefix.length);
        WebNodeStorage value = new WebNodeStorage(path, prefix, this);
        value.load();
        values[path] = value;
        rslt.add(value);
      }
    }
    return new Future.value(rslt);
  }

  void destroyValue(String path) {
    if (values.containsKey(path)) {
      values[path].clear();
      values.remove(path);
    }
  }
  void destroy() {
    values.forEach((String path, WebNodeStorage value) {
      value.clear();
    });
    values.clear();
  }
}

class WebNodeStorage extends ISubscriptionNodeStorage {
  String storePath;
  WebNodeStorage(
      String path, String prefix, WebResponderStorage storage)
      : super(path, storage) {
    storePath = '$prefix$path';
  }
  /// add data to List of values
  void addValue(ValueUpdate value) {
    qos = 3;
    value.storedData = '${DsJson.encode(value.toMap())}\n';
    if (window.localStorage.containsKey(storePath)) {
      window.localStorage[storePath] = window.localStorage[storePath] + value.storedData;
    } else {
      window.localStorage[storePath] = value.storedData;
    }
  }
  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue) {
    qos = 2;
    newValue.storedData = ' ${DsJson.encode(newValue.toMap())}\n';
    // add a space when qos = 2
    window.localStorage[storePath] = newValue.storedData;
  }
  void removeValue(ValueUpdate value) {
    // do nothing, it's done in valueRemoved
  }
  void valueRemoved(Iterable<ValueUpdate> updates) {
    window.localStorage[storePath] = updates.map((v) => v.storedData).join();
  }
  void clear() {
    window.localStorage.remove(storePath);
  }

  List<ValueUpdate> _cachedValue;
  void load() {
    String str = window.localStorage[storePath];
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
  }

  List<ValueUpdate> getLoadedValues() {
    return _cachedValue;
  }
}
