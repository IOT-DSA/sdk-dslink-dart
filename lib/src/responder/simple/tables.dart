part of dslink.responder;

/// A simple table result.
/// This is used to return simple tables from an action.
class SimpleTableResult {
  /// Table Columns
  List columns;

  /// Table Rows
  List rows;

  SimpleTableResult([this.rows, this.columns]);
}

/// An Asynchronous Table Result
/// This can be used to return asynchronous tables from actions.
class AsyncTableResult {
  /// Invoke Response.
  InvokeResponse response;
  /// Table Columns
  List columns;
  /// Table Rows
  List rows;
  /// Stream Status
  String status = StreamStatus.open;
  /// Table Metadata
  Map meta;
  /// Handler for when this is closed.
  OnInvokeClosed onClose;

  AsyncTableResult([this.columns]);

  /// Updates table rows to [rows].
  /// [stat] is the stream status.
  /// [meta] is the action result metadata.
  void update(List rows, [String stat, Map meta]) {
    if (this.rows == null) {
      this.rows = rows;
    } else {
      this.rows.addAll(rows);
    }
    this.meta = meta;
    if (stat != null) {
      status = stat;
    }

    if (response == null) {
      new Future(write);
    } else {
      write();
    }
  }

  /// Write this result to the result given by [resp].
  void write([InvokeResponse resp]) {
    if (resp != null) {
      if (response == null) {
        response = resp;
      } else {
        logger.warning("can not use same AsyncTableResult twice");
      }
    }

    if (response != null && (rows != null || meta != null || status == StreamStatus.closed)) {
      response.updateStream(rows, columns: columns, streamStatus: status, meta: meta);
      rows = null;
      columns = null;
    }
  }

  /// Closes this response.
  void close() {
    if (response != null) {
      response.close();
    } else {
      status = StreamStatus.closed;
    }
  }
}

/// A Live-Updating Table
class LiveTable {
  final List<TableColumn> columns;
  final List<LiveTableRow> rows;

  LiveTable.create(this.columns, this.rows);

  factory LiveTable([List<TableColumn> columns]) {
    return new LiveTable.create(columns == null ? [] : columns, []);
  }

  void onRowUpdate(LiveTableRow row) {
    if (_resp != null) {
      _resp.updateStream([row.values], meta: {
        "modify": "replace ${row.index}-${row.index}"
      });
    }
  }

  void doOnClose(Function f) {
    _onClose.add(f);
  }

  List<Function> _onClose = [];

  LiveTableRow createRow(List<dynamic> values, {bool ready: true}) {
    if (values == null) values = [];
    var row = new LiveTableRow(this, values);
    row.index = rows.length;
    rows.add(row);
    if (ready && _resp != null) {
      _resp.updateStream([row.values], meta: {
        "mode": "append"
      });
    }
    return row;
  }

  void clear() {
    rows.length = 0;
    if (_resp != null) {
      _resp.updateStream([], meta: {
        "mode": "refresh"
      }, columns: []);
    }
  }

  void refresh([int idx = -1]) {
    if (_resp != null) {
      _resp.updateStream(getCurrentState(), columns: columns.map((x) {
        return x.getData();
      }).toList(), streamStatus: StreamStatus.open, meta: {
        "mode": "refresh"
      });
    }
  }

  void reindex() {
    var i = 0;
    for (LiveTableRow row in rows) {
      row.index = i;
      i++;
    }
  }

  void override() {
    refresh();
  }

  void resend() {
    sendTo(_resp);
  }

  void sendTo(InvokeResponse resp) {
    _resp = resp;

    _resp.onClose = (r) {
      close(true);
    };

    if (autoStartSend) {
      resp.updateStream(getCurrentState(), columns: columns.map((x) {
        return x.getData();
      }).toList(), streamStatus: StreamStatus.open, meta: {
        "mode": "refresh"
      });
    }
  }

  void close([bool isFromRequester = false]) {
    while (_onClose.isNotEmpty) {
      _onClose.removeAt(0)();
    }

    if (!isFromRequester) {
      _resp.close();
    }
  }

  List getCurrentState([int from = -1]) {
    List<LiveTableRow> rw = rows;
    if (from != -1) {
      rw = rw.sublist(from);
    }
    return rw.map((x) => x.values).toList();
  }

  InvokeResponse get response => _resp;
  InvokeResponse _resp;

  bool autoStartSend = true;
}

class LiveTableRow {
  final LiveTable table;
  final List<dynamic> values;

  int index = -1;

  LiveTableRow(this.table, this.values);

  void setValue(int idx, value) {
    if (idx > values.length - 1) {
      values.length += 1;
    }
    values[idx] = value;
    table.onRowUpdate(this);
  }

  void delete() {
    table.rows.remove(this);
    var idx = index;
    table.refresh(idx);
    table.reindex();
  }
}
