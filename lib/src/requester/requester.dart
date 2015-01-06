part of dslink.requester;

class DsRequester {
  final DsConnection conn;
  final Map<int, DsRequest> _requests = new Map<int, DsRequest>();
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
  
  void subscribe(String path, DsValueUpdater updater) {
    // TODO(rinick): implement it
  }
  
  void unsubscribe(String path, DsValueUpdater updater) {
    // TODO(rinick): implement it
  }
  
//  DsListRequest list(String path) {
//    DsListRequest req = new DsListRequest();
//  }
//
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
      _requests.remove(request.rid);
      request._close();
    }
  }
}
