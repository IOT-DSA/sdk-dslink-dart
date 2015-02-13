part of dslink.responder;

typedef Map _FunctionCallback(String path, Map params);

class SimpleNodeProvider extends NodeProviderImpl {
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  LocalNode getNode(String path) {
    if (nodes.containsKey(path)) {
      return nodes[path];
    }
    var node = new SimpleNode(path);
    nodes[path] = node;
    return node;
  }
  SimpleNodeProvider([Map m]) {
    SimpleNode root = getNode("/");
    if (m != null) {
      root.load(m, this);
    }
  }
  void init([Map m]) {
    SimpleNode root = getNode("/");
    if (m != null) {
      root.load(m, this);
    }
  }
  void updateValue(String path, Object value) {
    SimpleNode node = getNode(path);
    node.valueController.add(new ValueUpdate(value, (new DateTime.now()).toUtc().toIso8601String()));
  }
}

class SimpleNode extends LocalNodeImpl {
  SimpleNode(String path) : super(path);

  _FunctionCallback invokeCallback;

  void load(Map m, NodeProviderImpl provider) {
    if (_loaded) {
      configs.clear();
      attributes.clear();
      children.clear();
    }
    String childPathPre;
    if (path == '/') {
      childPathPre = '/';
    } else {
      childPathPre = '$path/';
    }
    m.forEach((String key, value) {
      if (key.startsWith('?')) {
        if (key == '?invoke') {
          if (value is _FunctionCallback) {
            invokeCallback = value;
          } else {
            print('$value is not a valid FunctionCallback: $_FunctionCallback');
          }
        }
      } else if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        String childPathpath;
        Node node = provider.getNode('$childPathPre$key');
        children[key] = node;
        if (node is LocalNodeImpl) {
          node.load(value, provider);
        }
      }
    });
    _loaded = true;
  }

  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    if (invokeCallback != null) {
      Map rslt = invokeCallback(path, params);
      if (rslt != null) {
        response.updateStream([rslt]);
      }
    }
    return response..close();
  }

}
