part of dslink.requester;

class DsReqInvokeUpdate {
  List<DsTableColumn> columns;
  List<List> rows;
  DsReqInvokeUpdate(this.rows, this.columns);
}

class DsInvokeController {
  static List<DsTableColumn> getNodeColumns(DsReqNode node) {
    Object columns = node.getConfig(r'$columns');
    if (columns is! List && node.profile != null) {
      columns = node.profile.getConfig(r'$columns');
    }
    if (columns is List) {
      return DsTableColumn.parseColumns(columns);
    }
    return null;
  }

  final DsReqNode node;
  StreamController<DsReqInvokeUpdate> _controller;
  Stream<DsReqInvokeUpdate> _stream;
  DsRequest _request;
  List<DsTableColumn> _cachedColumns;
  DsInvokeController(this.node, Map params) {
    _controller = new StreamController<DsReqInvokeUpdate>();
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
  void _onNodeUpdate(DsReqListUpdate listUpdate) {
    //TODO, close the stream when configs are loaded
  }

  void _onUpdate(String status, List updates, List columns) {
    if (columns != null) {
      _cachedColumns = DsTableColumn.parseColumns(columns);
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
          for (DsTableColumn column in _cachedColumns) {
            if (obj.containsKey(column.name)) {
              row.add(obj[column.name]);
            } else {
              row.add(column.defaultValue);
            }
          }
        }
        rows.add(row);
      }
      _controller.add(new DsReqInvokeUpdate(rows, _cachedColumns));
    }
    if (status == DsStreamStatus.closed) {
      _controller.close();
    }
  }
}
