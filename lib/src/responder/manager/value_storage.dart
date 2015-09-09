part of dslink.responder;


abstract class ISubscriptionStorageManager {
  ISubscriptionResponderStorage getOrCreateStorage(String dsId);
  void destroyStorage(String dsId);
}

abstract class ISubscriptionResponderStorage {
  ISubscriptionNodeStorage getOrCreateValue(String path);
  void destroyValue(String path);
  Future<List<ISubscriptionNodeStorage>> load();
  void destroy();
}

abstract class ISubscriptionNodeStorage {
  String path;
  int qos;
  ISubscriptionNodeStorage(this.path);
  
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
  
  /// return the local vlaues
  List<ValueUpdate> getLoadedValues();
}