part of dslink;

class DSNode {
  final String name;
  final Map<String, DSNode> children = {};
  final List<Subscriber> subscribers = [];
  bool hasValue = false;
  
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
  
  DSNode createChild(String name, {dynamic value}) {
    var node = new DSNode(name);
    addChild(node);
    node.value = value;
    return node;
  }
  
  Value get value => _value;
  set value(val) {
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
  
  void _notifyValueUpdate() {
    for (var sub in subscribers) {
      sub.valueChanged(this, value);
    }
  }
}

class DSAction {
  final String name;
  
  DSAction(this.name);
}

abstract class Subscriber {
  final String name;
  
  Subscriber(this.name);
  
  void subscribed(DSNode node) {}
  void valueChanged(DSNode node, Value value);
  void unsubscribed(DSNode node) {}
}