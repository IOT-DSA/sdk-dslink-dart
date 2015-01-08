part of dslink.requester;

class DsReqSubscribeUpdate {
  String ts;
  Object value;
  Map meta;
  DsError error;
}
class DsSubscribeRequest extends DsRequest {
  final Map<String, DsSubscribeController> subsriptions = new Map<String, DsSubscribeController>();

  DsSubscribeRequest(DsRequester requester, int rid) : super(requester, rid, null);

  void _update(Map m) {
    List updates = m['updates'];
    if (updates is List) {
      // TODO, update DsSubscribeController
    }
  }


  HashSet<String> _changedPaths = new HashSet<String>();
  void addSubscription(DsSubscribeController controller) {
    String path = controller.node.path;
    if (!subsriptions.containsKey(path)) {
      subsriptions[path] = controller;
      if (_changedPaths.contains(path)) {
        _changedPaths.remove(path);
      } else {
        if (_changedPaths.isEmpty) {
          DsTimer.callLaterOnce(_sendSubscriptionReuests);
        }
        _changedPaths.add(path);
      }
    }
  }
  void removeSubscription(DsSubscribeController controller) {
    String path = controller.node.path;
    if (subsriptions.containsKey(path)) {
      subsriptions.remove(path);
      if (_changedPaths.contains(path)) {
        _changedPaths.remove(path);
      } else {
        if (_changedPaths.isEmpty) {
          DsTimer.callLaterOnce(_sendSubscriptionReuests);
        }
        _changedPaths.add(path);
      }
    }
  }
  void _sendSubscriptionReuests() {
    List toAdd = [];
    List toRemove = [];
    HashSet<String> processingPaths = _changedPaths;
    _changedPaths = new HashSet<String>();
    for (String path in _changedPaths) {
      if (subsriptions.containsKey(path)) {
        toAdd.add(path);
      } else {
        toRemove.add(path);
      }
    }
    if (!toAdd.isEmpty) {
      requester._sendRequest({
        'method': 'subscribe',
        'paths': toAdd
      }, null);
    }
    if (!toRemove.isEmpty) {
      requester._sendRequest({
        'method': 'unsubscribe',
        'paths': toRemove
      }, null);
    }
  }
}
class DsSubscribeController {
  final DsReqNode node;

  StreamController<DsReqSubscribeUpdate> _controller;
  Stream<DsReqSubscribeUpdate> _stream;
  HashSet _listeners;
  DsSubscribeController(this.node) {
    _controller = new StreamController<DsReqSubscribeUpdate>();
    _stream = _controller.stream.asBroadcastStream(onListen: _onListen, onCancel: _onCancel);
    _listeners = new HashSet();
  }



  bool _subscribing = false;
  void _onListen(StreamSubscription<DsReqSubscribeUpdate> listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
      if (!_subscribing) {
        node.requester._subsciption.addSubscription(this);
        _subscribing = true;
      }
    }
  }

  void _onCancel(StreamSubscription<DsReqSubscribeUpdate> listener) {
    if (_listeners.contains(listener)) {
      _listeners.remove(listener);
      if (_listeners.isEmpty) {
        _destroy();
      }
    }
  }

  void _destroy() {
    if (_subscribing != null) {
      node.requester._subsciption.removeSubscription(this);
    }
    _controller.close();
    node._subscribeController = null;
  }
}
