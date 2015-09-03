part of dslink.responder;

abstract class ISubscriptionStorageManager {
  ISubscriptionStorage getOrCreateStorage(String path);
  void destroyStorage(String path);
}

abstract class ISubscriptionStorage {
  /// add data to List of values
  void addValue(ValueUpdate value);
  /// need a input value to compare with the existing value
  void removeValue(ValueUpdate value);
  
  void clear();
  
  /// return a ValueUpdate or a List<ValueUpdate>
  Object getStoredValues();
}