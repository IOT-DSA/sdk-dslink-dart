part of dslink.requester;

/// base request class
abstract class DsRequest{
  final DsRequester requester;
  final int rid;
  
  bool _isClosed = false;
  bool get isClosed => _isClosed;
  
  Stream get onResponse;
  
  DsRequest(this.requester, this.rid);
  
  void _update(Map m);
  
  void _close();
  
  void close() {
    // let requester call _close();
    requester.close(this);
  }
}