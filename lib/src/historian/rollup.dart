part of dslink.historian;

abstract class Rollup {
  dynamic get value;

  void add(dynamic input);

  void reset();
}

class FirstRollup extends Rollup {
  @override
  void add(input) {
    if (set) {
      return;
    }
    value = input;
    set = true;
  }

  @override
  void reset() {
    set = false;
  }

  dynamic value;
  bool set = false;
}

class LastRollup extends Rollup {
  @override
  void add(input) {
    value = input;
  }

  @override
  void reset() {
  }

  dynamic value;
}

class AvgRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => input.length);
    }

    if (input is! num) {
      return;
    }

    total += input;
    count++;
  }

  @override
  void reset() {
    total = 0.0;
    count = 0;
  }

  dynamic total = 0.0;

  dynamic get value => total / count;
  int count = 0;
}

class SumRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => input.length);
    }

    if (input is! num) {
      return;
    }

    value += input;
  }

  @override
  void reset() {
    value = 0.0;
  }

  dynamic value = 0.0;
}

class CountRollup extends Rollup {
  @override
  void add(input) {
    value++;
  }

  @override
  void reset() {
    value = 0;
  }

  dynamic value = 0;
}

class MaxRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => null);
    }

    if (input is! num) {
      return;
    }

    value = max(value == null ? double.NEGATIVE_INFINITY : value, input);
  }

  @override
  void reset() {
    value = null;
  }

  dynamic value;
}

class MinRollup extends Rollup {
  @override
  void add(input) {
    if (input is String) {
      input = num.parse(input, (e) => null);
    }

    if (input is! num) {
      return;
    }

    value = min(value == null ? double.INFINITY : value, input);
  }

  @override
  void reset() {
    value = null;
  }

  dynamic value;
}

typedef Rollup RollupFactory();

final Map<String, RollupFactory> _rollups = {
  "none": () => null,
  "delta": () => new FirstRollup(),
  "first": () => new FirstRollup(),
  "last": () => new LastRollup(),
  "max": () => new MaxRollup(),
  "min": () => new MinRollup(),
  "count": () => new CountRollup(),
  "sum": () => new SumRollup(),
  "avg": () => new AvgRollup()
};
