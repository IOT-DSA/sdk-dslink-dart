part of dslink.responder;

class DsResponse {
  final DsResponder responder;
  final int rid;
  String _streamStatus = DsStreamStatus.initialize;
  DsResponse(this.responder, this.rid);

  /// close the request from responder side and also notify the requester
  void close([DsError err = null]) {
    _streamStatus = DsStreamStatus.closed;
    responder._closeResponse(rid, error: err, response: this);
  }

  /// close the response now, no need to send more response update
  void _close() {

  }
}
