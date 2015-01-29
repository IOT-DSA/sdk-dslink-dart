part of dslink.broker;

/// definition nodes are serializable node that won't change
/// the only change will be a global upgrade
class DefinitionNode extends SerializableNode {
  DefinitionNode(String path) : super(path);

  // TODO, list node of definition should get closed
}

class RootNode extends DefinitionNode {
  RootNode(String path) : super(path);

  bool _loaded = false;
  void load(Map m, SerializableNodeProvider provider) {
    if (_loaded) {
      throw 'root node can not be initialized twice';
    }
    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        SerializableNode node = new SerializableNode('/$key');
        node.load(value, provider);
        provider.nodes[node.path] = node;
        children[key] = node;
      }
    });
  }
}
