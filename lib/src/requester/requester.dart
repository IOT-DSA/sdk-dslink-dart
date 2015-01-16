part of dslink.requester;

class DsRequester extends ConnectionHandler {

  final Map<int, Request> _requests = new Map<int, Request>();
  /// caching of nodes
  final RequesterNodeCache _nodeCache = new RequesterNodeCache();
  SubscribeRequest _subsciption;

  DsRequester() {
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

  Stream<RequesterSubscribeUpdate> subscribe(String path) {
    return null;
  }

  Stream<RequesterListUpdate> list(String path) {
    RequesterNode node = _nodeCache.getNode(path, this);
    return node._list();
  }

  Stream<RequesterInvokeUpdate> invoke(String path, Map params) {
    RequesterNode node = _nodeCache.getNode(path, this);
    return node._invoke(params);
  }

// TODO: implement these Request classes
//  DsSetRequest set(String path, Object value) {
//    DsSetRequest req = new DsSetRequest();
//  }
//
//  DsRemoveRequest remove(String path) {
//    DsRemoveRequest req = new DsRemoveRequest();
//  }
//
//  DsListRequest list(String path) {
//    DsListRequest req = new DsListRequest();
//  }

  /// close the request from requester side and notify responder
  void closeRequest(Request request) {
    if (_requests.containsKey(request.rid)) {
      if (request.streamStatus != StreamStatus.closed) {
        addToSendList({
          'method': 'close',
          'rid': request.rid
        });
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
