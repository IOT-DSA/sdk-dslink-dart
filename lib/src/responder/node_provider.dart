part of dslink.responder;

/// Base Class for responder-side nodes.
abstract class LocalNode extends Node {
  BroadcastStreamController<String> _listChangeController;

  /// Changes to nodes will be added to this controller's stream.
  /// See [updateList].
  BroadcastStreamController<String> get listChangeController {
    if (_listChangeController == null) {
      _listChangeController = new BroadcastStreamController<String>(
        () {
          onStartListListen();
        }, () {
          onAllListCancel();
        }, null, true);
    }
    return _listChangeController;
  }

  void overrideListChangeController(BroadcastStreamController<String> controller) {
    _listChangeController = controller;
  }

  /// List Stream.
  /// See [listChangeController].
  Stream<String> get listStream => listChangeController.stream;

  /// Callback for when listing this node has started.
  void onStartListListen() {}

  /// Callback for when all lists are canceled.
  void onAllListCancel() {}

  bool get _hasListListener => _listChangeController?.hasListener ?? false;

  /// Node Provider
  NodeProvider get provider;

  /// Node Path
  final String path;

  LocalNode(this.path);

  /// Subscription Callbacks
  Map<ValueUpdateCallback, int> callbacks = new Map<ValueUpdateCallback, int>();

  /// Subscribes the given [callback] to this node.
  RespSubscribeListener subscribe(callback(ValueUpdate update), [int qos = 0]) {
    callbacks[callback] = qos;
    return new RespSubscribeListener(this, callback);
  }

  /// Unsubscribe the given [callback] from this node.
  void unsubscribe(ValueUpdateCallback callback) {
    if (callbacks.containsKey(callback)) {
      callbacks.remove(callback);
    }
  }

  ValueUpdate _lastValueUpdate;

  /// Gets the last value update of this node.
  ValueUpdate get lastValueUpdate {
    if (_lastValueUpdate == null) {
      _lastValueUpdate = new ValueUpdate(null);
    }
    return _lastValueUpdate;
  }

  /// Gets the current value of this node.
  dynamic get value {
    if (_lastValueUpdate != null) {
      return _lastValueUpdate.value;
    }
    return null;
  }

  bool _valueReady = false;
  /// Is the value ready?
  bool get valueReady => _valueReady;

  /// Updates this node's value to the specified [value].
  void updateValue(Object update, {bool force: false}) {
    _valueReady = true;
    if (update is ValueUpdate) {
      _lastValueUpdate = update;
      callbacks.forEach((callback, qos) {
        callback(_lastValueUpdate);
      });
    } else if (_lastValueUpdate == null ||
        _lastValueUpdate.value != update ||
        force) {
      _lastValueUpdate = new ValueUpdate(update);
      callbacks.forEach((callback, qos) {
        callback(_lastValueUpdate);
      });
    }
  }

  void clearValue() {
    _valueReady = false;
    _lastValueUpdate = null;
  }

  /// Checks if this node exists.
  /// list and subscribe can be called on a node that doesn't exist
  /// Other things like set remove, and invoke can only be applied to an existing node.
  bool get exists => true;

  /// whether the node is ready for returning a list response
  bool get listReady => true;

  /// Disconnected Timestamp
  String get disconnected => null;
  List getDisconnectedListResponse() {
    return [
      [r'$disconnectedTs', disconnected]
    ];
  }


  /// Checks if this node has a subscriber.
  /// Use this for things like polling when you
  /// only want to do something if the node is subscribed to.
  bool get hasSubscriber => callbacks.isNotEmpty;

  /// Gets the invoke permission for this node.
  int getInvokePermission() {
    return Permission.parse(getConfig(r'$invokable'));
  }

  /// Gets the set permission for this node.
  int getSetPermission() {
    return Permission.parse(getConfig(r'$writable'));
  }

  /// Called by the link internals to invoke this node.
  InvokeResponse invoke(
    Map<String, dynamic> params,
    Responder responder,
    InvokeResponse response,
    Node parentNode, [int maxPermission = Permission.CONFIG]) {
    return response..close();
  }

  /// Called by the link internals to set an attribute on this node.
  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    if (response != null) {
      return response..close();
    } else {
      if (!name.startsWith("@")) {
        name = "@${name}";
      }

      logger.finest('Provider: $path/$name set to: $value');
      attributes[name] = value;

      if (provider is SerializableNodeProvider) {
        (provider as SerializableNodeProvider).persist();
      }

      return null;
    }
  }

  /// Called by the link internals to remove an attribute from this node.
  Response removeAttribute(
      String name, Responder responder, Response response) {
    if (response != null) {
      return response..close();
    } else {
      if (!name.startsWith("@")) {
        name = "@${name}";
      }

      logger.finest('Provider: $path/$name attribute removed');
      attributes.remove(name);

      if (provider is SerializableNodeProvider) {
        (provider as SerializableNodeProvider).persist();
      }

      return null;
    }
  }

  /// Called by the link internals to set a config on this node.
  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    if (response != null) {
      return response..close();
    } else {
      if (!name.startsWith(r"$")) {
        name = "\$${name}";
      }

      configs[name] = value;

      return null;
    }
  }

  /// Called by the link internals to remove a config from this node.
  Response removeConfig(String name, Responder responder, Response response) {
    if (response != null) {
      return response..close();
    } else {
      if (!name.startsWith(r"$")) {
        name = "\$${name}";
      }
      configs.remove(name);

      return null;
    }
  }

  /// Called by the link internals to set a value of a node.
  Response setValue(Object value, Responder responder, Response response,
      [int maxPermission = Permission.CONFIG]) {
    return response..close();
  }

  /// Shortcut to [get].
  operator [](String name) {
    return get(name);
  }

  /// Set a config, attribute, or child on this node.
  operator []=(String name, Object value) {
    if (name.startsWith(r"$")) {
      configs[name] = value;
    } else if (name.startsWith(r"@")) {
      attributes[name] = value;
    } else if (value is Node) {
      addChild(name, value);
    }
  }

  void load(Map<String, dynamic> map) {
  }
}

/// Provides Nodes for a responder.
/// A single node provider can be reused by multiple responder.
abstract class NodeProvider {
  /// Gets an existing node.
  LocalNode getNode(String path);

  /// Gets a node at the given [path] if it exists.
  /// If it does not exist, create a new node and return it.
  ///
  /// When [addToTree] is false, the node will not be inserted into the node provider.
  LocalNode getOrCreateNode(String path, [bool addToTree = true]);

  /// Gets an existing node, or creates a dummy node for a requester to listen on.
  LocalNode operator [](String path) {
    return getNode(path);
  }

  /// Get the root node.
  LocalNode operator ~() => getOrCreateNode("/", false);

  /// Create a Responder
  Responder createResponder(String dsId, String sessionId);

  /// Get Permissions.
  IPermissionManager get permissions;
}
