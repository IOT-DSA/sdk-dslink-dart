part of dslink.requester;

/// manage cached nodes for requester
/// TODO: cleanup nodes that are no longer in use
class RemoteNodeCache {
  Map<String, RemoteNode> _nodes =
    new LeakProofMap<String, RemoteNode>.create(
      "remote node cache"
    );

  RemoteNodeCache({
    bool enableAutoNodeCleaner: true
  }) {
    if (enableAutoNodeCleaner) {
      startNodeCleaner();
    }
  }

  void startNodeCleaner() {
    if (_cleanerTimer != null) {
      return;
    }

    _cleanerTimer = Scheduler.every(Interval.FOUR_SECONDS, () {
      clearDanglingNodes();
    });
  }

  void stopNodeCleaner() {
    if (_cleanerTimer == null) {
      return;
    }

    _cleanerTimer.cancel();
    _cleanerTimer = null;
  }

  Timer _cleanerTimer;

  RemoteNode getRemoteNode(String path) {
    if (!_nodes.containsKey(path)) {
      if (path.startsWith('defs')) {
        _nodes[path] = new RemoteDefNode(path);
      } else {
        _nodes[path] = new RemoteNode(path);
      }
    }
    return _nodes[path];
  }

  Iterable<String> get cachedNodePaths => _nodes.keys;

  void clearDanglingNodes([bool handler(RemoteNode node) = _clearNodeIfRefZero]) {
    List<String> toRemove = [];
    for (String key in _nodes.keys) {
      RemoteNode node = _nodes[key];
      if (handler(node)) {
        toRemove.add(key);
      }
    }

    for (String key in toRemove) {
      logger.fine("Clearing dangling remote node at ${key}");
      clearCachedNode(key);
    }
  }

  static bool _clearNodeIfRefZero(RemoteNode node) {
    return node.referenceCount == 0;
  }

  bool isNodeCached(String path) {
    return _nodes.containsKey(path);
  }

  void clearCachedNode(String path) {
    _nodes.remove(path);
  }

  void clear() {
    _nodes.clear();
  }

  Node getDefNode(String path, String defName) {
    if (DefaultDefNodes.nameMap.containsKey(defName)) {
      return DefaultDefNodes.nameMap[defName];
    }
    return getRemoteNode(path);
  }

  /// update node with a map.
  RemoteNode updateRemoteChildNode(RemoteNode parent, String name, Map m) {
    String path;
    if (parent.remotePath == '/') {
      path = '/$name';
    } else {
      path = '${parent.remotePath}/$name';
    }
    RemoteNode rslt;
    if (_nodes.containsKey(path)) {
      rslt = _nodes[path];
      rslt.updateRemoteChildData(m, this);
    } else {
      rslt = new RemoteNode(path);
      _nodes[path] = rslt;
      rslt.updateRemoteChildData(m, this);
    }
    return rslt;
  }
}

class RemoteNode extends Node {
  final String remotePath;

  bool listed = false;
  String _name;
  String get name {
    if (_name == null) {
      _getRawName();
    }
    return _name;
  }

  ListController _listController;
  ReqSubscribeController _subscribeController;

  int get referenceCount => _referenceCount;
  int _referenceCount = 0;

  void increaseRefCount() {
    _referenceCount++;
  }

  void decreaseRefCount() {
    _referenceCount--;
  }

  RemoteNode(this.remotePath);

  void _getRawName() {
    if (remotePath == '/') {
      _name = '/';
    } else {
      _name = remotePath
        .split('/')
        .last;
    }
  }

  /// node data is not ready until all profile and mixins are updated
  bool isUpdated() {
    if (!isSelfUpdated()) {
      return false;
    }

    if (profile is RemoteNode && !(profile as RemoteNode).isSelfUpdated()) {
      return false;
    }
    return true;
  }

  /// whether the node's own data is updated
  bool isSelfUpdated() {
    return _listController != null && _listController.initialized;
  }

  Stream<RequesterListUpdate> _list(Requester requester) {
    if (_listController == null) {
      _listController = createListController(requester);
    }
    return _listController.stream;
  }

  /// need a factory function for children class to override
  ListController createListController(Requester requester) {
    return new ListController(this, requester);
  }

  void _subscribe(Requester requester, callback(ValueUpdate update), int qos) {
    if (_subscribeController == null) {
      _subscribeController = new ReqSubscribeController(this, requester);
    }
    _subscribeController.listen(callback, qos);
  }

  void _unsubscribe(Requester requester, callback(ValueUpdate update)) {
    if (_subscribeController != null) {
      _subscribeController.unlisten(callback);
    }
  }

  Stream<RequesterInvokeUpdate> _invoke(Map params, Requester requester,
    [int maxPermission = Permission.CONFIG, void fetchRawReq(Request request)]) {
    return new InvokeController(
      this, requester, params, maxPermission, fetchRawReq)._stream;
  }

  /// used by list api to update simple data for children
  void updateRemoteChildData(Map m, RemoteNodeCache cache) {
    String childPathPre;
    if (remotePath == '/') {
      childPathPre = '/';
    } else {
      childPathPre = '$remotePath/';
    }

    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        Node node = cache.getRemoteNode('$childPathPre/$key');
        children[key] = node;
        if (node is RemoteNode) {
          node.updateRemoteChildData(value, cache);
        }
      }
    });
  }

  /// clear all configs attributes and children
  void resetNodeCache() {
    configs.clear();
    attributes.clear();
    children.clear();
  }

  Map save({bool includeValue: true}) {
    var map = {};
    map.addAll(configs);
    map.addAll(attributes);
    for (String key in children.keys) {
      Node node = children[key];
      map[key] = node is RemoteNode ? node.save() : node.getSimpleMap();
    }

    if (includeValue &&
      _subscribeController != null &&
      _subscribeController._lastUpdate != null) {
      map["?value"] = _subscribeController._lastUpdate.value;
      map["?value_timestamp"] = _subscribeController._lastUpdate.ts;
    }

    return map;
  }
}

class RemoteDefNode extends RemoteNode {
  RemoteDefNode(String path) : super(path);
}
