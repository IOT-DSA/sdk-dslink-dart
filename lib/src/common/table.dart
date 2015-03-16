part of dslink.common;

class TableColumn {
  String type;
  String name;
  Object defaultValue;

  TableColumn(this.name, this.type, [this.defaultValue]);

  /// convert tableColumns into List of Map
  static List serializeColumns(List list) {
    List rslts = [];
    for (Object m in list) {
      if (m is Map) {
        rslts.add(m);
      } else if (m is TableColumn) {
        Map rslt = {'type': m.type, 'name': m.name};
        if (m.defaultValue != null) {
          rslt['default'] = m.defaultValue;
        }
        rslts.add(rslt);
      }
    }
    return rslts;
  }
  /// parse List of Map into TableColumn
  static List<TableColumn> parseColumns(List list) {
    List<TableColumn> rslt = <TableColumn>[];
    for (Object m in list) {
      if (m is Map && m['name'] is String && m['type'] is String) {
        rslt.add(new TableColumn(m['name'], m['type'], m['default']));
      } else if (m is TableColumn) {
        rslt.add(m);
      } else {
        // invalid column data
        return null;
      }
    }
    return rslt;
  }
}

class Table {
  List<TableColumn> columns;
  List<List> rows;
}
