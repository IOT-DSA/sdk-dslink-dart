part of dslink.responder;

typedef InvokeResponse InvokeCallback(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode);

/// definition nodes are serializable node that won't change
/// the only change will be a global upgrade
class DefinitionNode extends LocalNodeImpl {
  DefinitionNode(String path) : super(path) {
    this.configs[r'$is'] = 'static';
  }

  InvokeCallback _invokeCallback;
  void setInvokeCallback(InvokeCallback callback) {
    _invokeCallback = callback;
  }
  InvokeResponse invoke(Map params, Responder responder,
      InvokeResponse response, LocalNode parentNode,
      [int maxPermission = Permission.CONFIG]) {
    if (_invokeCallback == null) {
      return response..close(DSError.NOT_IMPLEMENTED);
    }
    int permission = responder.nodeProvider.permissions.getPermission(
        parentNode.path, responder);
    if (maxPermission < permission) {
      permission = maxPermission;
    }
    if (getInvokePermission() <= permission) {
      _invokeCallback(params, responder, response, parentNode);
      return response;
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }

    return response..close();
  }
}

class RootNode extends LocalNodeImpl {
  RootNode(String path) : super(path) {}

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
