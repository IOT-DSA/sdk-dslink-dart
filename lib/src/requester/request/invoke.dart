part of dslink.requester;

class RequesterInvokeUpdate {
  List<TableColumn> columns;
  List<List> rows;
  RequesterInvokeUpdate(this.rows, this.columns);
}

class InvokeController {
  static List<TableColumn> getNodeColumns(RequesterNode node) {
    Object columns = node.getConfig(r'$columns');
    if (columns is! List && node.profile != null) {
      columns = node.profile.getConfig(r'$columns');
    }
    if (columns is List) {
      return TableColumn.parseColumns(columns);
    }
    return null;
  }

  final RequesterNode node;
  StreamController<RequesterInvokeUpdate> _controller;
  Stream<RequesterInvokeUpdate> _stream;
  Request _request;
  List<TableColumn> _cachedColumns;
  InvokeController(this.node, Map params) {
    _controller = new StreamController<RequesterInvokeUpdate>();
    _stream = _controller.stream;
    Map reqMap = {
      'method': 'invoke',
      'path': node.path,
      'params': params
    };
// TODO update node before invoke to load columns
//    if(!node.isUpdated()) {
//      node._list().listen(_onNodeUpdate)
//    } else {
    _cachedColumns = getNodeColumns(node);
    _request = node.requester._sendRequest(reqMap, _onUpdate);
//    }
  }
  void _onNodeUpdate(RequesterListUpdate listUpdate) {
    //TODO, close the stream when configs are loaded
  }

  void _onUpdate(String status, List updates, List columns) {
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
      _controller.add(new RequesterInvokeUpdate(rows, _cachedColumns));
    }
    if (status == StreamStatus.closed) {
      _controller.close();
    }
  }
}
