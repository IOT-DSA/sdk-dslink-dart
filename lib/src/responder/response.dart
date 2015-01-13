part of dslink.responder;

class DsResponse {
  final DsResponder responder;
  final int rid;
  String _streamStatus = DsStreamStatus.initialize;
  DsResponse(this.responder, this.rid);

  /// close the request from responder side and also notify the requester
  void close([DsError err = null]) {
    _streamStatus = DsStreamStatus.closed;
    responder._closeResponse(rid, err);
  }

  void add(List updates, {String streamStatus, List columns}) {
    Map m = {
      'rid': rid
    };
    if (streamStatus != _streamStatus) {
      m['stream'] = streamStatus;
    }
    if (columns != null) {
      m['columns'] = columns;
    }
    if (updates != null) {
      m['updates'] = updates;
    }
    responder.addToSendList(m);
  }
  /// close the response now, no need to send more response update
  void _close() {

  }
}
