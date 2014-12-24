part of dslink.api;

typedef Value ValueCreator();
typedef bool UpdateFilter(Value last, Value current);

/// A DSA Node
abstract class DSNode {
  String get name;
  Map<String, DSNode> get children;
  Map<String, DSAction> get actions;
  Set<Subscriber> get subscribers;
  ValueCreator get valueCreator;
  set valueCreator(ValueCreator creator);
  String get icon;
  String get path;
  set icon(String url);
  ValueType get valueType;
  set valueType(ValueType type);
  DSNode get parent;
  set parent(DSNode node);
  bool get hasValue;
  bool get hasValueHistory;
  Value get value;
  set value(Value val);
  String get displayName;
  set displayName(String name);
  void addChild(DSNode node);
  void addAction(DSAction action);
  dynamic invoke(String action, Map<String, Value> args);
  getValueHistory();
  DSNode createChild(String name, {dynamic value, String icon, bool recording: false, bool setter: false, UpdateFilter updateFilter, Interval updateInterval, RollupType updateRollup});
  DSAction createAction(String name, {Map<String, ValueType> params: const {}, Map<String, ValueType> results: const {}, ActionExecutor execute, bool hasTableReturn: false});
  void subscribe(Subscriber subscriber);
  void unsubscribe(Subscriber subscriber);
  String getDisplayValue(Value value);
  bool get isWatchable;
  bool shouldUpdate(Value lastValue, Value currentValue);
  Interval getUpdateInterval();
  RollupType getUpdateRollup();
  Interval get updateInterval;
  RollupType get updateRollup;
  set updateInterval(Interval interval);
  set updateRollup(RollupType rollup);
  void removeChild(String name);
}

typedef void ActionHandler();

class BaseNode extends DSNode {
  final String name;
  final Map<String, DSNode> children = {};
  final Set<Subscriber> subscribers = new Set<Subscriber>();
  final Map<String, DSAction> actions = {};
  
  UpdateFilter updateFilter;
  RollupType updateRollup = RollupType.LAST;
  Interval updateInterval = Interval.ONE_HUNDRED_MILLISECONDS;
  
  ValueCreator valueCreator = () => Value.of(null);
  
  bool hasValue = false;
  ValueType _type;
  
  String icon;

  BaseNode(this.name);
  
  set valueType(ValueType val) => _type = val;
  
  ValueType get valueType {
    var v = value;
    if (v != null) {
      return v.type;
    } else if (_type != null) {
      return _type;
    } else {
      return null;
    }
  }
  
  DSNode parent;
  
  Value _value;
  
  String _displayName;
  set displayName(String val) => _displayName = val;
  String get displayName {
    if (_displayName != null) {
      return _displayName;
    } else {
      return name;
    }
  }
  
  String get path {
    var n = this;
    var parts = [];
    while (n.parent != null) {
      parts.add(n.name);
      n = n.parent;
    }
    parts = parts.reversed;
    return "/" + parts.join("/");
  }
  
  String getDisplayValue(Value val) {
    return null;
  }
  
  void addChild(DSNode child) {
    children[child.name] = child;
    child.parent = this;
    _notifyTreeUpdate();
  }
  
  void _notifyTreeUpdate() {
    for (var sub in subscribers) {
      sub.treeChanged(this);
    }
  }
  
  void subscribe(Subscriber subscriber) {
    subscribers.add(subscriber);
    subscriber.subscribed(this);
  }
  
  void unsubscribe(Subscriber subscriber) {
    subscribers.remove(subscriber);
    subscriber.unsubscribed(this);
  }
  
  DSNode createChild(String displayName, {dynamic value, String icon, bool recording: false, bool setter: false, UpdateFilter updateFilter, Interval updateInterval, RollupType updateRollup}) {
    var name = displayName.replaceAll(" ", "_");
    var node = recording ? new RecordingDSNode(name) : new BaseNode(name);
    addChild(node);
    
    if (value != null) {
      node.value = value;
    }
    
    if (updateFilter != null) {
      node.updateFilter = updateFilter;
    }
    
    if (updateInterval != null) {
      node.updateInterval = updateInterval;
    }
    
    if (updateRollup != null) {
      node.updateRollup = updateRollup;
    }
    
    if (setter) {
      node.createAction("SetValue", params: {
        "value": node.value.type
      }, execute: (args) {
        node.value = args["value"];
      });
    }
    
    node.displayName = displayName;
    node.icon = icon;
    return node;
  }
  
