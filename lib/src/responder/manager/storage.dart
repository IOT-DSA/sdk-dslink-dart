part of dslink.responder;


abstract class IStorageManager {
  /// general key/value pair storage
  IValueStorageBucket getOrCreateValueStorageBucket(String name);
  void destroyValueStorageBucket(String name);
  
  ISubscriptionResponderStorage getOrCreateSubscriptionStorage(String rpath);
  void destroySubscriptionStorage(String rpath);
  Future<List<List<ISubscriptionNodeStorage>>> loadSubscriptions();
}

abstract class ISubscriptionResponderStorage {
  String get responderPath;
  ISubscriptionNodeStorage getOrCreateValue(String path);
  void destroyValue(String path);
  Future<List<ISubscriptionNodeStorage>> load();
  void destroy();
}

abstract class ISubscriptionNodeStorage {
  final String path;
  final ISubscriptionResponderStorage storage;
  int qos;
  ISubscriptionNodeStorage(this.path, this.storage);
  
  /// add data to List of values
  void addValue(ValueUpdate value);
  
  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue);
  
  void removeValue(ValueUpdate value);
  /// api to optimize file remove;
  void valueRemoved(Iterable<ValueUpdate> updates){}
  
  
  void clear(int qos);
  void destroy();
  /// return the local vlaues
  List<ValueUpdate> getLoadedValues();
}

abstract class IValueStorageBucket {
  void setValue(String key, Object value);
  void removeValue(String key);
  Future<Map> load();
  void destroy();
}
