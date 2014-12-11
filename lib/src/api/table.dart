part of dslink.api;

abstract class Table {
  int get columnCount;
  
  bool getBoolean(int column);
  int getInteger(int column);
  String getColumnName(int column);
  dynamic getColumnPrimitive(int column);
  double getDouble(int column);
  String getString(int column);
  bool isNull(int column);
  bool next();
}

class SimpleTable extends Table {
  final Map<String, ValueType> columns;
  final Map<String, Value> values;
  final List<String> names = [];
  
  SimpleTable(this.columns, this.values) {
    for (var column in columns.keys) {
      names.add(column);
    }
  }
  
  @override
  int get columnCount => columns.length;

  @override
  bool getBoolean(int column) {
    return values[names[column]].toBoolean();
  }

  @override
  String getColumnName(int column) {
    return names[column];
  }

  @override
  dynamic getColumnPrimitive(int column) {
    return values[names[column]].toPrimitive();
  }

  @override
  double getDouble(int column) {
    return values[names[column]].toDouble();
  }

  @override
  int getInteger(int column) {
    return values[names[column]].toInteger();
  }

  @override
  String getString(int column) {
    return values[names[column]].toString();
  }

  @override
  bool isNull(int column) {
    return values[names[column]] == null || values[names[column]].isNull;
  }

  @override
  bool next() {
    return true;
  }
}