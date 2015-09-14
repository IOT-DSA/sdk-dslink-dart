part of dslink.broker;

// TODO, implement special configs and attribute merging
class RemoteLinkRootNode extends RemoteLinkNode with BrokerNodePermission implements BrokerNode {
  RemoteLinkRootNode(
      String path, String remotePath, RemoteLinkManager linkManager)
      : super(path, linkManager.broker, remotePath, linkManager);

  bool get loaded => true;

  // TODO does this need parentNode?
  LocalNode parentNode;

  ListController createListController(Requester requester) {
    return new RemoteLinkRootListController(this, requester);
  }

  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    if (!attributes.containsKey(name) || attributes[name] != value) {
      attributes[name] = value;
      updateList(name);
    }
    return response..close();
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    if (attributes.containsKey(name)) {
      attributes.remove(name);
      updateList(name);
    }
    return response..close();
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

  void load(Map m) {
    m.forEach((String name, Object value) {
      if (name.startsWith(r'$')) {
        configs[name] = value;
      } else if (name.startsWith('@')) {
        attributes[name] = value;
      } else if (value is Map) {
        pchildren[name] = new VirtualNodePermission()..load(value);
      }
    });
    if (m['?permissions'] is List) {
      loadPermission(m['?permissions']);
    }
  }

  Map serialize(bool withChildren) {
    Map rslt = {};
    configs.forEach((String name, Object val) {
      rslt[name] = val;
    });
    attributes.forEach((String name, Object val) {
      rslt[name] = val;
    });
    pchildren.forEach((String name, VirtualNodePermission val) {
      rslt[name] = val.serialize();
    });
    List permissionData = this.serializePermission();
    if (permissionData != null) {
      rslt['?permissions'] = permissionData;
    }
    return rslt;
  }

  void updateList(String name, [int permission = Permission.READ]) {
    listChangeController.add(name);
  }

  void resetNodeCache() {
    children.clear();
    configs.remove(r'$disconnectedTs');
  }

  /// children list only for permissions
  Map<String, VirtualNodePermission> pchildren = new Map<String, VirtualNodePermission>();

  @override
  int getPermission (Iterator<String> paths, Responder responder, int permission) {
    permission = super.getPermission(paths, responder, permission);
    if (permission == Permission.CONFIG) {
      return Permission.CONFIG;
    }
    if (paths.moveNext()) {
      String name = paths.current;
      if (pchildren[name] is BrokerNodePermission) {
        return pchildren[name].getPermission(paths, responder, permission);
      }
    }
    return permission;
  }
  @override
  Map getSimpleMap() {
    Map m = super.getSimpleMap();
    if (configs.containsKey(r'$shared')){
      m[r'$shared'] = configs[r'$shared'];
    }
    return m;
  }
}

class RemoteLinkRootListController extends ListController {
  RemoteLinkRootListController(RemoteNode node, Requester requester)
      : super(node, requester);

  void onUpdate(String streamStatus, List updates, List columns, Map meta, DSError error) {
    bool reseted = false;
    // TODO implement error handling
    if (updates != null) {
      for (Object update in updates) {
        String name;
        Object value;
        bool removed = false;
        if (update is Map) {
          if (update['name'] is String) {
            name = update['name'];
          } else {
            continue; // invalid response
          }
          if (update['change'] == 'remove') {
            removed = true;
          } else {
            value = update['value'];
          }
        } else if (update is List) {
          if (update.length > 0 && update[0] is String) {
            name = update[0];
            if (update.length > 1) {
              value = update[1];
            }
          } else {
            continue; // invalid response
          }
        } else {
          continue; // invalid response
        }
        if (name.startsWith(r'$')) {
          if (!reseted &&
              (name == r'$is' ||
                  name == r'$base' ||
                  (name == r'$disconnectedTs' && value is String))) {
            if (name == r'$is') {
              if (value == 'dsa/broker') {
                node.configs[r'$is'] = 'dsa/broker';
              } else {
                node.configs[r'$is'] = 'dsa/link';
              }
            }
            reseted = true;
            node.resetNodeCache();
          } else if (name == r'$shared') {
            node.configs[r'$shared'] = value;
          }
          // ignore other changes
        } else if (name.startsWith('@')) {
          // ignore
        } else {
          changes.add(name);
          if (removed) {
            node.children.remove(name);
          } else if (value is Map) {
            // TODO, also wait for children $is
            node.children[name] =
                requester.nodeCache.updateRemoteChildNode(node, name, value);
          }
        }
      }
      if (request.streamStatus != StreamStatus.initialize) {
        node.listed = true;
      }
      onProfileUpdated();
    }
  }
}
