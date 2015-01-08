part of dslink.requester;

class DsRequester {
  final DsConnection conn;
  final Map<int, DsRequest> _requests = new Map<int, DsRequest>();
  /// caching of nodes
  final DsReqNodeCache _nodeCache = new DsReqNodeCache();
  DsSubscribeRequest _subsciption;

  DsRequester(this.conn) {
    conn.onReceive.listen(_onData);
    _subsciption = new DsSubscribeRequest(this, 0);
    _requests[0] = _subsciption;
  }

  void _onData(Map m) {
    if (m['rid'] is int && _requests.containsKey(m['rid'])) {
      _requests[m['rid']]._update(m);
    }
  }
  int nextRid = 1;
  DsRequest _sendRequest(Map m, _DsRequestUpdater updater) {
    m['rid'] = nextRid;
    DsRequest req;
    if (updater != null) {
      req = new DsRequest(this, nextRid, updater);
      _requests[nextRid] = req;
    }
    conn.send(m);
    ++nextRid;
    return req;
  }

  Stream<DsReqSubscribeUpdate> subscribe(String path) {
    return null;
  }

  Stream<DsReqListUpdate> list(String path) {
    DsReqNode node = _nodeCache.getNode(path, this);
    return node._list();
  }
// TODO: implement these Request classes
//  DsInvokeRequest invoke(String path) {
//    DsInvokeRequest req = new DsInvokeRequest();
//  }
//
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
  void closeRequest(DsRequest request) {
    if (_requests.containsKey(request.rid)) {
      conn.send({
        'method': 'close',
        'rid': request.rid
      });
      _requests.remove(request.rid);
      request._close();
    }
  }
}
