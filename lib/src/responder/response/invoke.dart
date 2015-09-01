part of dslink.responder;

typedef void OnInvokeClosed(InvokeResponse response);

class _InvokeResponseUpdate {
  String status;
  List columns;
  List updates;
  Map meta;
  _InvokeResponseUpdate(this.status, this.updates, this.columns, this.meta);
}

class InvokeResponse extends Response {
  final LocalNode parentNode;
  final LocalNode node;
  final String name;
  InvokeResponse(Responder responder, int rid, this.parentNode, this.node, this.name)
      : super(responder, rid);

  List<_InvokeResponseUpdate> pendingData = new List<_InvokeResponseUpdate>();
  void updateStream(List updates,
      {List columns, String streamStatus: StreamStatus.open, Map meta}) {
    if (meta != null && meta['mode'] == 'refresh') {
      pendingData.clear();
    }
    pendingData.add(new _InvokeResponseUpdate(streamStatus, updates, columns, meta));
    prepareSending();
  }

  @override
  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;
    if (_err != null) {
      responder._closeResponse(rid, response: this, error: _err);
      if (_sentStreamStatus == StreamStatus.closed) {
        _close();
      }
      return;
    }
    
    for (_InvokeResponseUpdate update in pendingData) {
      List outColumns;
      if (update.columns != null) {
        outColumns = TableColumn.serializeColumns(update.columns);
      }
      responder.updateResponse(this, update.updates,
          streamStatus: update.status, columns: outColumns, meta:update.meta);
      if (_sentStreamStatus == StreamStatus.closed) {
        _close();
        break;
      }
    }
    pendingData.clear();
  }

  /// close the request from responder side and also notify the requester
  void close([DSError err = null]) {
    if (err != null) {
      _err = err;
    }
    if (pendingData != null) {
      pendingData.last.status = StreamStatus.closed;
    } else {
      pendingData.add(new _InvokeResponseUpdate(StreamStatus.closed, null, null, null));
      prepareSending();
    }
  }

  DSError _err;

  bool _closed = false;
  OnInvokeClosed onClose;
  void _close() {
    _closed = true;
    if (onClose != null) {
      onClose(this);
    }
  }
  
  /// for the broker trace action
  ResponseTrace getTraceData([String change = '+']) {
    return new ResponseTrace(parentNode.path, 'invoke', rid, change, name);
  }
}
