part of dslink.requester;

class DsReqListUpdate {
  /// this is only a list of changed fields
  /// when changes is null, means everything could have been changed
  List<String> changes;
  DsReqNode node;
  DsError error;
}

class DsListController {
  final DsReqNode node;
  StreamController<DsReqListUpdate> _controller;
  Stream<DsReqListUpdate> _stream;
  DsRequest _request;
  HashSet _listeners;
  DsListController(this.node) {
    _controller = new StreamController<DsReqListUpdate>();
    _stream = _controller.stream.asBroadcastStream(onListen: _onListen, onCancel: _onCancel);
    _listeners = new HashSet();
  }
  bool get initialized {
    return _request != null && _request.streamStatus != DsStreamStatus.initialize;
  }
  void _onUpdate(String status, List updates, List columns) {
    // TODO update node data and _controller

  }
  
  void _onListen(StreamSubscription<DsReqListUpdate> listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      if (_request == null) {
        _request = node.requester._sendRequest({
          'method': 'list',
          'path': node.path
        }, _onUpdate);
      }
    }
  }

  void _onCancel(StreamSubscription<DsReqListUpdate> listener) {
    if (_listeners.contains(listener)) {
      _listeners.remove(listener);
      if (_listeners.isEmpty) {
        _destroy();
      }
    }
  }
  
  void _destroy() {
    if (_request != null) {
      node.requester.closeRequest(_request);
      _request = null;
    }
    _controller.close();
    node._listController = null;
  }
}