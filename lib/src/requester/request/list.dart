part of dslink.requester;

class DsReqListUpdate {
  /// this is only a list of changed fields
  /// when changes is null, means everything could have been changed
  List<String> changes;
  DsReqNode node;
  DsError error;
}

class DsReqNode extends DsNode {
  final DsRequester requester;

  StreamController<DsReqListUpdate> _controller;
  Stream<DsReqListUpdate> _stream;
  DsRequest _request;

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
    return _request != null && _request.streamStatus != DsStreamStatus.initialize;
  }

  Stream<DsReqListUpdate> _list() {
    if (_stream == null) {
      _controller = new StreamController<DsReqListUpdate>();
      _stream = _controller.stream.asBroadcastStream(onListen: _onListen, onCancel: _onCancel);
      _subscriptions = new HashSet();
      _clearProperties();
    }
    return _stream;
  }

  void _onUpdate(String status, List updates, List columns) {

    if (status == DsStreamStatus.closed) {
      _clearRequest();
    }
  }

  HashSet _subscriptions;

  void _onListen(StreamSubscription<DsReqListUpdate> subscription) {
    if (!_subscriptions.contains(subscription)) {
      _subscriptions.add(subscription);
      if (_request == null) {
        _request = requester._sendRequest({
          'method': 'list',
          'path': path
        }, _onUpdate);
      }
    }
  }

  void _onCancel(StreamSubscription<DsReqListUpdate> subscription) {
    if (_subscriptions.contains(subscription)) {
      _subscriptions.remove(subscription);
      if (_subscriptions.isEmpty) {
        _clearRequest();
      }
    }
  }

  /// clear all configs attributes and children before reloading
  void _clearProperties() {

  }

  /// stop request and the stream
  void _clearRequest() {
    if (_request != null) {
      requester.close(_request);
      _request = null;
    }

    if (_controller != null) {
      _controller.close();
      _controller = null;
      _stream = null;
    }
  }
}
