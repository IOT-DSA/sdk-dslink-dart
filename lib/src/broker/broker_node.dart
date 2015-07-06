part of dslink.broker;

/// Wrapper node for brokers
class BrokerNode extends LocalNodeImpl {
  final BrokerNodeProvider provider;
  BrokerNode(String path, this.provider) : super(path);
}

/// Version node
class BrokerVersionNode extends LocalNodeImpl {
  static BrokerVersionNode instance;
  final NodeProvider provider;
  BrokerVersionNode(String path, this.provider, String version) : super(path) {
    instance = this;
    configs[r"$type"] = "string";
    updateValue(version);
  }
}

/// Start Time node
class StartTimeNode extends LocalNodeImpl {
  static StartTimeNode instance;
  final NodeProvider provider;
  StartTimeNode(String path, this.provider) : super(path) {
    instance = this;
    configs[r"$type"] = "time";
    updateValue(ValueUpdate.getTs());
  }
}

/// Clear Conns node
class ClearConnsAction extends LocalNodeImpl {
  BrokerNodeProvider provider;

  ClearConnsAction(String path, this.provider) : super(path) {
    configs[r"$name"] = "Clear Conns";
    configs[r"$invokable"] = "read";
  }

  @override
  InvokeResponse invoke(Map params, Responder responder,
      InvokeResponse response, LocalNode parentNode,
      [int maxPermission = Permission.CONFIG]) {
    provider.clearConns();
    return response..close();
  }
}

class RootNode extends LocalNodeImpl {
  final BrokerNodeProvider provider;
  RootNode(String path, this.provider) : super(path) {}

  bool _loaded = false;

  void load(Map m) {
    if (_loaded) {
      throw 'root node can not be initialized twice';
    }

    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        BrokerNode node = new BrokerNode('/$key', provider);
        node.load(value);
        provider.nodes[node.path] = node;
        children[key] = node;
      }
    });
  }
}
