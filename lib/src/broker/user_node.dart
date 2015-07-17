part of dslink.broker;

class UserNode extends BrokerNode {
  final String username;
  UserNode(String path, BrokerNodeProvider provider, this.username) : super(path, provider) {
    configs[r'$is'] = 'broker/unode';
    profile = provider.getNode('/defs/profile/broker/unode');
  }

  bool _loaded = false;
  /// Load this node from the provided map as [m].
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
        String childPath = '$childPathPre$key';
        LocalNode node = provider.getNode(childPath);
        children[key] = node;
        if (node is UserNode) {
          node.load(value);
        } else if (node is RemoteLinkRootNode) {
          node.load(value);
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
}

class UserRootNode extends UserNode {
  UserRootNode(String path, String username, BrokerNodeProvider provider)
      : super(path, provider, username) {
    configs[r'$is'] = 'broker/unoderoot';
    profile = provider.getOrCreateNode('/defs/profile/broker/unoderoot', false);
  }
}
InvokeResponse addChildNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  Object name = params['Name'];
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
    UserNode node = responder.nodeProvider.getOrCreateNode('${parentNode.path}/$name', false);
    parentNode.children[name] = node;
    parentNode.updateList(name);
    DsTimer.timerOnceBefore((responder.nodeProvider as BrokerNodeProvider).saveUsrNodes, 1000);
    
  }
  return response..close(DSError.INVALID_PARAMETER);
}


InvokeResponse addLink(Map params, Responder responder, InvokeResponse response,
    LocalNode parentNode) {
  Object name = params['Name'];
  Object dsId = params['Id'];
  if (parentNode is UserNode &&
      name is String &&
      name != '' &&
      !name.contains(Path.invalidNameChar) &&
      !name.startsWith(r'$') &&
      !name.startsWith('!')) {
    if (!(name as String).startsWith('#')) {
      name = '#$name';
    }
    if (parentNode.children.containsKey(name)) {
      return response
        ..close(new DSError('invalidParameter', msg: 'node already exist'));
    }
    String userDsId = '${parentNode.username}:$dsId';
    String existingPath = parentNode.provider._id2connPath[userDsId];
    if (existingPath != null && existingPath.startsWith('/users/')) {
      return response
             ..close(new DSError('invalidParameter', msg: 'id already in use'));
    }
    String path = '${parentNode.path}/$name';
    parentNode.provider._id2connPath[userDsId] = path;
    parentNode.provider._connPath2id[path] = userDsId;
    
    ServerLink link = parentNode.provider.getLink(userDsId);
    if (link != null) {
      link.close();
      parentNode.provider.removeLink(link);
    }
    LocalNode node = responder.nodeProvider.getOrCreateNode(path, false);
    node.configs[r'$$dsId'] = dsId;
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
