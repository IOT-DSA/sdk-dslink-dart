part of dslink.utils;

const int _MAP_LEAK_LIMIT = const int.fromEnvironment(
  "dsa.map.leak_limit",
  defaultValue: 2000
);

const int _LIST_LEAK_LIMIT = const int.fromEnvironment(
  "dsa.list.leak_limit",
  defaultValue: 2000
);

const bool _LEAK_PRINT_STACK = const bool.fromEnvironment(
  "dsa.leak.stacktrace",
  defaultValue: false
);

class LeakProofMap<K, V> extends Collection.DelegatingMap<K, V> {
  final int limit;
  final String id;

  LeakProofMap(Map<K, V> base, this.id, {this.limit: _MAP_LEAK_LIMIT}) :
      super(base);

  factory LeakProofMap.create(String id, {int limit: _MAP_LEAK_LIMIT}) {
    return new LeakProofMap<K, V>(
      new Map<K, V>(),
      id,
      limit: limit
    );
  }

  void operator []=(K key, V value) {
    super[key] = value;
    _check();
  }

  @override
  void addAll(Map<K, V> other) {
    super.addAll(other);
    _check();
  }

  void _check() {
    if (length % limit == 0) {
      String msg = "Map '${id}' is leaking. Current size is ${length} entries.";
      if (_LEAK_PRINT_STACK) {
        try {
          throw "Leaking Map";
        } catch (e, stack) {
          logger.fine(msg, e, stack);
        }
      } else {
        logger.fine(msg);
      }
    }
  }
}

class LeakProofList<T> extends Collection.DelegatingList<T> {
  final int limit;
  final String id;

  LeakProofList(List<T> base, this.id, {this.limit: _LIST_LEAK_LIMIT}) :
      super(base);

  factory LeakProofList.create(String id, {int limit: _LIST_LEAK_LIMIT}) {
    return new LeakProofList<T>(
      new List<T>(),
      id,
      limit: limit
    );
  }

  @override
  void add(T val) {
    super.add(val);
    _check();
  }

  @override
  bool remove(T val) {
    bool result = super.remove(val);
    _check();
    return result;
  }

  @override
  void addAll(Iterable<T> iterable) {
    super.addAll(iterable);
    _check();
  }

  void _check() {
    if (length % limit == 0) {
      String msg = "List '${id}' is leaking. Current size is ${length} entries.";
      if (_LEAK_PRINT_STACK) {
        try {
          throw "Leaking List";
        } catch (e, stack) {
          logger.fine(msg, e, stack);
        }
      } else {
        logger.fine(msg);
      }
    }
  }
}

class LeakProofQueue<T> extends Collection.DelegatingQueue<T> {
  final int limit;
  final String id;

  LeakProofQueue(Queue<T> base, this.id, {this.limit: _LIST_LEAK_LIMIT}) :
      super(base);

  factory LeakProofQueue.create(String id, {int limit: _LIST_LEAK_LIMIT}) {
    return new LeakProofQueue<T>(
      new ListQueue<T>(),
      id,
      limit: limit
    );
  }

  @override
  void add(T val) {
    super.add(val);
    _check();
  }

  @override
  bool remove(T val) {
    bool result = super.remove(val);
    _check();
    return result;
  }

  @override
  void addAll(Iterable<T> iterable) {
    super.addAll(iterable);
    _check();
  }

  void _check() {
    if (length % limit == 0) {
      String msg = "List '${id}' is leaking. Current size is ${length} entries.";
      if (_LEAK_PRINT_STACK) {
        try {
          throw "Leaking List";
        } catch (e, stack) {
          logger.fine(msg, e, stack);
        }
      } else {
        logger.fine(msg);
      }
    }
  }
}
