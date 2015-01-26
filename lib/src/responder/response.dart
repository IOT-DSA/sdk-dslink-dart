part of dslink.responder;

class Response {
  final Responder responder;
  final int rid;
  String _streamStatus = StreamStatus.initialize;
  Response(this.responder, this.rid);

  /// close the request from responder side and also notify the requester
  void close([DSError err = null]) {
    _streamStatus = StreamStatus.closed;
    responder._closeResponse(rid, error: err, response: this);
  }

  /// close the response now, no need to send more response update
  void _close() {}
}
