part of dslink.api;

/**
 * Represents a way to combine multiple values into a single value.
 */
abstract class Rollup {
  /**
   * Rolls multiple values into a single value.
   */
  Value combine(List<Value> values);
}

/**
 * Represents a type of rollup.
 */
class RollupType {
  static const RollupType FIRST = const RollupType._(1);
  static const RollupType LAST = const RollupType._(2);
  static const RollupType MAX = const RollupType._(3);
  static const RollupType MIN = const RollupType._(4);
  static const RollupType OR = const RollupType._(5);
  static const RollupType AND = const RollupType._(6);
  static const RollupType COUNT = const RollupType._(7);
  static const RollupType AVG = const RollupType._(8);
  static const RollupType SUM = const RollupType._(9);
  
  const RollupType._(this.id);
  
  final int id;
  
  static const Map<String, RollupType> _TYPES = const {
    "and": AND,
    "average": AVG,
    "avg": AVG,
    "count": COUNT,
    "first": FIRST,
    "last": LAST,
    "maximum": MAX,
    "max": MAX,
    "minimum": MIN,
    "min": MIN,
    "or": OR,
    "sum": SUM,
    "default": FIRST
  };
  
  static RollupType forName(String name) {
    if (_TYPES.containsKey(name.toLowerCase())) {
      return _TYPES[name.toLowerCase()];
    } else {
      return null;
    }
  }
  
  /**
   * Creates a rollup from this type.
   */
  Rollup create() {
    switch (this) {
      case FIRST:
        return new FirstRollup();
      case LAST:
        return new LastRollup();
      case MAX:
        return new MaxRollup();
      case MIN:
        return new MinRollup();
      case OR:
        return new OrRollup();
      case AND:
        return new AndRollup();
      case COUNT:
        return new CountRollup();
      case AVG:
        return new AvgRollup();
      case SUM:
        return new SumRollup();
      default:
        throw new Exception("This should never happen");
    }
  }
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
    if (!values.every((it) => it.type.name == "number")) {
      throw new Exception("Rollup contains non-numerical values.");
    }

    var prims = values.map((it) => it.toPrimitive()).toList();
    return Value.of(prims.reduce((a, b) => a + b));
  }
}

class AvgRollup extends Rollup {
  @override
  combine(List<Value> values) {
    if (!values.every((it) => it.type.name == "number")) {
      throw new Exception("Rollup contains non-numerical values.");
    }
    
    var prims = values.map((it) => it.toPrimitive()).toList();
    return Value.of(prims.reduce((a, b) => a + b) / prims.length);
  }
}

List<Value> _copySort(List<Value> values, Comparator<Value> comparator) {
  var list = new List.from(values);
  list.sort(comparator);
  return list;
}