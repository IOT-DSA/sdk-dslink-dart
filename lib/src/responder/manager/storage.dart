part of dslink.responder;

/// general purpose storage class
abstract class IStorageManager {
  /// general key/value pair storage
  IValueStorageBucket getOrCreateValueStorageBucket(String name);
  void destroyValueStorageBucket(String name);

  /// get subscription storage
  /// responder path point to a local responder node
  /// which means the dslink on the other side of the connection is a requester
  ISubscriptionResponderStorage getOrCreateSubscriptionStorage(String responderPath);

  /// destroy subscription storage
  void destroySubscriptionStorage(String responderPath);

  /// load all saved subscriptions
  /// should be called only during application initialization
  Future<List<List<ISubscriptionNodeStorage>>> loadSubscriptions();
}

/// a storage container for one dslink
/// different dslink will have different ISubscriptionResponderStorage
abstract class ISubscriptionResponderStorage {
  String get responderPath;

  ISubscriptionNodeStorage getOrCreateValue(String valuePath);
  void destroyValue(String valuePath);
  /// load all saved subscriptions
  /// should be called only during application initialization
  Future<List<ISubscriptionNodeStorage>> load();
  void destroy();
}

/// the storage of one value
abstract class ISubscriptionNodeStorage {
  final String path;
  final ISubscriptionResponderStorage storage;
  int qos;
  ISubscriptionNodeStorage(this.path, this.storage);

  /// add data to List of values
  void addValue(ValueUpdate value);

  /// set value to newValue and clear all existing values in the storage
  /// [removes] is only designed for database that can't directly remove all data in a key.
  /// ValueUpdate.storedData can be used to store any helper data for the storage class
  void setValue(Iterable<ValueUpdate> removes, ValueUpdate newValue);

  /// for some database it's easier to remove data one by one
  /// removeValue and valueRemoved will be both called, either one can be used
  void removeValue(ValueUpdate value);

  /// for some database it's easier to remove multiple data together
  /// removeValue and valueRemoved will be both called, either one can be used
  /// [updates] are all the remaining value that are still in the list
  void valueRemoved(Iterable<ValueUpdate> updates){}

  /// clear the values, but still leave the qos data in storage
  void clear(int qos);
  void destroy();

  /// return the existing storage values
  /// should be called only during application initialization
  /// and value will only be available after parent's load() function is finished
  List<ValueUpdate> getLoadedValues();
}

/// a storage class for general purpose key/value pair
abstract class IValueStorageBucket {
  IValueStorage getValueStorage(String key);
  Future<Map> load();
  void destroy();
}

/// basic value storage
abstract class IValueStorage {
  String get key;
  void setValue(Object value);
  Future getValueAsync();
  void destroy();
}
