part of dslink.requester;

class RequesterInvokeUpdate extends RequesterUpdate {
  List rawColumns;
  List<TableColumn> columns;
  List updates;
  DSError error;
  Map meta;

  RequesterInvokeUpdate(
      this.updates, this.rawColumns, this.columns, String streamStatus,
      {this.meta, this.error})
      : super(streamStatus);

  List<List> _rows;
  List<List> get rows {
    int colLen = -1;
    if (columns != null) {
      colLen = columns.length;
    }
    if (_rows == null) {
      _rows = [];
      for (Object obj in updates) {
        List row;
        if (obj is List) {
          if (obj.length < colLen) {
            row = obj.toList();
            for (int i = obj.length; i < colLen; ++i) {
              row.add(columns[i].defaultValue);
            }
          } else if (obj.length > colLen) {
            if (colLen == -1) { // when column is unknown, just return all values
              row = obj.toList();
            } else {
              row = obj.sublist(0, colLen);
            }
          } else {
            row = obj;
          }
        } else if (obj is Map) {
          row = [];
          if (columns != null) {
            for (TableColumn column in columns) {
              if (obj.containsKey(column.name)) {
                row.add(obj[column.name]);
              } else {
                row.add(column.defaultValue);
              }
            }
          }
        }
        _rows.add(row);
      }
    }
    return _rows;
  }
}

class InvokeController implements RequestUpdater {
  static List<TableColumn> getNodeColumns(RemoteNode node) {
    Object columns = node.getConfig(r'$columns');
    if (columns is! List && node.profile != null) {
      columns = node.profile.getConfig(r'$columns');
    }
    if (columns is List) {
      return TableColumn.parseColumns(columns);
    }
    return null;
  }

  final RemoteNode node;
  final Requester requester;
  StreamController<RequesterInvokeUpdate> _controller;
  Stream<RequesterInvokeUpdate> _stream;
  Request _request;
  List<TableColumn> _cachedColumns;

  InvokeController(this.node, this.requester, Map params,
      [int maxPermission = Permission.CONFIG]) {
    _controller = new StreamController<RequesterInvokeUpdate>();
    _controller.done.then(_onUnsubscribe);
    _stream = _controller.stream;
    Map reqMap = {
      'method': 'invoke',
      'path': node.remotePath,
      'params': params
    };
    if (maxPermission != Permission.CONFIG) {
      reqMap['permit'] = Permission.names[maxPermission];
    }
// TODO update node before invoke to load columns
//    if(!node.isUpdated()) {
//      node._list().listen(_onNodeUpdate)
//    } else {
    _cachedColumns = getNodeColumns(node);
    _request = requester._sendRequest(reqMap, this);
//    }
  }

  void _onUnsubscribe(obj) {
    if (_request != null && _request.streamStatus != StreamStatus.closed) {
      _request.close();
    }
  }

  void _onNodeUpdate(RequesterListUpdate listUpdate) {
    //TODO, close the stream when configs are loaded
  }

  void onUpdate(String streamStatus, List updates, List columns, Map meta, DSError error) {
    // TODO implement error
    if (columns != null) {
      _cachedColumns = TableColumn.parseColumns(columns);
    }

//    if (_cachedColumns == null) {
//      _cachedColumns = [];
//    }
    if (error != null) {
      streamStatus = StreamStatus.closed;
      _controller.add(
          new RequesterInvokeUpdate(null, null, null, streamStatus, error:error, meta:meta));
    } else if (updates != null) {
      _controller.add(new RequesterInvokeUpdate(
          updates, columns, _cachedColumns, streamStatus, meta:meta));
    }

    if (streamStatus == StreamStatus.closed) {
      _controller.close();
    }
  }

  void onDisconnect() {}
  void onReconnect() {}
}
