part of dslink.api;

abstract class Rollup {
  dynamic combine(List<Value> values);
}

class FirstRollup extends Rollup {
  @override
  combine(List<Value> values) => values.first;
}

class LastRollup extends Rollup {
  @override
  combine(List<Value> values) => values.last;
}

class MaxRollup extends Rollup {
  @override
  combine(List<Value> values) => _copySort(values, (a, b) => b.toDouble().compareTo(a.toDouble())).first;
}

class MinRollup extends Rollup {
  @override
  combine(List<Value> values) => _copySort(values, (a, b) => a.toDouble().compareTo(b.toDouble())).first;
}

class OrRollup extends Rollup {
  @override
  combine(List<Value> values) => Value.of(values.any((value) => value.isTruthy()));
}

class AndRollup extends Rollup {
  @override
  combine(List<Value> values) => Value.of(values.every((value) => value.isTruthy()));
}

class CountRollup extends Rollup {
  @override
  combine(List<Value> values) => Value.of(values.length);
}

class SumRollup extends Rollup {
  @override
  combine(List<Value> values) {
    if (!values.every((it) => it.type == "number")) {
      throw new Exception("Rollup contains non-numerical values.");
    }
    
    return Value.of(values.reduce((a, b) => a.toPrimitive() + b.toPrimitive()));
  }
}

class AvgRollup extends Rollup {
  @override
  combine(List<Value> values) {
    if (!values.every((it) => it.type == "number")) {
      throw new Exception("Rollup contains non-numerical values.");
    }
    
    var prims = values.map((it) => it.toPrimitive());
    return Value.of(prims.reduce((a, b) => a + b) / prims.length);
  }
}

List<Value> _copySort(List<Value> values, Comparator<Value> comparator) {
  var list = new List.from(values);
  list.sort(comparator);
  return list;
}