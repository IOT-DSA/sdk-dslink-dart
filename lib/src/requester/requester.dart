part of dslink.requester;

class DsRequester {
  final DsConnection conn;
  final Map<int, DsRequest> _requests = new Map<int, DsRequest>();
  /// caching of nodes
  final DsReqNodeManager _nodeManager = new DsReqNodeManager();
  //final DsSubscriptionStream subscriptionStream = new DsSubscriptionStream(this, 0);
  
  DsRequester(this.conn) {
    conn.onReceive.listen(_onData);
    //_requests[0] = subscriptionStream;
  }
  
  void _onData(Map m) {
    if (m['rid'] is int && _requests.containsKey(m['rid'])) {
      _requests[m['rid']]._update(m);
    }
  }
  int nextRid = 1;
  DsRequest _sendRequest(Map m, _DsRequestUpdater updater) {
    m['rid'] = nextRid;
    DsRequest req = new DsRequest(this, nextRid, updater);
    _requests[nextRid] = req;
    conn.send(m);
    ++nextRid;
    return req;
  }
  
  Stream<DsReqSubscribeUpdate> subscribe(String path) {
    return null;
  }
  
  
  Stream<DsReqListUpdate> list(String path) {
    DsReqNode node = _nodeManager.getNode(path, this);
    return node._list();
  }

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
  
  void close(DsRequest request) {
    if (_requests.containsKey(request.rid)) {
      conn.send({'method':'close','rid':request.rid});
      _requests.remove(request.rid);
      request._close();
    }
  }
}
