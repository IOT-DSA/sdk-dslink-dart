part of dslink.responder;

class DsResponse {
  final DsResponder responder;
  final int rid;
  String streamStatus;
  DsResponse(this.responder, this.rid);

  /// close the request from responder side and also notify the requester
  void close([DsError err = null]) {
    streamStatus = DsStreamStatus.closed;
    responder._closeResponse(rid, err);
  }
  /// close the response now, no need to send more response update
  void _close() {
    
  }
}
