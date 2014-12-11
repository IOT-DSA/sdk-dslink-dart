part of dslink;

class Metadata {
  static final Metadata STRING = new Metadata()
    ..type = ValueType.STRING;
  
  List<String> enumValues;
  double maxValue;
  double minValue;
  int precision;
  String timezone;
  ValueType type;
  String unitSymbol;
}

class Value {
  final DateTime timestamp;
  final ValueType type;
  final dynamic _value;
  final String status;
  
  Value(this.timestamp, this.type, dynamic value, {this.status: "ok"}) : _value = value;
  
  @override
  String toString() {
    if (_value == null) {
      return "null";
    } else {
      return _value.toString();
    }
  }
  
  int toInteger() {
    if (_value is! int) {
      throw new Exception("NOT THE RIGHT TYPE!");
    }
    return _value;
  }
  
  double toDouble() {
    if (_value.runtimeType != double) {
      throw new Exception("NOT THE RIGHT TYPE!");
    }
    return _value;
  }
  
  bool toBoolean() {
    if (_value is! bool) {
      throw new Exception("NOT THE RIGHT TYPE!");
    }
    return _value;
  }
  
  dynamic toPrimitive() {
    return _value == null ? null : ([
      int,
      double,
      bool
    ].contains(_value.runtimeType) ? _value : _value.toString());
  }
  
  static Value of(input) {
    if (input is String) {
      return new Value(new DateTime.now(), ValueType.STRING, input);
    } else if (input is int) {
      return new Value(new DateTime.now(), ValueType.INTEGER, input);
    } else if (input.runtimeType == double) {
      return new Value(new DateTime.now(), ValueType.DOUBLE, input);
    } else {
      throw new Exception("Unsupported Type");
    }
  }
}

class ValueType {
  static const ValueType STRING = const ValueType._("string");
  static const ValueType INTEGER = const ValueType._("integer");
  static const ValueType DOUBLE = const ValueType._("double");
  
  const ValueType._(this.name);
  
  final String name;  
}