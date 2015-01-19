part of dslink.common;

class TableColumn {
  static List<TableColumn> parseColumns(List list) {
    List<TableColumn> rslt = <TableColumn>[];
    for (Object m in list) {
      if (m is Map && m['name'] is String && m['type'] is String) {
        rslt.add(new TableColumn(m['name'], m['type'], m['default']));
      } else {
        // invalid column data
        return null;
      }
    }
    return rslt;
  }
  String type;
  String name;
  Object defaultValue;
  TableColumn(this.name, this.type, [this.defaultValue]);
}

class Table {
  List<TableColumn> columns;
  List<List> rows;
}
