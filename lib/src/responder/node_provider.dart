part of dslink.responder;

/// a node that can be subscribed or listed by multiple responders
abstract class LocalNode extends Node {
  final StreamController<String> listChangeController =
      new StreamController<String>();

  final String path;

  LocalNode(this.path);

  Stream<String> _listStream;

  Stream<String> get listStream {
    if (_listStream == null) {
      _listStream = listChangeController.stream.asBroadcastStream();
    }
    return _listStream;
  }

  Map<Function, int> callbacks = new Map<Function, int>();

  RespSubscribeListener subscribe(callback(ValueUpdate), [int cachelevel = 1]){
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
    } else if (_lastValueUpdate == null || _lastValueUpdate.value != update || force) {
      _lastValueUpdate = new ValueUpdate(update);
      callbacks.forEach((callback, cachelevel) {
        callback(_lastValueUpdate);
      });
    }
  }


  /// get a list of permission setting on this node
  PermissionList get permissions => null;

  /// get the permission of a responder (actually the permission of the linked requester)
  int getPermission(Responder responder) {
    return Permission.READ;
  }

  /// list and subscribe can be called on a node that doesn't exist
  /// other api like set remove, invoke, can only be applied to existing node
  bool get exists => true;

  /// whether the node is ready for returning a list response
  bool get listReady => true;
  String get disconnected => null;
  bool get valueReady => true;

  bool get hasSubscriber => callbacks.isNotEmpty;

  InvokeResponse invoke(
      Map params, Responder responder, InvokeResponse response) {
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
  Response setValue(Object value, Responder responder, Response response) {
    return response..close();
  }

  operator [](String name) {
    if (name.startsWith(r"$") || name.startsWith(r"@")) {
      return get(name);
    } else {
      return getChild(name);
    }
  }

  operator []=(String name, value) {
    if (name.startsWith(r"$") || name.startsWith(r"@")) {
      if (name.startsWith(r"$")) {
        configs[name] = value;
      } else {
        attributes[name] = value;
      }
    } else {
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
}
