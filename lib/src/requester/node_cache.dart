part of dslink.requester;

/// manage cached nodes for requester
/// TODO: cleanup nodes that are no longer in use
class RemoteNodeCache {
  Map<String, RemoteNode> _nodes = new Map<String, RemoteNode>();
  RemoteNodeCache() {
    // special def that should always be empty
    _nodes['/defs/profile/node'] = new RemoteDefNode('/defs/profile/node')..listed = true;
    _nodes['/defs/profile/static'] = new RemoteDefNode('/defs/profile/static')..listed = true;
  }
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
  Node getDefNode(String path) {
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
    if (mixins != null) {
      for (Node mixin in mixins) {
        if (mixin is RemoteNode && !mixin.isSelfUpdated()) {
          return false;
        }
      }
    }
    return true;
  }
  /// whether the node's own data is updated
  bool isSelfUpdated() {
    return _listController != null && _listController.initialized;
  }

  Stream<RequesterListUpdate> _list(Requester requester) {
    if (_listController == null) {
      _listController = new ListController(this, requester);
      reset();
    }
    return _listController.stream;
  }

  Stream<ValueUpdate> _subscribe(Requester requester) {
    if (_subscribeController == null) {
      _subscribeController = new ReqSubscribeController(this, requester);
    }
    return _subscribeController.stream;
  }

  Stream<RequesterInvokeUpdate> _invoke(Map params, Requester requester) {
    return new InvokeController(this, requester, params)._stream;
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
        String childPathpath;
        Node node = cache.getRemoteNode('$childPathPre/$key');
        children[key] = node;
        if (node is RemoteNode) {
          node.updateRemoteChildData(value, cache);
        }
      }
    });
  }
}

class RemoteDefNode extends RemoteNode{
  RemoteDefNode(String path) : super(path);
}
