part of dslink.requester;

typedef T RequestConsumer<T>(Request request);

abstract class RequestUpdater {
  void onUpdate(String status, List updates, List columns, Map meta, DSError error);
  void onDisconnect();
  void onReconnect();
}

class RequesterUpdate {
  final String streamStatus;

  RequesterUpdate(this.streamStatus);
}

class Requester extends ConnectionHandler {
  Map<int, Request> _requests = new Map<int, Request>();

  /// caching of nodes
  final RemoteNodeCache nodeCache;

  Requester([RemoteNodeCache cache])
      : nodeCache = cache != null ? cache : new RemoteNodeCache();

  int get subscriptionCount => _requests.values
    .where((x) => x is SubscribeRequest)
    .length;

  int get openRequestCount {
    return _requests.length;
  }

  void onData(DSPacket pkt) {
    if (pkt is DSResponsePacket) {
      _onReceiveUpdate(pkt);
    }
  }

  void _onReceiveUpdate(DSResponsePacket pkt) {
    if (pkt.rid is int && _requests.containsKey(pkt.rid)) {
      _requests[pkt.rid].onNewPacket(pkt);
    }
  }

  StreamController<DSError> _errorController =
    new StreamController<DSError>.broadcast();

  Stream<DSError> get onError => _errorController.stream;

  int lastRid = 0;
  int getNextRid() {
    do {
      if (lastRid < 0x7FFFFFFF) {
        ++lastRid;
      } else {
        lastRid = 1;
      }
    } while (_requests.containsKey(lastRid));
    return lastRid;
  }

  ProcessorResult getSendingData(int currentTime, int waitingAckId) {
    ProcessorResult rslt = super.getSendingData(currentTime, waitingAckId);
    return rslt;
  }

  Request sendRequest(DSRequestPacket pkt, RequestUpdater updater) =>
    _sendRequest(pkt, updater);

  Request _sendRequest(DSRequestPacket pkt, RequestUpdater updater, [Request r]) {
    pkt.rid = r != null ? r.rid : getNextRid();

    Request req;
    if (updater != null) {
      req = r != null ? r : new Request(this, pkt.rid, updater, pkt);
      _requests[pkt.rid] = req;
    }
    addToSendList(pkt);
    return req;
  }

  bool isNodeCached(String path) {
    return nodeCache.isNodeCached(path);
  }

  ReqSubscribeListener subscribe(String path, callback(ValueUpdate update),
      [int qos = 0]) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    node._subscribe(this, callback, qos);
    return new ReqSubscribeListener(this, path, callback);
  }

  Stream<ValueUpdate> onValueChange(String path, [int qos = 0]) {
    ReqSubscribeListener listener;
    StreamController<ValueUpdate> controller;
    int subs = 0;
    controller = new StreamController<ValueUpdate>.broadcast(onListen: () {
      subs++;
      if (listener == null) {
        listener = subscribe(path, (ValueUpdate update) {
          controller.add(update);
        }, qos);
      }
    }, onCancel: () {
      subs--;
      if (subs == 0) {
        listener.cancel();
        listener = null;
      }
    });
    return controller.stream;
  }

  Future<ValueUpdate> getNodeValue(String path) {
    var c = new Completer<ValueUpdate>();
    ReqSubscribeListener listener;
    listener = subscribe(path, (ValueUpdate update) {
      if (!c.isCompleted) {
        c.complete(update);
      }

      if (listener != null) {
        listener.cancel();
        listener = null;
      }
    });
    return c.future;
  }

  Future<RemoteNode> getRemoteNode(String path) {
    var c = new Completer<RemoteNode>();
    StreamSubscription sub;
    sub = list(path).listen((update) {
      if (!c.isCompleted) {
        c.complete(update.node);
      }

      if (sub != null) {
        sub.cancel();
      }
    }, onError: (e, stack) {
      if (!c.isCompleted) {
        c.completeError(e, stack);
      }
    }, cancelOnError: true);
    return c.future;
  }

  Stream<RequesterListUpdate> list(String path) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    return node._list(this);
  }

  Stream<RequesterInvokeUpdate> invoke(String path, [Map params = const {},
      int maxPermission = Permission.CONFIG, RequestConsumer fetchRawReq]) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    return node._invoke(params, this, maxPermission, fetchRawReq);
  }

  Future<RequesterUpdate> set(String path, Object value,
      [int maxPermission = Permission.CONFIG]) {
    return new SetController(this, path, value, maxPermission).future;
  }

  Future<RequesterUpdate> remove(String path) {
    return new RemoveController(this, path).future;
  }

  /// close the request from requester side and notify responder
  void closeRequest(Request request) {
    if (_requests.containsKey(request.rid)) {
      if (request.streamStatus != StreamStatus.closed) {
        var pkt = new DSRequestPacket();
        pkt.method = DSPacketMethod.close;
        pkt.rid = request.rid;
        addToSendList(pkt);
      }
      _requests.remove(request.rid);
      request._close();
    }
  }

  bool _connected = false;

  void onDisconnected() {
    if (!_connected) return;
    _connected = false;

    var newRequests = new Map<int, Request>();
    _requests.forEach((n, req) {
      if (req.rid <= lastRid && req.updater is! ListController) {
        req._close(DSError.DISCONNECTED);
      } else {
        newRequests[req.rid] = req;
        req.updater.onDisconnect();
      }
    });
    _requests = newRequests;
  }

  void onReconnected() {
    if (_connected) return;
    _connected = true;

    super.onReconnected();

    _requests.forEach((n, req) {
      req.updater.onReconnect();
      req.resend();
    });
  }
}
