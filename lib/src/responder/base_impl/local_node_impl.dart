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
  void load(Map m, NodeProviderImpl provider) {
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
    if (ps == null) {
      for (var node in mixins) {
        if ((node as LocalNode).permissions != null) {
          ps = (node as LocalNode).permissions;
          break;
        }
      }
    }
    if (ps != null) {
      ps.getPermission(responder);
    }
    if (parentNode != null) {
      return parentNode.getPermission(responder);
    }
    return Permission.NONE;
  }
  
  Response setAttribute(String name, String value, Responder responder, Response response) {
    if (getPermission(responder) >= Permission.WRITE) {
      if (attributes.containsKey(name) && attributes[name] != value){
        attributes[name] = value;
        //TODO update list stream
        //TODO need a flag so list stream is not updated when nothing is listening
      }
      return response..close();
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }
  }

  Response removeAttribute(String name, Responder responder, Response response) {
    return response..close();
  }

  Response setConfig(String name, Object value, Responder responder, Response response) {
    return response..close();
  }

  Response removeConfig(String name, Responder responder, Response response) {
    return response..close();
  }
}
