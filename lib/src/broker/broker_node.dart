part of dslink.broker;

// a wrapper node for
class BrokerNode extends LocalNodeImpl {
  BrokerNode(String path) : super(path);
}

class BrokerVersionNode extends LocalNodeImpl {
  BrokerVersionNode(String path, String version) : super(path) {
    configs[r'$type'] = 'string';
    updateValue(version);
  }
}
class StartTimeNode extends LocalNodeImpl {
  StartTimeNode(String path) : super(path) {
    configs[r'$type'] = 'time';
    updateValue(ValueUpdate.getTs());
  }
}