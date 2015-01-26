part of dslink.requester;

class RequesterUpdate {
  final String streamStatus;
  RequesterUpdate(this.streamStatus);
}

class Requester extends ConnectionHandler {
  final Map<int, Request> _requests = new Map<int, Request>();
  /// caching of nodes
  final RemoteNodeCache _nodeCache;
  SubscribeRequest _subsciption;

  Requester([RemoteNodeCache nodeCache])
      : _nodeCache = nodeCache != null ? nodeCache : new RemoteNodeCache() {
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
  Request _sendRequest(Map m, _RequestUpdater updater) {
    m['rid'] = nextRid;
    Request req;
    if (updater != null) {
      req = new Request(this, nextRid, updater);
      _requests[nextRid] = req;
    }
    addToSendList(m);
    ++nextRid;
    return req;
  }

  Stream<ValueUpdate> subscribe(String path) {
    RemoteNode node = _nodeCache.getRemoteNode(path, this);
    return node._subscribe();
  }

  Stream<RequesterListUpdate> list(String path) {
    RemoteNode node = _nodeCache.getRemoteNode(path, this);
    return node._list();
  }

  Stream<RequesterInvokeUpdate> invoke(String path, Map params) {
    RemoteNode node = _nodeCache.getRemoteNode(path, this);
    return node._invoke(params);
  }

  Future<RequesterUpdate> set(String path, Object value) {
    return new SetController(this, path, value).future;
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

  void onDisconnected() {
    // TODO: close pending requests, except subscription and list
  }

  void onReconnected() {
    // TODO: resend subscription and list
  }
}
