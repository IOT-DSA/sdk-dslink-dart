part of dslink.broker;

class BrokerNodeProvider extends NodeProviderImpl implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connPath to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();

  BrokerPermissions permissions;

  BrokerNode connsNode;
  BrokerNode usersNode;
  BrokerNode defsNode;
  BrokerNode quarantineNode;
  Map rootStructure = {'users':{}, 'conns': {}, 'defs': {}, 'sys': {}};

  bool shouldSaveFiles = true;
  bool enabledQuarantine = false;
  bool enabledPermission = false;
  bool acceptAllConns = true;
  BrokerNodeProvider({this.enabledQuarantine:false, this.acceptAllConns:true, List defaultPermission}) {
    permissions = new BrokerPermissions();
    // initialize root nodes
    RootNode root = new RootNode('/', this);

    nodes['/'] = root;
    if (enabledQuarantine) {
      rootStructure['quarantine'] = {};
    }
    root.load(rootStructure);
    connsNode = nodes['/conns'];
    usersNode = nodes['/users'];
    defsNode = nodes['/defs'];
    quarantineNode = nodes['/quarantine'];

    enabledPermission = defaultPermission != null;
    if (enabledPermission) {
      root.loadPermission(defaultPermission);//['dgSuper','config','default','write']
      defsNode.loadPermission(['default','read']);
      permissions.root = root;
    }

    loadDef();
    registerInvokableProfile(userNodeFunctions);
    initSys();
  }

  void initSys() {
    setNode("/sys/version", new BrokerVersionNode("/sys/version", this, DSA_VERSION));
    setNode("/sys/startTime", new StartTimeNode("/sys/startTime", this));
    setNode("/sys/clearConns", new ClearConnsAction("/sys/clearConns", this));
    setNode("/sys/throughput", new ThroughPutNode("/sys/throughput", this));
    
    upstream = new UpstreamNode("/sys/upstream", this);
    setNode("/sys/upstream", upstream);
    
    BrokerTraceNode.init(this);
  }

  UpstreamNode upstream;

  bool _defsLoaded = false;

  /// load a fixed profile map
  void loadDef() {
    DefinitionNode profileNode = getOrCreateNode('/defs/profile', false);
    defsNode.children['profile'] = profileNode;
    defaultProfileMap.forEach((String name, Map m) {
      String path = '/defs/profile/$name';
      DefinitionNode node = getOrCreateNode(path, false);
      node.load(m);
      profileNode.children[name] = node;
    });
    File connsFile = new File("defs.json");
    try {
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/defs/$name';
        DefinitionNode node = getOrCreateNode(path,false);
        node.load(m);
        defsNode.children[name] = node;
      });
    } catch (err) {
    }
  }

  void registerInvokableProfile(Map m) {
    void register(Map m, String path) {
      m.forEach((String key, Object val) {
        if (val is Map) {
          register(val, '$path$key/');
        } else if (val is InvokeCallback) {
          (getOrCreateNode('$path$key', false) as DefinitionNode).setInvokeCallback(val);
        }
      });
    }
    register(m, '/defs/profile/');
  }

  void loadUserNodes() {
    File connsFile = new File("usernodes.json");
    try {
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/users/$name';
        UserRootNode node = getOrCreateNode(path, false);
        if (enabledPermission) {
          node.loadPermission([[name,'config'],['default','none']]);
        }
        node.load(m);
        usersNode.children[name] = node;
        if (enabledQuarantine) {
          String path = '/quarantine/$name';
          BrokerNode node = getOrCreateNode(path, false);
          quarantineNode.children[name] = node;
        }
      });
    } catch (err) {
    }
  }

  Map saveUsrNodes() {
    Map m = {};
    usersNode.children.forEach((String name, LocalNodeImpl node) {
      m[name] = node.serialize(true);
    });
    File connsFile = new File("usernodes.json");
    if (shouldSaveFiles) {
      connsFile.writeAsStringSync(DsJson.encode(m));
    }
    return m;
  }

  void loadConns() {
    // loadConns from file
    File connsFile = new File("conns.json");
    try {
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/conns/$name';
        RemoteLinkRootNode node = getOrCreateNode(path, false);
        node.load(m);
        if (node.configs[r'$$dsId'] is String) {
          _id2connPath[node.configs[r'$$dsId']] = path;
          _connPath2id[path] = node.configs[r'$$dsId'];
        }
      });
    } catch (err) {
    }
  }

  Map saveConns() {
    Map m = {};
    connsNode.children.forEach((String name, RemoteLinkNode node) {
      RemoteLinkManager manager = node._linkManager;
      m[name] = manager.rootNode.serialize(false);
    });
    File connsFile = new File("conns.json");
    if (shouldSaveFiles) {
      connsFile.writeAsStringSync(DsJson.encode(m));
    }
    return m;
  }

  // remove disconnected nodes from the conns node
  void clearConns() {
    List names = connsNode.children.keys.toList();
    for (String name in names) {
      RemoteLinkNode node = connsNode.children[name];
      RemoteLinkManager manager = node._linkManager;
      if (manager.disconnected != null) {

        String fullId = _connPath2id[manager.path];
        _connPath2id.remove(manager.path);
        _id2connPath.remove(fullId);
        connsNode.children.remove(name);
        manager.inTree = false;
        connsNode.updateList(name);
      }
    }
    DsTimer.timerOnceAfter(saveConns, 3000);
  }

  /// add a node to the tree
  void setNode(String path, LocalNode newNode) {
    LocalNode node = nodes[path];
    if (node != null) {
      logger.severe('error, BrokerNodeProvider.setNode same node can not be set twice');
      return;
    }

    Path p = new Path(path);
    LocalNode parentNode = nodes[p.parentPath];
    if (parentNode == null) {
      logger.severe('error, BrokerNodeProvider.setNode parentNode is null');
      return;
    }

    nodes[path] = newNode;
    parentNode.addChild(p.name, newNode);
  }


  LocalNode getNode(String path) {
    return nodes[path];
  }

  LocalNode getOrCreateNode(String path, [bool addToTree = true]) {
    if (addToTree == true) {
      throw 'not supported';
    }

    LocalNode node = nodes[path];

    if (node != null) {
      return node;
    }
    if (path.startsWith('/users/')) {
      List paths = path.split('/');
      String username = path.split('/')[2];
      if (paths.length == 3) {
        node = new UserRootNode(path, username, this);
      } else {
        int pos = path.indexOf('/#');
        if (pos < 0) {
          node = new UserNode(path, this, username);
        } else {
          String connPath;
          int pos2 = path.indexOf('/', pos + 1);
          if (pos2 < 0) {
            connPath = path;
          } else {
            connPath = path.substring(0, pos2);
          }
          RemoteLinkManager conn = conns[connPath];
          if (conn == null) {
            // TODO conn = new RemoteLinkManager('/conns/$connName', connRootNodeData);
            conn = new RemoteLinkManager(this, connPath, this);
            conns[connPath] = conn;
            nodes[connPath] = conn.rootNode;
            conn.rootNode.parentNode = getOrCreateNode(path.substring(0, pos), false);
          }
          node = conn.getOrCreateNode(path, false);
        }
      }
    } else if (path.startsWith('/conns/')) {
      String connName = path.split('/')[2];
      String connPath = '/conns/$connName';
      RemoteLinkManager conn = conns[connPath];
      if (conn == null) {
        // TODO conn = new RemoteLinkManager('/conns/$connName', connRootNodeData);
        conn = new RemoteLinkManager(this, connPath, this);
        conns[connPath] = conn;
        nodes[connPath] = conn.rootNode;
        connsNode.children[connName] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
        conn.inTree = true;
        connsNode.updateList(connName);
      }
      node = conn.getOrCreateNode(path, false);
    } else if (path.startsWith('/quarantine/')) {
      List paths = path.split('/');
      String user = paths[2];
      if (paths.length > 3) {
        String connName = paths[3];
        String connPath = '/quarantine/$user/$connName';
        RemoteLinkManager conn = conns[connPath];
        if (conn == null) {
          // TODO conn = new RemoteLinkManager('/conns/$connName', connRootNodeData);
          conn = new RemoteLinkManager(this, connPath, this);
          conns[connPath] = conn;
          nodes[connPath] = conn.rootNode;
          BrokerNode quarantineUser = getOrCreateNode('/quarantine/$user', false);
          quarantineUser.children[connName] = conn.rootNode;
          conn.rootNode.parentNode = quarantineUser;
          conn.inTree = true;
          quarantineUser.updateList(connName);
        }
        node = conn.getOrCreateNode(path, false);
      } else {
        node = new BrokerNode(path, this);
      }
    } else if (path.startsWith('/defs/')) {
      //if (!_defsLoaded) {
      node = new DefinitionNode(path, this);
      //}
    } else {
      node = new BrokerNode(path, this);
    }
    if (node != null) {
      nodes[path] = node;
    }
    return node;
  }

  /// dsId to server links
  final Map<String, ServerLink> _links = new Map<String, ServerLink>();
  final Map<String, String> _id2connPath = new Map<String, String>();
  final Map<String, String> _connPath2id = new Map<String, String>();

  RemoteLinkManager getConnById(String id) {
    if (_id2connPath.containsKey(id)) {
      return conns[_id2connPath[id]];
    }
    return null;
  }
  RemoteLinkManager getConnPath(String path) {
    return conns[path];
  }
  String makeConnPath(String fullId) {
    if (_id2connPath.containsKey(fullId)) {
      return _id2connPath[fullId];
      // TODO is it possible same link get added twice?
    } else if (fullId.length < 43) {
      // user link
      String connPath = '/conns/$fullId';
      int count = 0;
      // find a connName for it
      while (_connPath2id.containsKey(connPath)) {
        connPath = '/conns/$fullId-${count++}';
      }
      _connPath2id[connPath] = fullId;
      _id2connPath[fullId] = connPath;
      return connPath;
    } else {
      // device link
      String connPath;

      String folderPath = '/conns/';
      String dsId = fullId;
      if (fullId.contains(':')) {
        // uname:dsId
        List<String> u_id = fullId.split(':');
        folderPath = '/quarantine/${u_id[0]}/';
        dsId = u_id[1];
      }

      // find a connName for it, keep append characters until find a new name
      int i = 43;
      if (dsId.length == 43) i = 42;
      for (; i >= 0; --i) {
        connPath = '$folderPath${dsId.substring(0, dsId.length - i)}';
        if (i == 43 && connPath.length > 8 && connPath.endsWith('-')) {
          // remove the last - in the name;
          connPath = connPath.substring(0, connPath.length - 1);
        }
        if (!_connPath2id.containsKey(connPath)) {
          _connPath2id[connPath] = fullId;
          _id2connPath[fullId] = connPath;
          break;
        }
      }
      DsTimer.timerOnceBefore(saveConns, 3000);
      return connPath;
    }
  }

  void addLink(ServerLink link) {
    String str = link.dsId;
    if (link.session != '') {
      str = '$str ${link.session}';
    }

    String connPath;
    // TODO update children list of /conns node
    if (_links.containsKey(str)) {
      // TODO is it possible same link get added twice?
    } else {
      _links[str] = link;
      if (link.session == null) {
        // don't create node for requester node with session
        connPath = makeConnPath(str);
        getOrCreateNode(connPath, false).configs[r'$$dsId'] = link.dsId;
        logger.info('new node added at $connPath');
      }
    }
  }

  ServerLink getLink(String dsId, {String sessionId:''}) {
    if (sessionId == null) sessionId = '';
    String str = dsId;
    if (sessionId != null && sessionId != '') {
      str = '$dsId sessionId';
    }
    if (_links[str] != null) {
      String connPath = makeConnPath(str);
      RemoteLinkNode node = getOrCreateNode(connPath, false);
      RemoteLinkManager conn = node._linkManager;
      if (!conn.inTree) {
        String connName = conn.path.split('/').last;
        connsNode.children[connName] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
        conn.inTree = true;
        connsNode.updateList(connName);
      }
    }
    return _links[str];
  }

  void removeLink(ServerLink link) {
    if (_links[link.dsId] == link) {
      _links.remove(link.dsId);
    }
  }

  Requester getRequester(String dsId) {
    String connPath = makeConnPath(dsId);
    if (conns.containsKey(makeConnPath)) {
      return conns[connPath].requester;
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getOrCreateNode(connPath, false);
    return node._linkManager.requester;
  }

  Responder getResponder(String dsId, NodeProvider nodeProvider,
                         [String sessionId = '']) {
    String connPath = makeConnPath(dsId);
    if (conns.containsKey(connPath)) {
      return conns[connPath].getResponder(nodeProvider, dsId, sessionId);
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getOrCreateNode(connPath, false);
    return node._linkManager.getResponder(nodeProvider, dsId, sessionId);
  }

  Responder createResponder(String dsId) {
    return new Responder(this, dsId);
  }
}
