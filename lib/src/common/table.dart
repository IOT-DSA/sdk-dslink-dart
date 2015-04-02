part of dslink.common;

class TableColumn {
  String type;
  String name;
  Object defaultValue;

  TableColumn(this.name, this.type, [this.defaultValue]);

  Map getData(){
    Map rslt = {'type': type, 'name': name};
    if (defaultValue != null) {
      rslt['default'] = defaultValue;
    }
    return rslt;
  }
  /// convert tableColumns into List of Map
  static List serializeColumns(List list) {
    List rslts = [];
    for (Object m in list) {
      if (m is Map) {
        rslts.add(m);
      } else if (m is TableColumn) {
        rslts.add(m.getData());
      }
    }
    return rslts;
  }
  /// parse List of Map into TableColumn
  static List<TableColumn> parseColumns(List list) {
    List<TableColumn> rslt = <TableColumn>[];
    for (Object m in list) {
      if (m is Map && m['name'] is String) {
        String type = 'string';
        if (m['type'] is String){
          type = m['type'];
        }
        rslt.add(new TableColumn(m['name'], type, m['default']));
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
