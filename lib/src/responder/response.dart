part of dslink.responder;

class DsResponse {
  final DsResponder responder;
  final int rid;
  String streamStatus;
  DsResponse(this.responder, this.rid);
  
  /// close the response now, no need to send more response update
  void _close() {
    
  }
}