part of dslink.common;

class ValueType {
  static const ValueType STRING = const ValueType("string");
  static const ValueType NUMBER = const ValueType("number");
  static const ValueType BOOLEAN = const ValueType("boolean");
  static const ValueType TIME = const ValueType("time");
  static const ValueType NULL = const ValueType("null");

  final String name;

  const ValueType(this.name);

  @override
  String toString() => "ValueType(name: ${name})";
}

typedef Value ValueCreator<T>(T input);

class Value {
  static const Map<Type, ValueType> PRIMITIVES = const {
    String: ValueType.STRING,
    int: ValueType.NUMBER,
    double: ValueType.NUMBER,
    bool: ValueType.BOOLEAN,
    Null: ValueType.NULL
  };

  final ValueType type;
  final dynamic value;
  final DateTime timestamp;
  final String status;

  const Value(this.type, this.value, this.timestamp, {this.status: "ok"});

  factory Value.of(input) {
    if (PRIMITIVES.keys.contains(input.runtimeType)) { // Input is primitive.
      return new Value(PRIMITIVES[input.runtimeType], input, new DateTime.now());
    } else if (input is Value) {
      return input;
    } else {
      throw new ArgumentError.value(input, "Value.of does not support the input '${input.runtimeType}'");
    }
  }

  bool isType(Type type) => value is Type;
  bool get isNull => value == null;
  bool get isOk => status.toLowerCase() == "ok";

  Value updateTimestamp([DateTime time]) {
    if (time == null) time = new DateTime.now();
    return new Value(type, value, time);
  }

  Value clone({DateTime timestamp}) {
    if (timestamp == null) timestamp = this.timestamp;
    return new Value(type, value, timestamp);
  }

  @override
  bool operator ==(obj) => obj is Value && obj.type == type && obj.value == value && obj.timestamp == timestamp;

  @override
  int get hashCode => hashObjects([type, value, timestamp]);

  @override
  String toString() => "Value(type: ${type}, value: ${value}, timestamp: ${timestamp}, status: ${status})";

  static Value valueOf(input) => new Value.of(input);
}


class ValueUpdate {
  Object value;
  String ts;
  String status;
  int count;
  num sum, min, max;
  ValueUpdate(this.value, this.ts, {Map meta, this.status, this.count: 1, this.sum: double.NAN, this.min: double.NAN, this.max: double.NAN}) {
    if (meta != null) {
      if (meta['count'] is int) {
        count = meta['count'];
      }
      if (meta['status'] is String) {
        status = meta['status'];
      }
      if (meta['sum'] is num) {
        sum = meta['sum'];
      }
      if (meta['max'] is num) {
        max = meta['max'];
      }
      if (meta['min'] is num) {
        min = meta['min'];
      }
    }
    if (value is num && count == 1) {
      if (sum != sum) sum = value;
      if (max != max) max = value;
      if (min != min) min = value;
    }
  }
}
