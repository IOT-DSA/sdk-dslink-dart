part of dslink.responder;

class RespSubscribeListener {
  ValueUpdateCallback callback;
  LocalNode node;

  RespSubscribeListener(this.node, this.callback);

  void cancel() {
    if (callback != null) {
      node.unsubscribe(callback);
      callback = null;
    }
  }
}

class SubscribeResponse extends Response {
  final String path;
  final LocalNode node;
  final int qos;

  RespSubscribeController _controller;

  SubscribeResponse(Responder responder, int rid, this.path, this.node, this.qos) :
      super(DSPacketMethod.subscribe, responder, rid) {
    int permission = responder.nodeProvider.permissions
      .getPermission(node.path, responder);

    _controller = new RespSubscribeController(
      this,
      node,
      permission >= Permission.READ,
      qos
    );

    if (responder._traceCallbacks != null) {
      ResponseTrace update = new ResponseTrace(
        path,
        'subscribe',
        rid,
        '+'
      );

      for (ResponseTraceCallback callback in responder._traceCallbacks) {
        callback(update);
      }
    }
  }

  void remove() {
    _controller.destroy();

    if (responder._traceCallbacks != null) {
      ResponseTrace update = new ResponseTrace(
        _controller.node.path,
        'subscribe',
        rid,
        '-'
      );

      for (ResponseTraceCallback callback in responder._traceCallbacks) {
        callback(update);
      }
    }

    close();
  }

  void subscriptionChanged(RespSubscribeController controller) {
    prepareSending();
  }

  @override
  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;

    if (waitingAckId != -1) {
      _waitingAckCount++;
      _lastWaitingAckId = waitingAckId;
    }

    List updates = new List();
    updates.addAll(_controller.process(waitingAckId));
    responder.updateResponse(this, updates, streamStatus: StreamStatus.open);
  }

  int _waitingAckCount = 0;
  int _lastWaitingAckId = -1;

  void ackReceived(int receiveAckId, int startTime, int currentTime) {
    if (receiveAckId == _lastWaitingAckId) {
      _waitingAckCount = 0;
    } else {
      _waitingAckCount--;
    }

    _controller.onAck(receiveAckId);

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

    if (responder.connection == null) {
      // don't pend send, when requester is offline
      return;
    }

    if (!_pendingSending) {
      _pendingSending = true;
      responder.addProcessor(this);
    }
  }

  void _close() {
    _controller.destroy();
    _waitingAckCount = 0;
    _lastWaitingAckId = -1;
    _sendingAfterAck = false;
  }

  @override
  ResponseTrace getTraceData([String change = '+']) {
    return new ResponseTrace(
      _controller.node.path,
      'subscribe',
      rid,
      '+'
    );
  }
}

class RespSubscribeController {
  final LocalNode node;
  final SubscribeResponse response;
  RespSubscribeListener _listener;

  bool _permitted = true;

  void set permitted(bool val) {
    if (val == _permitted) return;
    _permitted = val;
    if (_permitted && lastValues.length > 0) {
      response.subscriptionChanged(this);
    }
  }

  List<ValueUpdate> lastValues = new List<ValueUpdate>();
  ListQueue<ValueUpdate> waitingValues = new ListQueue<ValueUpdate>();

  //; = new ListQueue<ValueUpdate>();
  ValueUpdate lastValue;

  int _qosLevel = -1;
  ISubscriptionNodeStorage _storage;

  void set qosLevel(int v) {
    if (v < 0 || v > 3) v = 0;
    if (_qosLevel == v)
      return;

    _qosLevel = v;
    if (waitingValues == null && _qosLevel > 0) {
      waitingValues = new ListQueue<ValueUpdate>();
    }
    caching = (v & 1) == 1;
    persist = (v & 2) == 2;
  }

  bool _caching = false;

  void set caching(bool val) {
    if (val == _caching) return;
    _caching = val;
    if (!_caching) {
      lastValues.length = 0;
    }
  }

  bool _persist = false;

  void set persist(bool val) {
    if (val == _persist) return;
    _persist = val;
    ISubscriptionResponderStorage storageM = response.responder.storage;
    if (storageM != null) {
      if (_persist) {
        _storage = storageM.getOrCreateValue(node.path);
      } else if (_storage != null) {
        storageM.destroyValue(node.path);
        _storage = null;
      }
    }
  }

