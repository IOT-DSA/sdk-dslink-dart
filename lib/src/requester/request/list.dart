part of dslink.requester;

class RequesterListUpdate extends RequesterUpdate {
  /// this is only a list of changed fields
  /// when changes is null, means everything could have been changed
  List<String> changes;
  RemoteNode node;
  RequesterListUpdate(this.node, this.changes, String streamStatus)
      : super(streamStatus);
}

class ListDefListener {
  final RemoteNode node;
  final Requester requester;

  StreamSubscription listener;

  bool ready = false;
  ListDefListener(
      this.node, this.requester, void callback(RequesterListUpdate)) {
    listener = requester
        .list(node.remotePath)
        .listen((RequesterListUpdate update) {
      ready = update.streamStatus != StreamStatus.initialize;
      callback(update);
    });
  }
  void cancel() {
    listener.cancel();
  }
}

class ListController implements RequestUpdater {
  final RemoteNode node;
  final Requester requester;
  BroadcastStreamController<RequesterListUpdate> _controller;
  Stream<RequesterListUpdate> get stream => _controller.stream;
  Request request;
  ListController(this.node, this.requester) {
    _controller = new BroadcastStreamController<RequesterListUpdate>(
        onStartListen, _onAllCancel, _onListen);
  }
  bool get initialized {
    return request != null && request.streamStatus != StreamStatus.initialize;
  }
  String disconnectTs;
  void onDisconnect() {
    disconnectTs = ValueUpdate.getTs();
    node.configs[r'$disconnectedTs'] = disconnectTs;
    _controller.add(new RequesterListUpdate(
        node, [r'$disconnectedTs'], request.streamStatus));
  }
  void onReconnect() {
    if (disconnectTs != null) {
      node.configs.remove(r'$disconnectedTs');
      disconnectTs = null;
      changes.add(r'$disconnectedTs');
    }
  }
  
  LinkedHashSet<String> changes = new LinkedHashSet<String>();
  void onUpdate(String streamStatus, List updates, List columns,
      [DSError error]) {
    // TODO implement error handling
    if (updates != null) {
      for (Object update in updates) {
        String name;
        Object value;
        bool removed = false;
        if (update is Map) {
          if (update['name'] is String) {
            name = update['name'];
          } else {
            continue; // invalid response
          }
          if (update['change'] == 'remove') {
            removed = true;
          } else {
            value = update['value'];
          }
        } else if (update is List) {
          if (update.length > 0 && update[0] is String) {
            name = update[0];
            if (update.length > 1) {
              value = update[1];
            }
          } else {
            continue; // invalid response
          }
        } else {
          continue; // invalid response
        }
        if (name.startsWith(r'$')) {
          if (name == r'$is') {
            node.children.clear();
            node.attributes.clear();
            node.configs.clear();
            loadProfile(value);
          } else if (name == r'$mixin') {
            loadMixin(value);
          }
          changes.add(name);
          if (removed) {
            node.configs.remove(name);
          } else {
            node.configs[name] = value;
          }
        } else if (name.startsWith('@')) {
          changes.add(name);
          if (removed) {
            node.attributes.remove(name);
          } else {
            node.attributes[name] = value;
          }
        } else {
          changes.add(name);
          if (removed) {
            node.children.remove(name);
          } else if (value is Map) {
            // TODO, also wait for children $is
            node.children[name] =
                requester.nodeCache.updateRemoteChildNode(node, name, value);
          }
        }
      }
      if (request.streamStatus != StreamStatus.initialize) {
        node.listed = true;
      }
      if (_pendingRemoveDef) {
        _checkRemoveDef();
      }
      onDefUpdated();
    }
  }

  Map<String, ListDefListener> _defLoaders = new Map<String, ListDefListener>();
  void loadProfile(String str) {
    if (str == 'node') {
      return;
    }
    if (!str.startsWith('/')) {
      str = '/defs/profile/$str';
    }
    if (node.profile is RemoteNode &&
        (node.profile as RemoteNode).remotePath == str) {
      return;
    }
    if (node.profile != null) {
      _pendingRemoveDef = true;
    }
    node.profile = requester.nodeCache.getDefNode(str);
    if ((node.profile is RemoteNode) && !(node.profile as RemoteNode).listed) {
      _loadDef(node.profile);
    }
  }
  String _lastMixin;
  void loadMixin(String str) {
    if (str == _lastMixin) {
      return;
    }
    _lastMixin = str;
    _pendingRemoveDef = true;
    node.mixins = [];
    for (String path in str.split('|').reversed) {
      if (!path.startsWith('/')) {
        path = '${node.remotePath}/$path';
      }
      var mixinNode = requester.nodeCache.getRemoteNode(path);
      node.mixins.add(mixinNode);
      if (_defLoaders.containsKey(path)) {
        continue;
      }
      _loadDef(node);
    }
  }
  void _loadDef(RemoteNode def) {
    if (node == def || _defLoaders.containsKey(def.remotePath)) {
      return;
    }
    ListDefListener listener =
        new ListDefListener(def, requester, _onDefUpdate);
    _defLoaders[def.remotePath] = listener;
  }
  static const List<String> _ignoreProfileProps = const [
    r'$is',
    r'$permission',
    r'$settings'
  ];
  void _onDefUpdate(RequesterListUpdate update) {
    changes.addAll(
        update.changes.where((str) => !_ignoreProfileProps.contains(str)));
    if (update.streamStatus == StreamStatus.closed) {
      if (_defLoaders.containsKey(update.node.remotePath)) {
        _defLoaders.remove(update.node.remotePath);
      }
    }
    onDefUpdated();
    printDebug('_onDefUpdated');
  }
  bool _ready = false;
  void onDefUpdated() {
    if (!_ready) {
      _ready = true;
      for (ListDefListener listener in _defLoaders.values) {
        if (!listener.ready) {
          _ready = false;
          break;
        }
      }
    }

    if (_ready) {
      if (request.streamStatus != StreamStatus.initialize) {
        _controller.add(new RequesterListUpdate(
            node, changes.toList(), request.streamStatus));
        changes.clear();
      }
      if (request.streamStatus == StreamStatus.closed) {
        _controller.close();
        for (ListDefListener listener in _defLoaders.values) {
          listener.cancel();
        }
        _defLoaders.clear();
      }
    } else {
      // TODO remove this debug code
      printDebug(_defLoaders.keys);
    }
  }
  bool _pendingRemoveDef = false;
  void _checkRemoveDef() {
    _pendingRemoveDef = false;
  }

  void onStartListen() {
    if (request == null) {
      request = requester._sendRequest(
          {'method': 'list', 'path': node.remotePath}, this);
    }
  }
  void _onListen(callback(RequesterListUpdate)) {
    if (_ready && request != null) {
      DsTimer.callLater(() {
        List changes = []
          ..addAll(node.configs.keys)
          ..addAll(node.attributes.keys)
          ..addAll(node.children.keys);
        RequesterListUpdate update =
            new RequesterListUpdate(node, changes, request.streamStatus);
        callback(update);
      });
    }
  }

  void _onAllCancel() {
    _destroy();
  }

  void _destroy() {
    _defLoaders.forEach((str, listener) {
      listener.cancel();
    });
    _defLoaders.clear();

    if (request != null) {
      requester.closeRequest(request);
      request = null;
    }

    _controller.close();
    node._listController = null;
  }
}
