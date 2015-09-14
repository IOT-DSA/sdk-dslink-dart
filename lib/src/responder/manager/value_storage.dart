part of dslink.responder;


abstract class ISubscriptionStorageManager {
  ISubscriptionResponderStorage getOrCreateStorage(String rpath);
  void destroyStorage(String rpath);
  Future<List<List<ISubscriptionNodeStorage>>> load();
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
  
  
  void clear();
  
  /// return the local vlaues
  List<ValueUpdate> getLoadedValues();
}