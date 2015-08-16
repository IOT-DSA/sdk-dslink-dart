part of dslink.requester;

/// manage cached nodes for requester
/// TODO: cleanup nodes that are no longer in use
class RemoteNodeCache {
  Map<String, RemoteNode> _nodes = new Map<String, RemoteNode>();
  RemoteNodeCache() {}
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
  String name;
  ListController _listController;
  ReqSubscribeController _subscribeController;

  RemoteNode(this.remotePath) {
    _getRawName();
  }
  void _getRawName() {
    if (remotePath == '/') {
      name = '/';
    } else {
      name = remotePath.split('/').last;
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
      [int maxPermission = Permission.CONFIG]) {
    return new InvokeController(this, requester, params, maxPermission)._stream;
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
}

class RemoteDefNode extends RemoteNode {
  RemoteDefNode(String path) : super(path);
}
