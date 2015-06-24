part of dslink.responder;

/// a node that can be subscribed or listed by multiple responders
abstract class LocalNode extends Node {
  BroadcastStreamController<String> _listChangeController;
  BroadcastStreamController<String> get listChangeController {
    if (_listChangeController == null) {
      _listChangeController = new BroadcastStreamController<String>(
          onStartListListen, onAllListCancel);
    }
    return _listChangeController;
  }
  Stream<String> get listStream => listChangeController.stream;
  StreamSubscription _listReqListener;

  void onStartListListen() {}

  void onAllListCancel() {}
  

  final String path;

  LocalNode(this.path);

  Map<Function, int> callbacks = new Map<Function, int>();

  RespSubscribeListener subscribe(callback(ValueUpdate), [int cachelevel = 1]) {
    callbacks[callback] = cachelevel;
    return new RespSubscribeListener(this, callback);
  }

  void unsubscribe(callback(ValueUpdate)) {
    if (callbacks.containsKey(callback)) {
      callbacks.remove(callback);
    }
  }

  ValueUpdate _lastValueUpdate;
  ValueUpdate get lastValueUpdate {
    if (_lastValueUpdate == null) {
      _lastValueUpdate = new ValueUpdate(null);
    }
    return _lastValueUpdate;
  }

  void updateValue(Object update, {bool force: false}) {
    if (update is ValueUpdate) {
      _lastValueUpdate = update;
      callbacks.forEach((callback, cachelevel) {
        callback(_lastValueUpdate);
      });
    } else if (_lastValueUpdate == null ||
        _lastValueUpdate.value != update ||
        force) {
      _lastValueUpdate = new ValueUpdate(update);
      callbacks.forEach((callback, cachelevel) {
        callback(_lastValueUpdate);
      });
    }
  }

  /// list and subscribe can be called on a node that doesn't exist
  /// other api like set remove, invoke, can only be applied to existing node
  bool get exists => true;

  /// whether the node is ready for returning a list response
  bool get listReady => true;
  String get disconnected => null;
  bool get valueReady => true;

  bool get hasSubscriber => callbacks.isNotEmpty;

  int getInvokePermission(){
    return Permission.parse(getConfig(r'$invokable'));
  }
  int getSetPermission(){
    return Permission.parse(getConfig(r'$writable'));
  }
  InvokeResponse invoke(
      Map params, Responder responder, InvokeResponse response, Node parentNode, [int maxPermission = Permission.CONFIG]) {
    return response..close();
  }

  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    return response..close();
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    return response..close();
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    return response..close();
  }

  Response removeConfig(String name, Responder responder, Response response) {
    return response..close();
  }

  /// set node value
  Response setValue(Object value, Responder responder, Response response, [int maxPermission = Permission.CONFIG]) {
    return response..close();
  }

  operator [](String name) {
    return get(name);
  }

  operator []=(String name, Object value) {
    if (name.startsWith(r"$")) {
      configs[name] = value;
    } else if (name.startsWith(r"@")) {
      attributes[name] = value;
    } else if (value is Node) {
      addChild(name, value);
    }
  }
}

/// node provider for responder
/// one NodeProvider can be reused by multiple responders.
abstract class NodeProvider {
  /// get an existing node or create a dummy node for requester to listen on
  LocalNode getNode(String path);

  /// get an existing node or create a dummy node for requester to listen on
  LocalNode operator [](String path) {
    return getNode(path);
  }
  
  LocalNode operator ~() => this["/"];
  
  Responder createResponder(String dsId);
  
  IPermissionManager get permissions;
}
