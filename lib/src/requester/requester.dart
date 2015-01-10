part of dslink.requester;

class DsRequester {

  final Map<int, DsRequest> _requests = new Map<int, DsRequest>();
  /// caching of nodes
  final DsReqNodeCache _nodeCache = new DsReqNodeCache();
  DsSubscribeRequest _subsciption;

  DsRequester() {
    _subsciption = new DsSubscribeRequest(this, 0);
    _requests[0] = _subsciption;
  }
  DsConnection _conn;
  StreamSubscription _connListener;
  StreamSubscription _beforeSendListener;
  DsConnection get connection => _conn;
  void set connection(DsConnection conn) {
    if (_connListener != null) {
      _connListener.cancel();
      _connListener = null;
      onDisconnected(_conn);
    }
    _conn = conn;
    _connListener = _conn.onReceive.listen(_onData);
    _conn.onDisconnected.then(onDisconnected);
    // resend all requests after a connection
    _resendRequests();
  }
  void onDisconnected(DsConnection conn) {
    if (_conn == conn) {
      if (_connListener != null) {
        _connListener.cancel();
        _connListener = null;
      }
      //TODO clean up
      // send error and close all requests except the subscription and list requests
      _conn = null;
    }
  }
  void _resendRequests() {
    //TODO resend requests for subscription and list
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
    if (_conn != null) {
      _conn.send(m);
    }
    ++nextRid;
    return req;
  }
  /// no data is sent yet, but need to make connection to send a onBeforeSending event
  void _addProcessor(void processor()) {
    if (_conn != null) {
      _conn.addProcessor(processor);
    }
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
      _conn.send({
        'method': 'close',
        'rid': request.rid
      });
      _requests.remove(request.rid);
      request._close();
    }
  }
}
