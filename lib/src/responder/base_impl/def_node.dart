part of dslink.responder;

/// definition nodes are serializable node that won't change
/// the only change will be a global upgrade
class DefinitionNode extends LocalNodeImpl {
  DefinitionNode(String path) : super(path) {
    this.configs[r'$is'] = 'def';
  }

  // TODO, list node of definition should get closed
}

class RootNode extends DefinitionNode {
  RootNode(String path) : super(path) {
    permissions = new PermissionList();
  }

  bool _loaded = false;
  void load(Map m, NodeProviderImpl provider) {
    if (_loaded) {
      throw 'root node can not be initialized twice';
    }
    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        LocalNodeImpl node = new LocalNodeImpl('/$key');
        node.load(value, provider);
        provider.nodes[node.path] = node;
        children[key] = node;
      }
    });
  }
}
