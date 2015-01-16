part of dslink.requester;

/// manage cached nodes for requester
/// TODO: cleanup nodes that are no longer in use
class RequesterNodeCache {
  Map<String, RequesterNode> _nodes = new Map<String, RequesterNode>();
  RequesterNodeCache();
  RequesterNode getNode(String path, DsRequester requester) {
    if (!_nodes.containsKey(path)) {
      _nodes[path] = new RequesterNode(path, requester);
    }
    return _nodes[path];
  }
}

class RequesterNode extends Node {
  final DsRequester requester;

  ListController _listController;
  SubscribeController _subscribeController;

  RequesterNode(String path, this.requester) : super(path);

  /// node data is not ready until all profile and mixins are updated
  bool isUpdated() {
    if (!isSelfUpdated()) {
      return false;
    }
    if (profile is RequesterNode && !(profile as RequesterNode).isSelfUpdated()) {
      return false;
    }
    if (mixins != null) {
      for (Node mixin in mixins) {
        if (mixin is RequesterNode && !mixin.isSelfUpdated()) {
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
    return _listController._stream;
  }
  
  Stream<RequesterSubscribeUpdate> _subscribe() {
    if (_subscribeController == null) {
      _subscribeController = new SubscribeController(this);
    }
    return _subscribeController._stream;
  }
  
  Stream<RequesterInvokeUpdate> _invoke(Map params) {
    return new InvokeController(this, params)._stream;
  }
}
