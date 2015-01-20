part of dslink.requester;

class RequesterListUpdate extends RequesterUpdate {
  /// this is only a list of changed fields
  /// when changes is null, means everything could have been changed
  List<String> changes;
  RequesterNode node;
  RequesterListUpdate(this.node, this.changes);
}

class ListController {
  final RequesterNode node;
  StreamController<RequesterListUpdate> _controller;
  Stream<RequesterListUpdate> _stream;
  Request _request;
  final HashSet _listeners = new HashSet();
  ListController(this.node) {
    _controller = new StreamController<RequesterListUpdate>();
    _stream = _controller.stream.asBroadcastStream(onListen: _onListen, onCancel: _onCancel);
  }
  bool get initialized {
    return _request != null && _request.streamStatus != StreamStatus.initialize;
  }

  LinkedHashSet<String> changes = new LinkedHashSet<String>();
  void _onUpdate(String status, List updates, List columns) {
    if (updates != null) {
      for (Object update in updates) {
        String name;
        Object value;
        bool removed = false;
        if (update is Map) {
          if (update['name'] is String) {
            name = update['name'];
          } else {
            continue; // invalid response
          }
          if (update['change'] == 'remove') {
            removed = true;
          } else {
            value = update['value'];
          }
        } else if (update is List) {
          if (update.length > 0 && update[0] is String) {
            name = update[0];
            if (update.length > 1) {
              value = update[1];
            }
          } else {
            continue; // invalid response
          }
        } else {
          continue; // invalid response
        }
        if (name.startsWith(r'$')) {
          // TODO, loading for $is and $mixin
          changes.add(name);
          if (removed) {
            node.configs.remove(name);
          } else {
            node.configs[name] = value;
          }
        } else if (name.startsWith('@')) {
          changes.add(name);
          if (removed) {
            node.attributes.remove(name);
          } else {
            node.attributes[name] = value;
          }
        } else {
          changes.add(name);
          if (removed) {
            node.children.remove(name);
          } else if (value is Map) {
            node.children[name] = node.requester._nodeCache.updateNode(value);
          }
        }
      }
      if (_request.streamStatus != StreamStatus.initialize) {
        _controller.add(new RequesterListUpdate(node, changes.toList()));
        changes.clear();
      }
    }
    if (status == StreamStatus.closed) {
      _controller.close();
    }
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
