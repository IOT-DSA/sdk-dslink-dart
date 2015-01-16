part of dslink.requester;

class RequesterListUpdate {
  /// this is only a list of changed fields
  /// when changes is null, means everything could have been changed
  List<String> changes;
  RequesterNode node;
  DSError error;
}

class ListController {
  final RequesterNode node;
  StreamController<RequesterListUpdate> _controller;
  Stream<RequesterListUpdate> _stream;
  Request _request;
  HashSet _listeners;
  ListController(this.node) {
    _controller = new StreamController<RequesterListUpdate>();
    _stream = _controller.stream.asBroadcastStream(onListen: _onListen, onCancel: _onCancel);
    _listeners = new HashSet();
  }
  bool get initialized {
    return _request != null && _request.streamStatus != StreamStatus.initialize;
  }
  void _onUpdate(String status, List updates, List columns) {
    // TODO update node data and _controller

  }

  void _onListen(StreamSubscription<RequesterListUpdate> listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      if (_request == null && node.requester.connection != null) {
        _request = node.requester._sendRequest({
          'method': 'list',
          'path': node.path
        }, _onUpdate);
      }
    }
  }

  void _onCancel(StreamSubscription<RequesterListUpdate> listener) {
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
