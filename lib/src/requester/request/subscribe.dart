part of dslink.requester;

class ReqSubscribeListener implements StreamSubscription {
  Function callback;
  Requester requester;
  String path;
  ReqSubscribeListener(this.requester, this.path, this.callback);
  Future cancel() {
    if (callback != null) {
      requester.unsubscribe(path, callback);
      callback = null;
    }
    return null;
  }

  // TODO  define a custom class to replace StreamSubscription
  Future asFuture([futureValue]) {
    return null;
  }

  bool get isPaused => false;

  void onData(void handleData(data)) {}

  void onDone(void handleDone()) {}

  void onError(Function handleError) {}

  void pause([Future resumeSignal]) {}

  void resume() {}
}

/// only a place holder for reconnect and disconnect
/// real logic is in SubscribeRequest itself
class SubscribeController implements RequestUpdater {
  SubscribeRequest request;
  SubscribeController();
  void onDisconnect() {
    // TODO: implement onDisconnect
  }

  void onReconnect() {
    // TODO: implement onReconnect
  }

  void onUpdate(String status, List updates, List columns, Map meta, DSError error) {
    // do nothing
  }
}

class SubscribeRequest extends Request implements ConnectionProcessor{
  final Map<String, ReqSubscribeController> subsriptions =
      new Map<String, ReqSubscribeController>();

  final Map<int, ReqSubscribeController> subsriptionids =
      new Map<int, ReqSubscribeController>();

  SubscribeRequest(Requester requester, int rid)
      : super(requester, rid, new SubscribeController(), null) {
    (updater as SubscribeController).request = this;
  }

  @override
  void resend() {
    prepareSending();
  }

  @override
  void _close([DSError error]) {
    if (subsriptions.isNotEmpty) {
      subsriptions.forEach((String path, ReqSubscribeController controller) {
        _changedPaths.add(path);
      });
    }
  }

  @override
  void _update(Map m) {
    List updates = m['updates'];
    if (updates is List) {
      for (Object update in updates) {
        String path;
        int sid = -1;
        ;
        Object value;
        String ts;
        Map meta;
        if (update is Map) {
          if (update['ts'] is String) {
            path = update['path'];
            ts = update['ts'];
            if (update['path'] is String) {
              path = update['path'];
            } else if (update['sid'] is int) {
              sid = update['sid'];
            } else {
              continue; // invalid response
            }
          }
          value = update['value'];
          meta = update;
        } else if (update is List && update.length > 2) {
          if (update[0] is String) {
            path = update[0];
          } else if (update[0] is int) {
            sid = update[0];
          } else {
            continue; // invalid response
          }
          value = update[1];
          ts = update[2];
        } else {
          continue; // invalid response
        }
        if (path != null && subsriptions.containsKey(path)) {
          subsriptions[path]
              .addValue(new ValueUpdate(value, ts: ts, meta: meta));
        } else if (sid > -1 && subsriptionids.containsKey(sid)) {
          subsriptionids[sid]
              .addValue(new ValueUpdate(value, ts: ts, meta: meta));
        }
      }
    }
  }

  HashSet<String> _changedPaths = new HashSet<String>();
  void addSubscription(ReqSubscribeController controller, int level) {
    String path = controller.node.remotePath;
    subsriptions[path] = controller;
    subsriptionids[controller.sid] = controller;
    prepareSending();
    _changedPaths.add(path);
  }

  void removeSubscription(ReqSubscribeController controller) {
    String path = controller.node.remotePath;
    if (subsriptions.containsKey(path)) {
      toRemove[subsriptions[path].sid] = subsriptions[path];
      prepareSending();
    } else if (subsriptionids.containsKey(controller.sid)) {
      logger.severe(
          'unexpected remoteSubscription in the requester, sid: ${controller.sid}');
    }
  }

  Map<int, ReqSubscribeController> toRemove = new Map<int, ReqSubscribeController>();
  void prepareSending(){
    if (!_pendingSend) {
      _pendingSend = true;
      requester.addProcessor(this);
    }
  }
  bool _pendingSend = false;
  void startSendingData() {
    _pendingSend = false;
    if (requester.connection == null) {
      return;
    }
    List toAdd = [];

    HashSet<String> processingPaths = _changedPaths;
    _changedPaths = new HashSet<String>();
    for (String path in processingPaths) {
      if (subsriptions.containsKey(path)) {
        ReqSubscribeController sub = subsriptions[path];
        Map m = {'path': path, 'sid': sub.sid};
        if (sub.maxCache > 1) {
          m['cache'] = sub.maxCache;
        }
        toAdd.add(m);
      }
    }
    if (!toAdd.isEmpty) {
      requester._sendRequest({'method': 'subscribe', 'paths': toAdd}, null);
    }
    if (!toRemove.isEmpty) {
      List removeSids = [];
      toRemove.forEach((int sid, ReqSubscribeController sub) {
        if (sub.callbacks.isEmpty) {
          removeSids.add(sid);
          subsriptions.remove(sub.node.remotePath);
          subsriptionids.remove(sub.sid);
          sub._destroy();
        }
      });
      requester._sendRequest({'method': 'unsubscribe', 'sids': removeSids}, null);
      toRemove.clear();
    }
  }

  void ackWaiting(int ackId) {
    // TODO: implement ackSent
  }
  void ackReceived(int ackId) {
    // TODO: implement ackReceived
  }
}

class ReqSubscribeController {
  final RemoteNode node;
  final Requester requester;

  Map<Function, int> callbacks = new Map<Function, int>();
  int maxCache = 0;
  int sid;
  ReqSubscribeController(this.node, this.requester) {
    sid = requester.nextSid++;
  }

  void listen(callback(ValueUpdate), int cacheLevel) {
    if (cacheLevel < 1) cacheLevel = 1;
    if (cacheLevel > 1000000) cacheLevel = 1000000;
    if (cacheLevel > maxCache) {
      maxCache = cacheLevel;
      requester._subsciption.addSubscription(this, maxCache);
    }

    if (callbacks.containsKey(callback)) {
      if (callbacks[callback] == maxCache && cacheLevel < maxCache) {
        callbacks[callback] = cacheLevel;
        updateCacheLevel();
      } else {
        callbacks[callback] = cacheLevel;
      }
    } else {
      callbacks[callback] = cacheLevel;
      if (_lastUpdate != null) {
        callback(_lastUpdate);
      }
    }
  }

  void unlisten(callback(ValueUpdate)) {
    if (callbacks.containsKey(callback)) {
      int cacheLevel = callbacks.remove(callback);
      if (callbacks.isEmpty) {
        requester._subsciption.removeSubscription(this);
      } else if (cacheLevel == maxCache && maxCache > 1) {
        updateCacheLevel();
      }
    }
  }

  void updateCacheLevel() {
    int maxCacheLevel = 1;
    callbacks.forEach((callback, level) {
      if (level > maxCacheLevel) {
        maxCacheLevel = level;
      }
    });
    if (maxCacheLevel != maxCache) {
      maxCache = maxCacheLevel;
      requester._subsciption.addSubscription(this, maxCache);
    }
  }

  ValueUpdate _lastUpdate;
  void addValue(ValueUpdate update) {
    _lastUpdate = update;
    for (Function callback in callbacks.keys.toList()) {
      callback(_lastUpdate);
    }
    ;
  }
  
  void _destroy() {
    callbacks.clear();
    node._subscribeController = null;
  }
}
