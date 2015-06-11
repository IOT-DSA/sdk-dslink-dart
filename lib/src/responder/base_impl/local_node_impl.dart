part of dslink.responder;

abstract class NodeProviderImpl extends NodeProvider {
  Map<String, LocalNode> get nodes;
}

class LocalNodeImpl extends LocalNode {
  LocalNode parentNode;

  PermissionList permissions;

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
        rslt[key] = val.serialize(true);
      }
    });
    return rslt;
  }

  bool _loaded = false;
  bool get loaded => _loaded;

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
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        Node node = provider.getNode('$childPathPre$key');
        if (node is LocalNodeImpl) {
          node.load(value, provider);
        }
        children[key] = node;
      }
    });
    _loaded = true;
  }

  /// get the permission of a responder on this node;
  int getPermission(Responder responder) {
    PermissionList ps = permissions;
    if (ps != null) {
      return ps.getPermission(responder);
    }
    if (parentNode != null) {
      return parentNode.getPermission(responder);
    }
    // TODO default permission should be NONE
    return Permission.WRITE;
  }

  void updateList(String name, [int permission = Permission.READ]) {
    listChangeController.add(name);
  }
  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE) {
      if (!attributes.containsKey(name) || attributes[name] != value) {
        attributes[name] = value;
        updateList(name);
      }
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE) {
      if (attributes.containsKey(name)) {
        attributes.remove(name);
        updateList(name);
      }
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    var config = Configs.getConfig(name, profile);
    return response..close(config.setConfig(value, this, responder));
  }

  Response removeConfig(String name, Responder responder, Response response) {
    var config = Configs.getConfig(name, profile);
    return response..close(config.removeConfig(this, responder));
  }

  Response setValue(Object value, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE &&
        this.getConfig(r'$writable') == 'write') {
      updateValue(value);
      // TODO check value type
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }
}
