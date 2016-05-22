part of dslink.responder;

typedef void OnInvokeClosed(InvokeResponse response);
typedef void OnInvokeSend(InvokeResponse response, Map m);

/// return true if params are valid
typedef bool OnReqParams(InvokeResponse resp, Map m);

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
      : super(DSPacketMethod.invoke, responder, rid);

  List<_InvokeResponseUpdate> pendingData = new List<_InvokeResponseUpdate>();

  bool _hasSentColumns = false;

  /// update data for the responder stream
  void updateStream(List updates,
      {List columns, String streamStatus: StreamStatus.open,
        Map meta, bool autoSendColumns: true}) {
    if (meta != null && meta['mode'] == 'refresh') {
      pendingData.length = 0;
    }

    if (!_hasSentColumns) {
      if (columns == null &&
        autoSendColumns &&
        node != null &&
        node.configs[r"$columns"] is List) {
        columns = node.configs[r"$columns"];
      }
    }

    if (columns != null) {
      _hasSentColumns = true;
    }

    pendingData.add(
      new _InvokeResponseUpdate(streamStatus, updates, columns, meta)
    );
    prepareSending();
  }

  OnReqParams onReqParams;
  /// new parameter from the requester
  void updateReqParams(Map m) {
    if (onReqParams != null) {
      onReqParams(this, m);
    }
  }

  @override
  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;
    if (_err != null) {
      responder.closeResponse(rid, response: this, error: _err);
      if (_sentStreamStatus == StreamStatus.closed) {
        _close();
      }
      return;
    }

    for (_InvokeResponseUpdate update in pendingData) {
      List<Map<String, dynamic>> outColumns;
      if (update.columns != null) {
        outColumns = TableColumn.serializeColumns(update.columns);
      }

      responder.updateResponse(
        this,
        update.updates,
        streamStatus: update.status,
        columns: outColumns,
        meta: update.meta, handleMap: (m) {
        if (onSendUpdate != null) {
          onSendUpdate(this, m);
        }
      });

      if (_sentStreamStatus == StreamStatus.closed) {
        _close();
        break;
      }
    }
    pendingData.length = 0;
  }

  /// close the request from responder side and also notify the requester
  void close([DSError err = null]) {
    if (err != null) {
      _err = err;
    }
    if (!pendingData.isEmpty) {
      pendingData.last.status = StreamStatus.closed;
    } else {
      pendingData.add(
        new _InvokeResponseUpdate(StreamStatus.closed, null, null, null)
      );
      prepareSending();
    }
  }

  DSError _err;

  OnInvokeClosed onClose;
  OnInvokeSend onSendUpdate;

  void _close() {
    if (onClose != null) {
      onClose(this);
    }
  }

  /// for the broker trace action
  ResponseTrace getTraceData([String change = '+']) {
    return new ResponseTrace(parentNode.path, 'invoke', rid, change, name);
  }
}
