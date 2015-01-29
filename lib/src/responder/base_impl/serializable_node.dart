part of dslink.responder;


abstract class SerializableNodeProvider extends NodeProvider {
  Map<String, LocalNode> get nodes;
}

class SerializableNode extends LocalNode {
  SerializableNode(String path) : super(path);
  Map serialize(bool withChildren) {
    var rslt = {};
    configs.forEach((key, val) {
      rslt[key] = val;
    });
    attributes.forEach((key, val) {
      rslt[key] = val;
    });
    children.forEach((key, val) {
      if (withChildren) {
        rslt[key] = val.serialize(true);
      }
    });
    return rslt;
  }
  
  bool _loaded = false;
  void load(Map m, SerializableNodeProvider provider) {
    if (_loaded) {
      configs.clear();
      attributes.clear();
      children.clear();
    }
    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        Node node = provider.getNode('$path/$key');
        if (node is SerializableNode) {
          node.load(value, provider);
        }
        children[key] = node;
      }
    });
    _loaded = true;
  }
}
