part of dslink.common;

class DsTableColumn {
  static List<DsTableColumn> parseColumns(List list) {
    List<DsTableColumn> rslt = new List<DsTableColumn>();
    for (Object m in list) {
      if (m is Map && m['name'] is String && m['type'] is String) {
        rslt.add(new DsTableColumn(m['name'], m['type'], m['default']));
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
  DsTableColumn(this.name, this.type, [this.defaultValue]);
}

class DsTable {
  List<DsTableColumn> columns;
  List<List> rows;
}
