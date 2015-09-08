part of dslink.responder;


abstract class ISubscriptionStorageManager {
  ISubscriptionResponderStorage getOrCreateStorage(String dsId);
  void destroyStorage(String dsId);
}

abstract class ISubscriptionResponderStorage {
  ISubscriptionValueStorage getOrCreateValue(String path);
  void destroyValue(String path);
  Map<String, ISubscriptionValueStorage> load();
  void destroy();
}

abstract class ISubscriptionValueStorage {
  
  int qos;
  
  /// add data to List of values
  void addValue(ValueUpdate value) {
    value.serialized = DsJson.encode(value.toMap());
  }
  
  void setValue(ValueUpdate value) {
    value.serialized = DsJson.encode(value.toMap());
  }
  
  void removeValue(ValueUpdate value);
  /// api to optimize file remove;
  void valueRemoved(Iterable<ValueUpdate> updates){}
  
  
  void clear();
  
  /// load stored values
  List<ValueUpdate> loadAll();
}