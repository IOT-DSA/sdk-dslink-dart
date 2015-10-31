part of dslink.broker;

class BrokerDataNode extends BrokerNode {
  static IValueStorageBucket storage;
  BrokerNode parent;
  BrokerDataNode(String path, BrokerNodeProvider provider)
      : super(path, provider) {
    configs[r'$is'] = 'broker/dataNode';
    profile = provider.getOrCreateNode('/defs/profile/broker/dataNode', false);
    configs[r'$writable'] = 'write';
  }
  Response setValue(Object value, Responder responder, Response response,
      [int maxPermission = Permission.CONFIG]) {
    if (parent == null) {
      // add this node to tree and create all parent levels
      provider.getOrCreateNode(path, true);
      if (configs[r'$type'] == null) {
        configs[r'$type'] = 'dynamic';
      }
    }
    if (storage != null &&
        (lastValueUpdate == null || lastValueUpdate.value != value)) {
      storage.setValue(path, value);
    }
    return super.setValue(value, responder, response, maxPermission);
  }
  
  @override
  void load(Map m) {
    super.load(m);
    children.forEach((String key, Node node) {
      if (node is BrokerDataNode) {
        node.parent = this;
      }
    });
  }
}
class BrokerDataRoot extends BrokerDataNode {
  BrokerNode parent;
  BrokerDataRoot(String path, BrokerNodeProvider provider)
      : super(path, provider) {
    configs[r'$is'] = 'broker/dataRoot';
    profile = provider.getOrCreateNode('/defs/profile/broker/dataRoot', false);
    // avoid parent checking
    parent = this;
  }
}

InvokeResponse addDataNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  Object name = params['Name'];
  Object type = params['Type'];
  Object editor = params['Editor'];
  if (parentNode is BrokerDataNode &&
      parentNode.parent != null && // make sure parent node itself is in tree
      name is String &&
      name != '' &&
      !name.contains(Path.invalidNameChar) &&
      !name.startsWith(r'$') &&
      !name.startsWith(r'!')) {
    if (parentNode.children.containsKey(name)) {
      return response
        ..close(new DSError('invalidParameter', msg: 'node already exist'));
    }
    BrokerDataNode node = responder.nodeProvider.getOrCreateNode(
        '${parentNode.path}/$name', false);
    if (type is String &&
        const [
      'string',
      'number',
      'bool',
      'array',
      'map',
      'binary',
      'dynamic'
    ].contains(type)) {
      node.configs[r'$type'] = type;
      if (editor is String) {
        node.configs[r'$editor'] = editor;
      }
    }
    parentNode.children[name] = node;
    node.parent = parentNode;
    parentNode.updateList(name);
    DsTimer.timerOnceBefore(
        (responder.nodeProvider as BrokerNodeProvider).saveDataNodes, 1000);
    return response..close();
  }
  return response..close(DSError.INVALID_PARAMETER);
}

InvokeResponse deleteDataNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  Object recursive = params['Recursive'];
  if (parentNode is BrokerDataNode &&
          parentNode is! BrokerDataRoot &&
          parentNode.parent != null // make sure parent node itself is in tree
      ) {
    if (recursive == true) {
      removeDataNodeRecursive(parentNode, parentNode.path.substring(parentNode.path.lastIndexOf('/') + 1));
    } else {
      if (parentNode.children.isEmpty) {
        BrokerDataNode parent = parentNode.parent;
        String name = parentNode.path.substring(parentNode.path.lastIndexOf('/') + 1);
        parentNode.parent = null;
        parent.children.remove(name);
        parent.updateList(name);
        parentNode.clearValue();
      } else {
        return response..close(DSError.INVALID_PARAMETER);
      }
    }
    DsTimer.timerOnceBefore(
        (responder.nodeProvider as BrokerNodeProvider).saveDataNodes, 1000);
    return response..close();
  }
  return response..close(DSError.INVALID_PARAMETER);
}
void removeDataNodeRecursive(BrokerDataNode node, String name) {
  for (String name in node.children.keys.toList()) {
    removeDataNodeRecursive(node.children[name], name);
  }
  BrokerDataNode parent = node.parent;
  node.parent = null;
  parent.children.remove(name);
  parent.updateList(name);
  node.clearValue();
}

Map dataNodeFunctions = {
  "broker": {
    "dataNode": {
      "addNode": addDataNode,
      "addValue": addDataNode,
      "deleteNode": deleteDataNode
    },
    "dataRoot": {"addNode": addDataNode, "addValue": addDataNode},
  }
};
