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
  ListQueue<ValueUpdate> waitingValues = new ListQueue<ValueUpdate>();
  
  /// add data to List of values
  void addValue(ValueUpdate value) {
    value.serialized = DsJson.encode(value.toMap());
    waitingValues.add(value);
  }
  
  void setValue(ValueUpdate value) {
    value.serialized = DsJson.encode(value.toMap());
    waitingValues.clear();
    waitingValues.add(value);
  }
  
  void removeValue(ValueUpdate value);
  /// api to optimize file remove;
  void valueRemoved(){}
  
  void onAck(int ackId) {
    while (!waitingValues.isEmpty && waitingValues.first.waitingAck == ackId) {
      // TODO is there any need to add protection in case ackId is out of sync?
      // because one stuck data will cause the queue to overflow
      removeValue(waitingValues.removeFirst());
    }
    valueRemoved();
  }
  
  void clear() {
    waitingValues.clear();
  }
  void destroy();
}