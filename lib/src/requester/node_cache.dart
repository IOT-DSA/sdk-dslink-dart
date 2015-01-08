part of dslink.requester;


class DsReqNode extends DsNode {
  final DsRequester requester;

  DsListController _listController;
  DsSubscribeController _subscribeController;

  DsReqNode(String path, this.requester) : super(path);

  /// node data is not ready until all profile and mixins are updated
  bool isUpdated() {
    if (!isSelfUpdated()) {
      return false;
    }
    if (profile is DsReqNode && !(profile as DsReqNode).isSelfUpdated()) {
      return false;
    }
    if (mixins != null) {
      for (DsNode mixin in mixins) {
        if (mixin is DsReqNode && !mixin.isSelfUpdated()) {
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

  Stream<DsReqListUpdate> _list() {
    if (_listController == null) {
      _listController = new DsListController(this);
      reset();
    }
    return _listController._stream;
  }
  Stream<DsReqSubscribeUpdate> _subscribe() {
    if (_subscribeController == null) {
      _subscribeController = new DsSubscribeController(this);
    }
    return _subscribeController._stream;
  }
}
