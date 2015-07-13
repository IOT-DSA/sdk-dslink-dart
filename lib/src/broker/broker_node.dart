part of dslink.broker;

/// Wrapper node for brokers
class BrokerNode extends LocalNodeImpl with BrokerNodePermission{
  final BrokerNodeProvider provider;
  BrokerNode(String path, this.provider) : super(path);
  
  @override
  void load(Map m) {
    super.load(m);
    if (m['?permissions'] is List) {
      loadPermission(m['?permissions']);
    }
  }
  
  @override 
  Map serialize(bool withChildren) {
    Map rslt = super.serialize(withChildren);
    List permissionData = this.serializePermission();
    if (permissionData != null) {
      rslt['?permissions'] = permissionData;
    }
    return rslt;
  }
  
  @override
  int getPermission (Iterator<String> paths, Responder responder, int permission) {
    permission = super.getPermission(paths, responder, permission);
    if (permission == Permission.CONFIG) {
      return Permission.CONFIG;
    }
    if (paths.moveNext()) {
      String name = paths.current;
      if (children[name] is BrokerNodePermission) {
        return (children[name] as BrokerNodePermission).getPermission(paths, responder, permission);
      }
    }
    return permission;
  }
}

/// Version node
class BrokerVersionNode extends BrokerNode {
  static BrokerVersionNode instance;
  BrokerVersionNode(String path, BrokerNodeProvider provider, String version) : super(path, provider) {
    instance = this;
    configs[r"$type"] = "string";
    updateValue(version);
  }
}

/// Start Time node
class StartTimeNode extends BrokerNode {
  static StartTimeNode instance;
  StartTimeNode(String path, BrokerNodeProvider provider) : super(path, provider) {
    instance = this;
    configs[r"$type"] = "time";
    updateValue(ValueUpdate.getTs());
  }
}

/// Clear Conns node
class ClearConnsAction extends BrokerNode {

  ClearConnsAction(String path, BrokerNodeProvider provider) : super(path, provider) {
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

class RootNode extends BrokerNode {
  RootNode(String path, BrokerNodeProvider provider) : super(path, provider) {}

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
