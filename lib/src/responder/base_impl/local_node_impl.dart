part of dslink.responder;

abstract class NodeProviderImpl extends NodeProvider {
  Map<String, LocalNode> get nodes;
}

abstract class LocalNodeImpl extends LocalNode {
  LocalNodeImpl(String path) : super(path);

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
        if (val is LocalNodeImpl) {
          rslt[key] = val.serialize(true);
        } else {
          rslt[key] = val.getSimpleMap();
        }
      }
    });

    return rslt;
  }

  bool _loaded = false;

  bool get loaded => _loaded;

  @override
  void load(Map m) {
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
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        Node node = provider.getOrCreateNode('$childPathPre$key', false);
        if (node is LocalNodeImpl) {
          node.load(value);
        }
        children[key] = node;
      }
    });
    _loaded = true;
  }

  void updateList(String name) {
    listChangeController.add(name);
  }

  @override
  Response setAttribute(String name, Object value, Responder responder,
      Response response) {
    if (!attributes.containsKey(name) || attributes[name] != value) {
      attributes[name] = value;
      updateList(name);

      if (provider is SerializableNodeProvider) {
        (provider as SerializableNodeProvider).persist();
      }
    }
    return response..close();
  }

  @override
  Response removeAttribute(String name, Responder responder,
      Response response) {
    if (attributes.containsKey(name)) {
      attributes.remove(name);
      updateList(name);

      if (provider is SerializableNodeProvider) {
        (provider as SerializableNodeProvider).persist();
      }
    }
    return response..close();
  }

  @override
  Response setConfig(String name, Object value, Responder responder,
      Response response) {
    var config = Configs.getConfig(name, profile);
    response.close(config.setConfig(value, this, responder));
    return response;
  }

  @override
  Response removeConfig(String name, Responder responder, Response response) {
    var config = Configs.getConfig(name, profile);
    return response..close(config.removeConfig(this, responder));
  }

  @override
  Response setValue(
    Object value,
    Responder responder,
    Response response,
    [int maxPermission = Permission.CONFIG]) {
    updateValue(value);
    // TODO: check value type
    return response..close();
  }
}
