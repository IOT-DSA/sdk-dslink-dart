part of dslink.responder;

class Response implements ConnectionProcessor{
  final Responder responder;
  final int rid;
  String _sentStreamStatus = StreamStatus.initialize;
  Response(this.responder, this.rid);

  /// close the request from responder side and also notify the requester
  void close([DSError err = null]) {
    _sentStreamStatus = StreamStatus.closed;
    responder._closeResponse(rid, error: err, response: this);
  }

  /// close the response now, no need to send more response update
  void _close() {}
  
  
  void prepareSendingData() {
    if (!_pendingSendingData) {
      _pendingSendingData = true;
      responder.addProcessor(this);
    }
  }
  bool _pendingSendingData = false;
  void startSendingData() {
    _pendingSendingData = false;
  }
  
  void ackWaiting(int ackId) {
    // TODO: implement ackSent
  }
  void ackReceived(int ackId) {
    // TODO: implement ackReceived
  }
}
