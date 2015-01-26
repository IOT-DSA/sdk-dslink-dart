part of dslink.responder;

class InvokeResponse extends Response {
  final LocalNode node;
  InvokeResponse(Responder responder, int rid, this.node)
      : super(responder, rid);

  int _pendingInitializeLength = 0;
  List _columns;
  List _updates;
  String _streamStatus = StreamStatus.initialize;
  void updateStream(List udpates,
      {List columns, String streamStatus: StreamStatus.open}) {
    if (columns != null) {
      _columns = columns;
    }
    if (_updates == null) {
      _updates = udpates;
    } else {
      _updates.addAll(udpates);
    }
    if (_streamStatus == StreamStatus.initialize) {
      // in case stream can't return all restult all at once, count the length of initilize
      _pendingInitializeLength += udpates.length;
    }
    _streamStatus = streamStatus;
    responder.addProcessor(processor);
  }
  void processor() {
    if (_columns != null) {
      _columns = TableColumn.serializeColumns(_columns);
    }
    responder.updateReponse(this, _updates,
        streamStatus: _streamStatus, columns: _columns);
    _columns = null;
    _updates = null;
  }
  void _close() {}
}
