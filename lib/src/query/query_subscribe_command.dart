part of dslink.query;

class _QuerySubscription {
  final QueryCommandSubscribe command;
  final LocalNode node;
  RespSubscribeListener listener;

  /// if removed, the subscription will be destroyed next frame
  bool removed = false;
  bool justAdded = true;
  _QuerySubscription(this.command, this.node) {
    if (node.valueReady) {
      valueCallback(node.lastValueUpdate);
    }
    listener = node.subscribe(valueCallback);
  }

  ValueUpdate lastUpdate;
  void valueCallback(ValueUpdate value) {
    lastUpdate = value;
    command.updateRow(getRowData());
  }

  List getRowData() {
    // TODO: make sure node still in tree
    // because list remove node update could come one frame later
    if (!removed && lastUpdate != null) {
      if (justAdded) {
        justAdded = false;
        return [node.path, '+', lastUpdate.value, lastUpdate.ts];
      } else {
        return [node.path, '', lastUpdate.value, lastUpdate.ts];
      }
    }
    return null;
  }

  List getRowDataForNewResponse() {
    if (!removed && !justAdded && lastUpdate != null) {
      return [node.path, '+', lastUpdate.value, lastUpdate.ts];
    }
    return null;
  }

  void destroy() {
    listener.cancel();
  }
}

class QueryCommandSubscribe extends BrokerQueryCommand {
  static List columns = [
    {'name': 'path', 'type': 'string'},
    {'name': 'change', 'type': 'string'},
    {'name': 'value', 'type': 'string'},
    {'name': 'ts', 'type': 'string'},
  ];

  QueryCommandSubscribe(BrokerQueryManager manager) : super(manager);

  void addResponse(InvokeResponse response) {
    if (_pending) {
      // send all pending update to existing responses
      // so the new response can continue on a clear state
      _doUpdate();
    }
    super.addResponse(response);
    List rows = [];
    subscriptions.forEach((String path, _QuerySubscription sub) {
      List data = sub.getRowDataForNewResponse();
      if (data != null) {
        rows.add(data);
      }
    });
    response.updateStream(rows, columns: columns);
  }

  Set<String> _changes = new Set<String>();
  Map<String, _QuerySubscription> subscriptions =
      new Map<String, _QuerySubscription>();

  bool _pending = false;
  void updatePath(String path) {
    _changes.add(path);
    if (!_pending) {
      _pending = true;
      DsTimer.callLater(_doUpdate);
    }
  }

  List _pendingRows = [];
  void updateRow(List row) {
    _pendingRows.add(row);
    if (!_pending) {
      _pending = true;
      DsTimer.callLater(_doUpdate);
    }
  }

  void _doUpdate() {
    if (!_pending) {
      return;
    }
    _pending = false;
    List rows = _pendingRows;
    _pendingRows = [];
    for (String path in _changes) {
      _QuerySubscription sub = subscriptions[path];
      if (sub != null) {
        if (sub.removed) {
          if (!sub.justAdded) {
            rows.add([path, '-', null, ValueUpdate.getTs()]);
          }
          subscriptions.remove(path);
          sub.destroy();
        } else {
          List data = sub.getRowData();
          if (data != null) {
            rows.add(data);
          }
        }
      }
    }
    _changes.clear();
    for (var resp in responses) {
      resp.updateStream(rows);
    }
  }

  // must be list result
  // new matched node [node,'+']
  // remove matched node [node, '-']
  void updateFromBase(List updates) {
    for (List data in updates) {
      if (data[0] is LocalNode) {
        LocalNode node = data[0];
        if (data[1] == '+') {
          if (!subscriptions.containsKey(node.path)) {
            subscriptions[node.path] = new _QuerySubscription(this, node);
          } else {
            subscriptions[node.path].removed = false;
          }
        } else if (data[1] == '-') {
          if (subscriptions.containsKey(node.path)) {
            subscriptions[node.path].removed = true;
            updatePath(node.path);
          }
        }
      }
    }
  }

  String toString() {
    return r'subscribe $value';
  }

  void destroy() {
    super.destroy();
    subscriptions.forEach((String key, _QuerySubscription sub) {
      sub.destroy();
    });
  }
}
