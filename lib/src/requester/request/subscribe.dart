part of dslink.requester;

class ReqSubscribeListener implements StreamSubscription {
  ValueUpdateCallback callback;
  Requester requester;
  String path;
  ReqSubscribeController controller;

  ReqSubscribeListener(this.requester, this.path, this.callback, this.controller);

  Future cancel() {
    if (callback != null) {
      controller.unlisten(callback);
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
  }
}

class SubscribeRequest extends Request implements ConnectionProcessor {
  final String path;
  int _qos = 0;

  SubscribeRequest(Requester requester, int rid, this.path)
      : super(requester, rid, new SubscribeController(), null) {
    (updater as SubscribeController).request = this;
  }

  ReqSubscribeController controller;

  @override
  void resend() {
    prepareSending();
  }

  @override
  void _close([DSError error]) {
    _waitingAckCount = 0;
    _lastWatingAckId = -1;
    _sendingAfterAck = false;
  }

  @override
  void onNewPacket(DSResponsePacket pkt) {
    var payload = pkt.readPayloadPackage();

    if (payload is List) {
      payload.forEach(_onValueUpdate);
    } else if (payload is Map) {
      _onValueUpdate(payload);
    }
  }

  void _onValueUpdate(Map m) {
    String ts = m["ts"];
    var value = m["value"];
    var meta = m["meta"];

    if (controller != null) {
      var valueUpdate = new ValueUpdate(value, ts: ts, meta: meta);
      controller.addValue(valueUpdate);
    }
  }

  void setController(ReqSubscribeController controller) {
    this.controller = controller;
    prepareSending();
  }

  void removeSubscription() {
    close();
  }

  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;

    if (waitingAckId != -1) {
      _waitingAckCount++;
      _lastWatingAckId = waitingAckId;
    }

    if (requester.connection == null) {
      return;
    }

    var pkt = new DSRequestPacket();
    pkt.method = DSPacketMethod.subscribe;
    pkt.path = path;
    pkt.qos = _qos;
    requester._sendRequest(pkt, updater, this);
  }

  void updateQos(int qos) {
    _qos = qos;
    removeSubscription();
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
    sid = requester.getNextRid();
    _sub = new SubscribeRequest(requester, sid, node.remotePath);
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
      _sub.updateQos(qos);
      _sub.setController(this);
    }
  }

  SubscribeRequest _sub;

  void unlisten(callback(ValueUpdate update)) {
    if (callbacks.containsKey(callback)) {
      int cacheLevel = callbacks.remove(callback);
      if (callbacks.isEmpty) {
        _sub.removeSubscription();
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
  }
}
