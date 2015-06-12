part of dslink.requester;

abstract class RequestUpdater {
  void onUpdate(String status, List updates, List columns, DSError error);
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

  SubscribeRequest _subsciption;

  Requester([RemoteNodeCache cache])
      : nodeCache = cache != null ? cache : new RemoteNodeCache() {
    _subsciption = new SubscribeRequest(this, 0);
    _requests[0] = _subsciption;
  }

  void onData(List list) {
    for (Object resp in list) {
      if (resp is Map) {
        _onReceiveUpdate(resp);
      }
    }
  }

  void _onReceiveUpdate(Map m) {
    if (m['rid'] is int && _requests.containsKey(m['rid'])) {
      _requests[m['rid']]._update(m);
    }
  }

  int nextRid = 1;
  int nextSid = 1;

  // TODO need a new design for short polling and long polling
  int lastSentId = 0;

  List doSend() {
    List rslt = super.doSend();
    lastSentId = nextRid - 1;
    return rslt;
  }

  Request _sendRequest(Map m, RequestUpdater updater) {
    m['rid'] = nextRid;
    Request req;
    if (updater != null) {
      req = new Request(this, nextRid, updater, m);
      _requests[nextRid] = req;
    }
    addToSendList(m);
    ++nextRid;
    return req;
  }

  ReqSubscribeListener subscribe(String path, callback(ValueUpdate), [int cacheLevel = 1]) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    node._subscribe(this, callback, cacheLevel);
    return new ReqSubscribeListener(this, path, callback);
  }

  void unsubscribe(String path, callback(ValueUpdate)) {
     RemoteNode node = nodeCache.getRemoteNode(path);
     node._unsubscribe(this, callback);
   }

  Stream<RequesterListUpdate> list(String path) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    return node._list(this);
  }

  Stream<RequesterInvokeUpdate> invoke(String path, Map params, [int maxPermission = Permission.CONFIG]) {
    RemoteNode node = nodeCache.getRemoteNode(path);
    return node._invoke(params, this, maxPermission);
  }

  Future<RequesterUpdate> set(String path, Object value, [int maxPermission = Permission.CONFIG]) {
    return new SetController(this, path, value, maxPermission).future;
  }

  Future<RequesterUpdate> remove(String path) {
    return new RemoveController(this, path).future;
  }

  /// close the request from requester side and notify responder
  void closeRequest(Request request) {
    if (_requests.containsKey(request.rid)) {
      if (request.streamStatus != StreamStatus.closed) {
        addToSendList({'method': 'close', 'rid': request.rid});
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
    ;
    newRequests[0] = _subsciption;
    _requests.forEach((n, req) {
      if (req.rid <= lastSentId &&
          req.updater is! ListController) {
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
