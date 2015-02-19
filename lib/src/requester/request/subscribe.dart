part of dslink.requester;

class SubscribeRequest extends Request {
  final Map<String, ReqSubscribeController> subsriptions = new Map<String, ReqSubscribeController>();

  SubscribeRequest(Requester requester, int rid) : super(requester, rid, null);

  @override
  void _update(Map m) {
    List updates = m['updates'];
    if (updates is List) {
      for (Object update in updates) {
        String path;
        Object value;
        String ts;
        Map meta;
        if (update is Map) {
          if (update['path'] is String && update['ts'] is String) {
            path = update['path'];
            ts = update['ts'];
          } else {
            continue; // invalid response
          }
          value = update['value'];
          meta = update;
        } else if (update is List && update.length > 2) {
          if (update.length > 0 && update[0] is String) {
            path = update[0];
            value = update[1];
            ts = update[2];
          } else {
            continue; // invalid response
          }
        } else {
          continue; // invalid response
        }
        if (subsriptions.containsKey(path)) {
          subsriptions[path].addValue(new ValueUpdate(value, ts: ts, meta: meta));
        }
      }
    }
  }

  HashSet<String> _changedPaths = new HashSet<String>();
  void addSubscription(ReqSubscribeController controller) {
    String path = controller.node.remotePath;
    if (!subsriptions.containsKey(path)) {
      subsriptions[path] = controller;
      if (_changedPaths.contains(path)) {
        _changedPaths.remove(path);
      } else {
        requester.addProcessor(_sendSubscriptionReuests);
        _changedPaths.add(path);
      }
    }
  }
  void removeSubscription(ReqSubscribeController controller) {
    String path = controller.node.remotePath;
    if (subsriptions.containsKey(path)) {
      subsriptions.remove(path);
      if (_changedPaths.contains(path)) {
        _changedPaths.remove(path);
      } else {
        requester.addProcessor(_sendSubscriptionReuests);
        _changedPaths.add(path);
      }
    }
  }
  void _sendSubscriptionReuests() {
    if (requester.connection == null) {
      return;
    }
    List toAdd = [];
    List toRemove = [];
    HashSet<String> processingPaths = _changedPaths;
    _changedPaths = new HashSet<String>();
    for (String path in processingPaths) {
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
class ReqSubscribeController {
  final RemoteNode node;
  final Requester requester;

  BroadcastStreamController<ValueUpdate> _controller;
  Stream<ValueUpdate> get stream => _controller.stream;
  ReqSubscribeController(this.node, this.requester) {
    _controller = new BroadcastStreamController<ValueUpdate>(_onStartListen, _onAllCancel, _onListen);
  }

  ValueUpdate _lastUpdate;
  void addValue(ValueUpdate update) {
    _lastUpdate = update;
    _controller.add(_lastUpdate);
  }
  void _onListen(callback(ValueUpdate)) {
    if (_lastUpdate != null) {
      callback(_lastUpdate);
    }
  }
  bool _subscribing = false;
  void _onStartListen() {
    if (!_subscribing) {
      requester._subsciption.addSubscription(this);
      _subscribing = true;
    }
  }

  void _onAllCancel() {
    _destroy();
  }

  void _destroy() {
    if (_subscribing != null) {
      requester._subsciption.removeSubscription(this);
    }
    _controller.close();
    node._subscribeController = null;
  }
}
