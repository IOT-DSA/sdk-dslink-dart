part of dslink.api;

class DSNode {
  final String name;
  final Map<String, DSNode> children = {};
  final List<Subscriber> subscribers = [];
  final Map<String, DSAction> actions = {};
  bool hasValue = false;
  ValueType _type;
  
  String icon;
  
  set valueType(ValueType val) => _type = val;
  ValueType get valueType {
    if (value != null) {
      return value.type;
    } else if (_type != null) {
      return _type;
    } else {
      return null;
    }
  }
  
  DSNode parent;
  
  Value _value;
  
  DSNode(this.name);
  
  String get path {
    var n = this;
    var parts = [];
    while (n.parent != null) {
      parts.add(n.name);
      n = n.parent;
    }
    var buff = new StringBuffer();
    parts = parts.reversed;
    return "/" + parts.join("/");
  }
  
  void addChild(DSNode child) {
    children[child.name] = child;
    child.parent = this;
  }
  
  void subscribe(Subscriber subscriber) {
    subscribers.add(subscriber);
    subscriber.subscribed(this);
  }
  
  void unsubscribe(Subscriber subscriber) {
    subscribers.remove(subscriber);
    subscriber.unsubscribed(this);
  }
  
  DSNode createChild(String name, {dynamic value, String icon, bool recording: false}) {
    var node = recording ? new RecordingDSNode(name) : new DSNode(name);
    addChild(node);
    
    if (value != null) {
      node.value = value;
    }
    
    node.icon = icon;
    return node;
  }
  
  Value get value => _value;
  set value(val) => _setValue(val);
  
  void _setValue(val) {
    Value v;
    if (val is Value) {
      v = val;
    } else {
      v = Value.of(val);
    }
    hasValue = true;
    _value = v;
    _notifyValueUpdate();
  }
  
  void addAction(DSAction action) {
    actions[action.name] = action;
  }
  
  DSAction createAction(String name, {Map<String, ValueType> params: const {}, Map<String, ValueType> results: const {}, ActionExecutor execute, bool hasTableReturn: false}) {
    var action = new DSAction(name, params: params, results: results, execute: execute, hasTableReturn: hasTableReturn);
    addAction(action);
    return action;
  }
  
  void _notifyValueUpdate() {
    for (var sub in subscribers) {
      sub.valueChanged(this, value);
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
}

class RecordingDSNode extends DSNode {
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
  getValueHistory() => new ValueTrend(DSContext.getTimeRange(), valueType, values, interval: DSContext.getInterval());
  
  DateTime _start;
}

typedef dynamic ActionExecutor(Map<String, Value> args);

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
  void valueChanged(DSNode node, Value value);
  void unsubscribed(DSNode node) {}
}