  RespSubscribeController(this.response, this.node, this._permitted,
      int qos) {
    this.qosLevel = qos;

    _listener = node.subscribe(addValue, _qosLevel);
    if (node.valueReady && node.lastValueUpdate != null) {
      addValue(node.lastValueUpdate);
    }
  }

  bool _isCacheValid = true;

  void addValue(ValueUpdate val) {
    if (_caching && _isCacheValid) {
      lastValues.add(val);
      if (lastValues.length > response.responder.maxCacheLength) {
        // cache is no longer valid, fallback to rollup mode
        _isCacheValid = false;
        lastValue = new ValueUpdate(null, ts: '');
        for (ValueUpdate update in lastValues) {
          lastValue.mergeAdd(update);
        }
        lastValues.length = 0;
        if (_qosLevel > 0) {
          if (_storage != null) {
            _storage.setValue(waitingValues, lastValue);
          }
          waitingValues
            ..clear()
            ..add(lastValue);
        }
      } else {
        lastValue = val;
        if (_qosLevel > 0) {
          waitingValues.add(lastValue);
          if (_storage != null) {
            _storage.addValue(lastValue);
          }
        }
      }
    } else {
      if (lastValue != null) {
        lastValue = new ValueUpdate.merge(lastValue, val);
      } else {
        lastValue = val;
      }
      if (_qosLevel > 0) {
        if (_storage != null) {
          _storage.setValue(waitingValues, lastValue);
        }
        waitingValues
          ..clear()
          ..add(lastValue);
      }
    }
    // TODO, don't allow this to be called from same controller more often than 100ms
    // the first response can happen ASAP, but
    if (_permitted) {
      response.subscriptionChanged(this);
    }
  }

  List process(int waitingAckId) {
    List rslts = new List();
    if (_caching && _isCacheValid) {
      for (ValueUpdate lastValue in lastValues) {
        rslts.add(lastValue.toMap());
      }

      if (_qosLevel > 0) {
        for (ValueUpdate update in lastValues) {
          update.waitingAck = waitingAckId;
        }
      }
      lastValues.length = 0;
    } else {
      Map m = lastValue.toMap();
      rslts.add(m);
      if (_qosLevel > 0) {
        lastValue.waitingAck = waitingAckId;
      }
      _isCacheValid = true;
    }
    lastValue = null;
    return rslts;
  }

  void onAck(int ackId) {
    if (waitingValues.isEmpty) {
      return;
    }
    bool valueRemoved = false;
    if (!waitingValues.isEmpty && waitingValues.first.waitingAck != ackId) {
      ValueUpdate matchUpdate;
      for (ValueUpdate update in waitingValues) {
        if (update.waitingAck == ackId) {
          matchUpdate = update;
          break;
        }
      }

      if (matchUpdate != null) {
        while (!waitingValues.isEmpty && waitingValues.first != matchUpdate) {
          ValueUpdate removed = waitingValues.removeFirst();
          if (_storage != null) {
            _storage.removeValue(removed);
            valueRemoved = true;
          }
        }
      }
    }

    while (!waitingValues.isEmpty && waitingValues.first.waitingAck == ackId) {
      ValueUpdate removed = waitingValues.removeFirst();
      if (_storage != null) {
        _storage.removeValue(removed);
        valueRemoved = true;
      }
    }

    if (valueRemoved && _storage != null) {
      _storage.valueRemoved(waitingValues);
    }
  }

  void resetCache(List<ValueUpdate> values) {
    if (this._caching) {
      if (lastValues.length > 0 && lastValues.first.equals(values.last)) {
        lastValues.removeAt(0);
      }
      lastValues = values..addAll(lastValues);
      if (waitingValues != null) {
        waitingValues.clear();
        waitingValues.addAll(lastValues);
      }
    } else {
      lastValues.length = 0;
      if (waitingValues != null) {
        waitingValues.clear();
        waitingValues.add(values.last);
      }
    }
    lastValue = values.last;
  }

  void destroy() {
    if (_storage != null) {
      ISubscriptionResponderStorage storageM = response.responder.storage;
      storageM.destroyValue(node.path);
      _storage = null;
    }
    _listener.cancel();
  }
}
