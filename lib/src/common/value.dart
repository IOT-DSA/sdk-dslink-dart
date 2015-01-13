part of dslink.common;

class ValueType {
  final String name;
  
  const ValueType(this.name);
}

class Value {
  final ValueType type;
  final dynamic value;
  final DateTime timestamp;
  
  Value(this.type, this.value, this.timestamp);
  
  Value updateTimestamp([DateTime time]) {
    if (time == null) time = new DateTime.now();
    return new Value(type, value, time);
  }
  
  Value clone({DateTime timestamp}) {
    if (timestamp == null) timestamp = this.timestamp;
    return new Value(type, value, timestamp);
  }
  
  bool operator ==(obj) => obj is Value && obj.type == type && obj.value == value && obj.timestamp == timestamp;
  
  int get hashCode => hashObjects([type, value, timestamp]);
}