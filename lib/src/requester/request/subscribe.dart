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

  // TODO: define a custom class to replace StreamSubscription
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

  void onUpdate(String status, List updates, List columns, Map meta,
      DSError error) {
    // do nothing
  }
}

class SubscribeRequest extends Request implements ConnectionProcessor {
  int lastSid = 0;

  int getNextSid() {
    do {
      if (lastSid < 0x7FFFFFFF) {
        ++lastSid;
      } else {
        lastSid = 1;
      }
    } while (subscriptionIds.containsKey(lastSid));
    return lastSid;
  }

  final Map<String, ReqSubscribeController> subscriptions =
    new Map<String, ReqSubscribeController>();

  final Map<int, ReqSubscribeController> subscriptionIds =
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
    if (subscriptions.isNotEmpty) {
      _changedPaths.addAll(subscriptions.keys);
    }
    _waitingAckCount = 0;
    _lastWatingAckId = -1;
    _sendingAfterAck = false;
  }

  @override
  void _update(Map m) {
    List updates = m['updates'];
    if (updates is List) {
      for (Object update in updates) {
        String path;
        int sid = -1;
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

        ReqSubscribeController controller;
        if (path != null) {
          controller = subscriptions[path];
        } else if (sid > -1) {
          controller = subscriptionIds[sid];
        }

        if (controller != null) {
          var valueUpdate = new ValueUpdate(value, ts: ts, meta: meta);
          controller.addValue(valueUpdate);
        }
      }
    }
  }

  HashSet<String> _changedPaths = new HashSet<String>();

  void addSubscription(ReqSubscribeController controller, int level) {
    String path = controller.node.remotePath;
    subscriptions[path] = controller;
    subscriptionIds[controller.sid] = controller;
    prepareSending();
    _changedPaths.add(path);
  }

  void removeSubscription(ReqSubscribeController controller) {
    String path = controller.node.remotePath;
    if (subscriptions.containsKey(path)) {
      toRemove[subscriptions[path].sid] = subscriptions[path];
      prepareSending();
    } else if (subscriptionIds.containsKey(controller.sid)) {
      logger.severe(
          'unexpected remoteSubscription in the requester, sid: ${controller
              .sid}');
    }
  }

  Map<int, ReqSubscribeController> toRemove =
    new Map<int, ReqSubscribeController>();

  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;

    if (waitingAckId != -1) {
      _waitingAckCount++;
      _lastWatingAckId = waitingAckId;
    }

    if (requester.connection == null) {
      return;
    }
    List toAdd = [];

    HashSet<String> processingPaths = _changedPaths;
    _changedPaths = new HashSet<String>();
    for (String path in processingPaths) {
      if (subscriptions.containsKey(path)) {
        ReqSubscribeController sub = subscriptions[path];
        Map m = {'path': path, 'sid': sub.sid};
        if (sub.currentQos > 0) {
          m['qos'] = sub.currentQos;
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
          subscriptions.remove(sub.node.remotePath);
          subscriptionIds.remove(sub.sid);
          sub._destroy();
        }
      });
      requester._sendRequest(
          {'method': 'unsubscribe', 'sids': removeSids}, null);
      toRemove.clear();
    }
  }

  bool _pendingSending = false;
  int _waitingAckCount = 0;
  int _lastWatingAckId = -1;

  void ackReceived(int receiveAckId, int startTime, int currentTime) {
    if (receiveAckId == _lastWatingAckId) {
      _waitingAckCount = 0;
    } else {
      _waitingAckCount--;
    }

    if (_sendingAfterAck) {
      _sendingAfterAck = false;
      prepareSending();
    }
  }

  bool _sendingAfterAck = false;

  void prepareSending() {
    if (_sendingAfterAck) {
      return;
    }

    if (_waitingAckCount > ConnectionProcessor.ACK_WAIT_COUNT) {
      _sendingAfterAck = true;
      return;
    }

    if (!_pendingSending) {
      _pendingSending = true;
      requester.addProcessor(this);
    }
  }
}

class ReqSubscribeController {
  final RemoteNode node;
  final Requester requester;

  Map<Function, int> callbacks = new Map<Function, int>();
  int currentQos = -1;
  int sid;

  ReqSubscribeController(this.node, this.requester) {
    sid = requester._subscription.getNextSid();

    node.increaseRefCount();
  }

  void listen(callback(ValueUpdate update), int qos) {
    if (qos < 0 || qos > 3) {
      qos = 0;
    }
    bool qosChanged = false;

    if (callbacks.containsKey(callback)) {
      if (callbacks[callback] != 0) {
        callbacks[callback] = qos;
        qosChanged = updateQos();
      } else {
        callbacks[callback] = qos;
      }
    } else {
      callbacks[callback] = qos;
      int neededQos = qos;
      if (currentQos > -1) {
        neededQos |= currentQos;
      }
      qosChanged = neededQos > currentQos;
      currentQos = neededQos;
      if (_lastUpdate != null) {
        callback(_lastUpdate);
      }
    }

    if (qosChanged) {
      requester._subscription.addSubscription(this, currentQos);
    }
  }

  void unlisten(callback(ValueUpdate update)) {
    if (callbacks.containsKey(callback)) {
      int cacheLevel = callbacks.remove(callback);
      if (callbacks.isEmpty) {
        requester._subscription.removeSubscription(this);
      } else if (cacheLevel == currentQos && currentQos > 1) {
        updateQos();
      }
    }
  }

  bool updateQos() {
    int qosCache = 0;

    for (var qos in callbacks.values) {
      qosCache |= qos;
    }

    if (qosCache != currentQos) {
      currentQos = qosCache;
      return true;
    }
    return false;
  }

  ValueUpdate _lastUpdate;

  void addValue(ValueUpdate update) {
    _lastUpdate = update;
    for (Function callback in callbacks.keys.toList()) {
      callback(_lastUpdate);
    }
  }

  void _destroy() {
    callbacks.clear();
    node._subscribeController = null;
    node.decreaseRefCount();
  }
}
