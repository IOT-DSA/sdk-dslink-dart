part of dslink.requester;

class RequesterInvokeUpdate extends RequesterUpdate {
  List<TableColumn> columns;
  List<List> updates;
  RequesterInvokeUpdate(this.updates, this.columns, String streamStatus) : super(streamStatus);
}

class InvokeController implements RequestUpdater{
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
  StreamController<RequesterInvokeUpdate> _controller;
  Stream<RequesterInvokeUpdate> _stream;
  Request _request;
  List<TableColumn> _cachedColumns;
  InvokeController(this.node, Map params) {
    _controller = new StreamController<RequesterInvokeUpdate>();
    _stream = _controller.stream;
    Map reqMap = {'method': 'invoke', 'path': node.remotePath, 'params': params};
// TODO update node before invoke to load columns
//    if(!node.isUpdated()) {
//      node._list().listen(_onNodeUpdate)
//    } else {
    _cachedColumns = getNodeColumns(node);
    _request = node.requester._sendRequest(reqMap, this);
//    }
  }
  void _onNodeUpdate(RequesterListUpdate listUpdate) {
    //TODO, close the stream when configs are loaded
  }

  void onUpdate(String streamStatus, List updates, List columns) {
    if (columns != null) {
      _cachedColumns = TableColumn.parseColumns(columns);
    }
    if (_cachedColumns == null) {
      _controller.close();
      _request.close();
      return;
    }
    List<List> rows = [];
    if (updates != null) {
      for (Object obj in updates) {
        List row;
        if (obj is List) {
          if (obj.length < _cachedColumns.length) {
            row = obj.toList();
            for (int i = obj.length; i < _cachedColumns.length; ++i) {
              row.add(_cachedColumns[i].defaultValue);
            }
          } else if (obj.length > _cachedColumns.length) {
            row = obj.sublist(0, _cachedColumns.length);
          } else {
            row = obj;
          }
        } else if (obj is Map) {
          row = [];
          for (TableColumn column in _cachedColumns) {
            if (obj.containsKey(column.name)) {
              row.add(obj[column.name]);
            } else {
              row.add(column.defaultValue);
            }
          }
        }
        rows.add(row);
      }
      _controller.add(new RequesterInvokeUpdate(rows, _cachedColumns, streamStatus));
    }
    if (streamStatus == StreamStatus.closed) {
      _controller.close();
    }
  }
}
