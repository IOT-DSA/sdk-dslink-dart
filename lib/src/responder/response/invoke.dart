part of dslink.responder;

typedef void OnInvokeClosed(InvokeResponse response);

class InvokeResponse extends Response {
  final LocalNode node;
  InvokeResponse(Responder responder, int rid, this.node)
      : super(responder, rid);

  int _pendingInitializeLength = 0;
  List _columns;
  List _updates;
  String _sendingStreamStatus = StreamStatus.initialize;
  Map _meta;
  void updateStream(List updates,
      {List columns, String streamStatus: StreamStatus.open, Map meta}) {
    if (columns != null) {
      _columns = columns;
    }
    _meta = meta;
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
    prepareSendingData();
  }

  @override
  void startSendingData() {
    _pendingSendingData = false;
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
        streamStatus: _sendingStreamStatus, columns: _columns, meta:_meta);
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
    prepareSendingData();
  }

  DSError _err;

  OnInvokeClosed onClose;
  void _close() {
    if (onClose != null) {
      onClose(this);
    }
  }
}
