part of dslink.broker;

class UserNode extends LocalNodeImpl {
  final String username;
  UserNode(String path, this.username, BrokerNodeProvider provider) : super(path) {
    configs[r'$is'] = 'broker/unode';
    profile = provider.getNode('/defs/profile/broker/unode');
  }

  bool _loaded = false;
  /// Load this node from the provided map as [m].
  void load(Map m, [BrokerNodeProvider provider]) {
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
        String childPath = '$childPathPre$key';
        LocalNode node = provider.getNode(childPath);
        children[key] = node;
        if (node is UserNode) {
          node.load(value, provider);
        } else if (node is RemoteLinkRootNode) {
          node.load(value, provider);
          node._linkManager.inTree = true;
          if (node.configs[r'$$dsId'] is String) {
            String userDsId = '$username:${node.configs[r'$$dsId']}';
            provider._id2connPath[userDsId] = childPath;
            provider._connPath2id[childPath] = userDsId;
          }
        }
      }
    });
    _loaded = true;
  }
  Map save() {
    Map rslt = {};
    configs.forEach((str, val) {
      rslt[str] = val;
    });
    attributes.forEach((str, val) {
      rslt[str] = val;
    });
    children.forEach((str, Node node) {
      if (node is UserNode) rslt[str] = node.save();
    });
    return rslt;
  }
}

class UserRootNode extends UserNode {
  UserRootNode(String path, String username, BrokerNodeProvider provider)
      : super(path, username, provider) {
    configs[r'$is'] = 'broker/unoderoot';
    profile = provider.getNode('/defs/profile/broker/unoderoot');
  }
}
InvokeResponse addChildNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  Object name = params['name'];
  if (parentNode is UserNode &&
      name is String &&
      name != '' &&
      !name.contains(Path.invalidNameChar) &&
      !name.startsWith(r'$') &&
      !name.startsWith(r'!') &&
      !name.startsWith(r'#')) {
    if (parentNode.children.containsKey(name)) {
      return response
        ..close(new DSError('invalidParameter', msg: 'node already exist'));
    }
    UserNode node = responder.nodeProvider.getNode('${parentNode.path}/$name');
    parentNode.children[name] = node;
    parentNode.updateList(name);
    DsTimer.timerOnceBefore((responder.nodeProvider as BrokerNodeProvider).saveUsrNodes, 1000);
    
  }
  return response..close(DSError.INVALID_PARAMETER);
}

InvokeResponse addLink(Map params, Responder responder, InvokeResponse response,
    LocalNode parentNode) {
  Object name = params['name'];
  if (parentNode is UserNode &&
      name is String &&
      name != '' &&
      !name.contains(Path.invalidNameChar) &&
      !name.startsWith(r'$') &&
      !name.startsWith(r'!') &&
      !name.startsWith(r'#')) {
    if (parentNode.children.containsKey(name)) {
      return response
        ..close(new DSError('invalidParameter', msg: 'node already exist'));
    }
    UserNode node = responder.nodeProvider.getNode('${parentNode.path}/$name');
    parentNode.children[name] = node;
    parentNode.updateList(name);
    DsTimer.timerOnceBefore((responder.nodeProvider as BrokerNodeProvider).saveUsrNodes, 1000);
    
  }
  return response..close(DSError.INVALID_PARAMETER);
}
Map userNodeFunctions = {
  "broker": {
    "unode": {"addChild": addChildNode, "addLink": addLink},
    "unoderoot": {"addChild": addChildNode, "addLink": addLink,}
  }
};