  Value get value {
    if (_value != null) {
      return _value;
    } else {
      _setValue(valueCreator());
      return _value;
    }
  }
  
  set value(val) => _setValue(val);
  
  Value _lastValue;
  
  void _setValue(val) {
    Value v;
    if (val is Value) {
      v = val;
    } else {
      v = Value.of(val);
    }
    
    if (_value != null && v.type == _value.type && v.toPrimitive() == _value.toPrimitive()) { // Value is the exact same
      return;
    }
    
    _lastValue = _value;
    
    hasValue = true;
    _value = v;
    _notifyValueUpdate();
  }
  
  void addAction(DSAction action) {
    _notifyTreeUpdate();
    actions[action.name] = action;
  }
  
  DSAction createAction(String name, {Map<String, ValueType> params: const {}, Map<String, ValueType> results: const {}, ActionExecutor execute, bool hasTableReturn: false}) {
    var action = new DSAction(name, params: params, results: results, execute: execute, hasTableReturn: hasTableReturn);
    addAction(action);
    return action;
  }
  
  void _notifyValueUpdate() {
    for (var sub in subscribers) {
      sub.valueChanged(_lastValue, this, value);
    }
  }
  
  dynamic invoke(String action, Map<String, Value> params) {
    if (actions.containsKey(action)) {
      return actions[action].invoke(params);
    }
    return null;
  }
  
  /// Fetches Value History. This can return a Trend or a Future<Trend>
  getValueHistory() {
    return null;
  }
  
  bool hasValueHistory = false;

  @override
  bool get isWatchable => true;

  @override
  bool shouldUpdate(Value lastValue, Value currentValue) {
    if (updateFilter == null) {
      return true;
    } else {
      return updateFilter(lastValue, currentValue);
    }
  }

  @override
  Interval getUpdateInterval() {
    return updateInterval;
  }

  @override
  RollupType getUpdateRollup() {
    return updateRollup;
  }

  @override
  void removeChild(String name) {
    children.remove(name);
    _notifyTreeUpdate();
  }
}

class RecordingDSNode extends BaseNode {
  final List<Value> values = [];
  
  RecordingDSNode(String name) : super(name) {
    _start = new DateTime.now();
    hasValueHistory = true;
  }
  
  @override
  set value(val) {
    _setValue(val);
    values.add(value);
  }
  
  @override
  getValueHistory() => Trends.create(valueType, values);
  
  DateTime _start;
}

typedef dynamic ActionExecutor(Map<String, Value> args);
typedef void Runnable();

class Poller {
  final Runnable runner;
  
  Timer _timer;
  
  Poller(this.runner);
  
  void poll(Duration interval) {
    if (_timer != null && _timer.isActive) {
      throw new StateError("poller already started");
    }
    
    _timer = new Timer.periodic(interval, (timer) {
      runner();
    });
  }
  
  void pollSeconds(int count) => poll(new Duration(seconds: count));
  void pollMinutes(int count) => poll(new Duration(minutes: count));
  void pollHours(int count) => poll(new Duration(hours: count));
  void pollEverySecond() => pollSeconds(1);
  void pollEveryFiveSeconds() => pollSeconds(5);
  
  void cancel() {
    _timer.cancel();
  }
}

Poller poller(Runnable runner) => new Poller(runner);

class DSAction {
  final String name;
  final Map<String, ValueType> results;
  final Map<String, ValueType> params;
  final ActionExecutor execute;
  final bool hasTableReturn;
  final String tableName;
  
  DSAction(this.name, {this.results: const {}, this.params: const {}, this.execute, this.hasTableReturn: false, this.tableName: "table"});
  
  dynamic invoke(Map<String, Value> args) {
    if (execute != null) {
      return execute(args);
    } else {
      return null;
    }
  }
}

abstract class Subscriber {
  final String name;
  
  Subscriber(this.name);
  
  void subscribed(DSNode node) {}
  void valueChanged(Value lastValue, DSNode node, Value value);
  void unsubscribed(DSNode node) {}
  void treeChanged(DSNode node) {}
}
