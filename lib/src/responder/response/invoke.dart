part of dslink.responder;

typedef void OnInvokeClosed(InvokeResponse);

class InvokeResponse extends Response {
  final LocalNode node;
  InvokeResponse(Responder responder, int rid, this.node)
      : super(responder, rid);

  int _pendingInitializeLength = 0;
  List _columns;
  List _updates;
  String _sendingStreamStatus = StreamStatus.initialize;
  void updateStream(List updates, {List columns, String streamStatus: StreamStatus.open}) {
    if (columns != null) {
      _columns = columns;
    }

    if (_updates == null) {
      _updates = updates;
    } else {
      _updates.addAll(updates);
    }

    if (_sendingStreamStatus == StreamStatus.initialize) {
      // in case stream can't return all restult all at once, count the length of initilize
      _pendingInitializeLength += updates.length;
    }

    _sendingStreamStatus = streamStatus;
    responder.addProcessor(processor);
  }

  void processor() {
    if (_err != null) {
      responder._closeResponse(rid, response: this, error: _err);
      if (_sentStreamStatus == StreamStatus.closed) {
        _close();
      }
      return;
    }

    if (_columns != null) {
      _columns = TableColumn.serializeColumns(_columns);
    }
    responder.updateResponse(this, _updates,
        streamStatus: _sendingStreamStatus, columns: _columns);
    _columns = null;
    _updates = null;
    if (_sentStreamStatus == StreamStatus.closed) {
      _close();
    }
  }

  /// close the request from responder side and also notify the requester
  void close([DSError err = null]) {
    if (err != null) {
      _err = err;
    }
    _sendingStreamStatus = StreamStatus.closed;
    responder.addProcessor(processor);
  }

  DSError _err;

  OnInvokeClosed onClose;
  void _close() {
    if (onClose != null) {
      onClose(this);
    }
  }
}
