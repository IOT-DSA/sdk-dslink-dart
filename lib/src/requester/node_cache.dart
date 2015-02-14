part of dslink.requester;

/// manage cached nodes for requester
/// TODO: cleanup nodes that are no longer in use
class RemoteNodeCache {
  Map<String, RemoteNode> _nodes = new Map<String, RemoteNode>();
  RemoteNodeCache();
  RemoteNode getRemoteNode(String path, Requester requester) {
    if (!_nodes.containsKey(path)) {
      _nodes[path] = new RemoteNode(path, requester);
    }
    return _nodes[path];
  }
  /// update node with a map.
  RemoteNode updateRemoteNode(RemoteNode parent, String name, Map m) {
    String path;
    if (parent.remotePath == '/') {
      path = '/$name';
    } else {
      path = '${parent.remotePath}/$name';
    }
    RemoteNode rslt;
    if (_nodes.containsKey(path)) {
      rslt = _nodes[path];
      rslt.updateRemoteData(m, this);
    } else {
      rslt = new RemoteNode(path, parent.requester);
      _nodes[path] = rslt;
      rslt.updateRemoteData(m, this);
    }
    return rslt;
  }
}

class RemoteNode extends Node {
  final Requester requester;
  final String remotePath;
  bool listed = false;
  String name;
  ListController _listController;
  ReqSubscribeController _subscribeController;

  RemoteNode(this.remotePath, this.requester) {
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

  Stream<RequesterListUpdate> _list() {
    if (_listController == null) {
      _listController = new ListController(this);
      reset();
    }
    return _listController.stream;
  }

  Stream<ValueUpdate> _subscribe() {
    if (_subscribeController == null) {
      _subscribeController = new ReqSubscribeController(this);
    }
    return _subscribeController.stream;
  }

  Stream<RequesterInvokeUpdate> _invoke(Map params) {
    return new InvokeController(this, params)._stream;
  }

  /// used by list api to update simple data for children
  void updateRemoteData(Map m, RemoteNodeCache cache) {
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
        Node node = cache.getRemoteNode('$childPathPre/$key', requester);
        children[key] = node;
        if (node is RemoteNode) {
          node.updateRemoteData(value, cache);
        }
      }
    });
  }
}

class RequesterProfileNode extends RemoteNode {
  RequesterProfileNode(String path, Requester requester) : super(path, requester);
}
