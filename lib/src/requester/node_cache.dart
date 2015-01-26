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
  RemoteNode updateRemoteNode(Map m) {
    //TODO
    return null;
  }
}

class RemoteNode extends Node {
  final Requester requester;
  final String remotePath;
  ListController _listController;
  ReqSubscribeController _subscribeController;

  RemoteNode(this.remotePath, this.requester);

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
}

class RequesterProfileNode extends RemoteNode {
  RequesterProfileNode(String path, Requester requester) : super(path, requester);
}
