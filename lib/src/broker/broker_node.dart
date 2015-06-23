part of dslink.broker;

/// Wrapper node for brokers
class BrokerNode extends LocalNodeImpl {
  BrokerNode(String path) : super(path);
}

/// Version node
class BrokerVersionNode extends LocalNodeImpl {
  BrokerVersionNode(String path, String version) : super(path) {
    configs[r"$type"] = "string";
    updateValue(version);
  }
}

/// Start Time node
class StartTimeNode extends LocalNodeImpl {
  StartTimeNode(String path) : super(path) {
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
  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response, LocalNode parentNode, [int maxPermission = Permission.CONFIG]) {
    provider.clearConns();
    return response..close();
  }
}
