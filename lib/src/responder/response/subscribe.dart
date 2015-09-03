part of dslink.responder;

class RespSubscribeListener {
  Function callback;
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
  SubscribeResponse(Responder responder, int rid) : super(responder, rid);

  final Map<String, RespSubscribeController> subsriptions =
      new Map<String, RespSubscribeController>();
  final Map<int, RespSubscribeController> subsriptionids =
      new Map<int, RespSubscribeController>();

  final LinkedHashSet<RespSubscribeController> changed =
      new LinkedHashSet<RespSubscribeController>();

  void add(String path, LocalNode node, int sid, int qos) {
    if (subsriptions[path] != null) {
      RespSubscribeController controller = subsriptions[path];
      if (controller.sid != sid) {
        subsriptionids.remove(controller.sid);
        controller.sid == sid;
        subsriptionids[sid] = controller;
      }
      controller.qosLevel = qos;
    } else {
      int permission = responder.nodeProvider.permissions
          .getPermission(node.path, responder);
      RespSubscribeController controller = new RespSubscribeController(
          this, node, sid, permission >= Permission.READ, qos);
      subsriptions[path] = controller;
      subsriptionids[sid] = controller;
      if (responder._traceCallbacks != null){
        ResponseTrace update = new ResponseTrace(path,'subscribe',0,'+');
        for (ResponseTraceCallback callback in responder._traceCallbacks) {
          callback(update);
        }  
      }
    }
  }

  void remove(int sid) {
    if (subsriptionids[sid] != null) {
      RespSubscribeController controller = subsriptionids[sid];
      subsriptionids[sid].destroy();
      subsriptionids.remove(sid);
      subsriptions.remove(controller.node.path);
      if (responder._traceCallbacks != null){
        ResponseTrace update = new ResponseTrace(controller.node.path,'subscribe',0,'-');
        for (ResponseTraceCallback callback in responder._traceCallbacks) {
          callback(update);
        }  
      }
    }
  }

  void subscriptionChanged(RespSubscribeController controller) {
    changed.add(controller);
    prepareSending();
  }
  @override
  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;
    
    if (waitingAckId != -1) {
      _waitingAckCount++;
      _lastWatingAckId = waitingAckId;
    }
  
    List updates = [];
    for (RespSubscribeController controller in changed) {
      updates.addAll(controller.process(waitingAckId));
    }
    responder.updateResponse(this, updates);
    changed.clear();
  }

  int _waitingAckCount = 0;
  int _lastWatingAckId = -1;
   
  void ackReceived(int receiveAckId, int startTime, int currentTime) {
    if (receiveAckId == _lastWatingAckId) {
      _waitingAckCount = 0;
    } else {
      _waitingAckCount --;
    }
    if (responder.storage != null) {
      subsriptions.forEach((String path, RespSubscribeController controller){
        if (controller._storage != null) {
          controller.onAck(receiveAckId);
        }
      });
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
      responder.addProcessor(this);
    }
  }
  
  void _close() {
    subsriptions.forEach((path, controller) {
      controller.destroy();
    });
    subsriptions.clear();
    _waitingAckCount = 0;
    _lastWatingAckId = -1;
    _sendingAfterAck = false;
  }
  void addTraceCallback(ResponseTraceCallback _traceCallback) {
    subsriptions.forEach((path, controller) {
      ResponseTrace update = new ResponseTrace(controller.node.path,'subscribe',0,'+');
      _traceCallback(update);
    });
  }
}

class RespSubscribeController {
  final LocalNode node;
  final SubscribeResponse response;
  RespSubscribeListener _listener;
  int sid;

  bool _permitted = true;
  void set permitted(bool val) {
    if (val == _permitted) return;
    _permitted = val;
    if (_permitted && lastValues.length > 0) {
      response.subscriptionChanged(this);
    }
  }

  List<ValueUpdate> lastValues = new List<ValueUpdate>();
  ValueUpdate lastValue;
  
  ListQueue<ValueUpdate> waitingValues;// = new ListQueue<ValueUpdate>();
    
  int _qosLevel = -1;
  ISubscriptionStorage _storage;
  
  void set qosLevel(int v) {
    if (v < 0 || v > 3) v = 0;
    if (_qosLevel == v) 
      return;
    
    _qosLevel = v;
    
    persist = (v&2) == 2;
    caching = (v&1) == 1;
  }
  
  bool _caching = false;
  void set caching(bool val) {
    if (val == _caching) return;
    _caching = val;
    if (!_caching) {
      lastValues.clear();
    }
  }
  bool _persist = false;
  void set persist(bool val) {
    if (val == _persist) return;
    _persist = val;
    ISubscriptionStorageManager storageM = response.responder.storage;
    if (storageM != null) {
      if (_persist) {
        _storage = storageM.getOrCreateStorage(node.path);
        if (waitingValues == null) {
          waitingValues = new ListQueue<ValueUpdate>();
        }
      } else if (_storage != null){
        storageM.destroyStorage(node.path);
      }
    }
  }

  RespSubscribeController(
      this.response, this.node, this.sid, this._permitted, int qos) {
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
        lastValue = new ValueUpdate(null,ts:'');
        for (ValueUpdate update in lastValues) {
          lastValue.mergeAdd(update);
        }
        lastValues.clear();
      } else {
        lastValue = val;
      }
    } else {
      if (lastValue != null) {
        lastValue =  new ValueUpdate.merge(lastValue, val);
      } else {
        lastValue = val;
      }
    }
    // TODO, don't allow this to be called from same controller more oftern than 100ms
    // the first response can happen ASAP, but
    if (_permitted) {
      response.subscriptionChanged(this);
    }
  }

  List process(int waitingAckId) {
    List rslts = [];
    if (_caching && _isCacheValid) {
      for (ValueUpdate lastValue in lastValues) {
        rslts.add([sid, lastValue.value, lastValue.ts]);
      }
      if (_storage != null) {
        for (ValueUpdate update in lastValues) {
          update.waitingAck = waitingAckId;
          _storage.addValue(update);
        }
        waitingValues.addAll(lastValues);
      }
      lastValues.clear();
    } else {
      if (lastValue.count > 1 || lastValue.status != null) {
        Map m = {'ts': lastValue.ts, 'value': lastValue.value, 'sid': sid};
        if (lastValue.count == 0) {} else if (lastValue.count > 1) {
          m['count'] = lastValue.count;
          if (lastValue.sum.isFinite) {
            m['sum'] = lastValue.sum;
          }
          if (lastValue.max.isFinite) {
            m['max'] = lastValue.max;
          }
          if (lastValue.min.isFinite) {
            m['min'] = lastValue.min;
          }
        }
        rslts.add(m);
      } else {
        rslts.add([sid, lastValue.value, lastValue.ts]);
      }
      if (_storage != null) {
        lastValue.waitingAck = waitingAckId;
        _storage.addValue(lastValue);
        waitingValues.add(lastValue);
      }
      lastValue = null;
      _isCacheValid = true;
    }
    return rslts;
  }
  void onAck(int ackId) {
    while (!waitingValues.isEmpty && waitingValues.first.waitingAck == ackId) {
      // TODO is there any need to add protection in case ackId is out of sync?
      // because one stuck data will cause the queue to overflow
      _storage.removeValue(waitingValues.removeFirst());
    }
  }
  void destroy() {
    _listener.cancel();
  }
}
